"""Layout probes: find B_* structure offsets in the running client, read-only.

Each probe searches for the offset that makes a whole list of live objects consistent at once
(dozens of samples, not one), so a lucky match is very unlikely. Anchors are facts every logged-in
client has: the player object (C_CHARPTR) with a human/elf/gargoyle body, a backpack on layer 21
with graphic 0E75h or 09B2h, a chain of gumps whose RTTI classes say "Gump", and the character
name in the window title ("Ultima Online - <name> (<shard>)").

probe(ctx) -> {B_X: (value, evidence)} for what it could establish; nothing is guessed.
"""
import ctypes
import ctypes.wintypes as wt
import struct

from .oracles import stl_find

BODIES = {0x190, 0x191, 0x192, 0x193, 0x25D, 0x25E, 0x29A, 0x29B, 0x3DB, 0x3DF, 0x3E2}
BACKPACKS = {0x0E75, 0x09B2}
LAYER_BACKPACK = 21
MAX_OBJ = 4000


def window_title(pid):
    """title of the process's top-level window ('Ultima Online - Name (Shard)')"""
    user32 = ctypes.WinDLL('user32')
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, lp):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(p))
        if p.value == pid and user32.IsWindowVisible(hwnd):
            n = user32.GetWindowTextLengthW(hwnd)
            if n:
                b = ctypes.create_unicode_buffer(n + 1)
                user32.GetWindowTextW(hwnd, b, n + 1)
                found.append(b.value)
        return True
    user32.EnumWindows(cb, 0)
    return max(found, key=len) if found else ''


def name_and_shard(title):
    if ' - ' not in title:
        return None, None
    rest = title.split(' - ', 1)[1]
    if rest.endswith(')') and ' (' in rest:
        n, s = rest[:-1].rsplit(' (', 1)
        return n.strip(), s.strip()
    return rest.strip(), None


class Probe:
    def __init__(self, ctx):
        self.c = ctx
        self.p = ctx.p
        self.found = {}
        self.notes = []

    def u32(self, a):
        return self.p.u32(a)

    def has_rtti(self, obj):
        return bool(obj) and self.c.cls_of_object(obj) is not None

    # ---- objects ----------------------------------------------------------------------------
    def walk(self, start, idoff):
        """objects from start following [o + idoff + $C]; stops at 0, a loop or a non-object"""
        out, seen, o = [], set(), start
        while o and o not in seen and len(out) < MAX_OBJ:
            seen.add(o)
            if not self.has_rtti(o):
                break
            s = self.u32(o + idoff)
            if s is None or not (0 < s < 0x80000000):
                break
            out.append(o)
            o = self.u32(o + idoff + 0xC)
        return out

    def objects(self):
        player = self.u32(self.c.at(self.c.v['C_CHARPTR']))
        if not player:
            self.notes.append('objects: C_CHARPTR is null (log in first)')
            return
        best = (0, None, [])
        for off in range(0, 0x400, 4):
            s = self.u32(player + off)
            if not s or not (0 < s < 0x40000000):
                continue
            objs = self.walk(player, off)
            # what makes it the serial: unique values; whatever sits in a container is an item
            # (serial bit 30 set) whose container is an object of the same list; the player wears
            # or carries something
            ids = set(objs)
            serials = [self.u32(o + off) for o in objs]
            if len(set(serials)) != len(serials):
                continue
            conts = [self.u32(o + off + 4) or 0 for o in objs]
            inside = [i for i, ct in enumerate(conts) if ct]
            if len(inside) < 3 or not any(ct == player for ct in conts):
                continue
            if any(conts[i] not in ids or not (serials[i] & 0x40000000) for i in inside):
                continue
            if len(objs) > best[0]:
                best = (len(objs), off, objs)
        n, idoff, objs = best
        if idoff is None or n < 5:
            self.notes.append('objects: no offset gives a consistent object list (best %d objects)' % n)
            return
        self.found['B_ITEMID'] = (idoff, '%d objects chained by [obj+$%X+$C], all with serial and RTTI vtable, '
                                         'containers inside the list' % (n, idoff))
        self.player, self.idoff, self.objs = player, idoff, objs
        cont = {o: (self.u32(o + idoff + 4) or 0) for o in objs}
        children = [o for o in objs if cont[o] == player]
        # type: the player's body, and a backpack among its children on layer 21 (slot byte near the id)
        for t in range(0, idoff, 2):
            if (self.p.u16(player + t) or 0) not in BODIES:
                continue
            for o in children:
                if (self.p.u16(o + t) or 0) in BACKPACKS:
                    slots = [s for s in range(4, 0x40) if self.p.u8(o + idoff + s) == LAYER_BACKPACK]
                    if slots:
                        self.found['B_ITEMTYPE'] = (t, 'player body %Xh and backpack %Xh at +$%X' % (
                            self.p.u16(player + t), self.p.u16(o + t), t))
                        self.found['B_ITEMSLOT'] = (slots[0], 'backpack layer 21 at id+$%X' % slots[0])
                        break
            if 'B_ITEMTYPE' in self.found:
                break
        # position: X/Y words of everything on the ground lie around the player
        ground = [o for o in objs if not cont[o]]
        if len(ground) >= 3:
            best = None
            for x in range(0, idoff, 2):
                px, py = self.p.u16(player + x), self.p.u16(player + x + 2)
                if not px or not py or px >= 7168 or py >= 4096:
                    continue
                near = 0
                for o in ground:
                    ox, oy = self.p.u16(o + x) or 0, self.p.u16(o + x + 2) or 0
                    if 0 < ox < 7168 and 0 < oy < 4096 and abs(ox - px) <= 40 and abs(oy - py) <= 40:
                        near += 1
                z = struct.unpack('<h', self.p.read(player + x + 4, 2))[0]
                if near >= 0.9 * len(ground) and -128 <= z <= 127 and (best is None or near > best[1]):
                    best = (x, near, px, py, z)
            if best:
                x, near, px, py, z = best
                self.found['B_POS'] = (x, 'player at %d,%d,%d; %d of %d ground objects within 40 tiles' % (
                    px, py, z, near, len(ground)))

    # ---- status gump: the character's name --------------------------------------------------
    def statname(self, name):
        if not name or not hasattr(self, 'idoff'):
            return
        g = self.u32(self.player + self.idoff + 0x10)
        if not g:
            self.notes.append('status: no status gump open for the player (open it and probe again)')
            return
        d = self.p.read(g, 0x800)
        i = d.find(name.encode('latin1') + b'\0')
        if i < 0:
            self.notes.append('status: %r not found in the status gump %08X' % (name, g))
            return
        self.found['B_STATNAME'] = (i, 'character name %r at status gump +$%X' % (name, i))

    # ---- gumps ------------------------------------------------------------------------------
    def gumps(self):
        head = self.u32(self.c.at(self.c.v['C_CONTPOS']))
        if not head:
            self.notes.append('gumps: no gump open')
            return
        best = (0, None, [])
        for off in range(4, 0x200, 4):
            chain, seen, g = [], set(), head
            while g and g not in seen and len(chain) < 300:
                seen.add(g)
                cls = self.c.cls_of_object(g)
                if not cls or 'Gump' not in cls:
                    break
                chain.append(cls)
                g = self.u32(g + off)
            if g == 0 and len(chain) > best[0]:            # must END the list cleanly
                best = (len(chain), off, chain)
        n, off, chain = best
        if off is None or n < 2:
            self.notes.append('gumps: no next-offset chains two or more gumps')
            return
        self.found['B_CONTNEXT'] = (off, '%d gumps chained by +$%X: %s' % (
            n, off, ', '.join(c.replace('.?AV', '').replace('@@', '') for c in chain[:6])))


    # ---- buff bar -------------------------------------------------------------------------
    def buff_entry(self, a):
        """does a look like a buff icon entry: icon id, duration, timer id, title/description cliloc?"""
        d = self.p.read(a, 0xE0)
        if len(d) < 0xE0:
            return False
        icon, dur, timer, title = struct.unpack_from('<IiiI', d, 0)
        desc = struct.unpack_from('<I', d, 0xDC)[0]
        return (0 < icon < 0x10000 and -1 <= dur < 86400 * 30 and -1 <= timer < 100000
                and 500000 <= title < 4000000 and 500000 <= desc < 4000000)

    def buffbar(self):
        """The 'BuffIcons Gump' keeps a std::vector of fixed-size icon entries: begin, end and
        capacity pointers in a row somewhere in the gump, entries that decode (icon id, cliloc numbers
        at +$C and +$DC). The cliloc map's head offset and key offset follow from looking up an entry's
        title cliloc in the manager (C_CLILOC). Needs the buff window open with at least one buff."""
        nxt = self.found['B_CONTNEXT'][0] if 'B_CONTNEXT' in self.found else self.c.v.get('B_CONTNEXT')
        head = self.u32(self.c.at(self.c.v['C_CONTPOS'])) if self.c.v.get('C_CONTPOS') else None
        if not head or not nxt:
            self.notes.append('buff bar: no gump list to search')
            return
        gump, seen, g = None, set(), head
        while g and g not in seen and len(seen) < 300:
            seen.add(g)
            if self.text_at(self.u32(g + 8) or 0, 32)[0] == 'BuffIcons Gump':
                gump = g
                break
            g = self.u32(g + nxt)
        if not gump:
            self.notes.append('buff bar: no BuffIcons gump (open the buff window with a buff on, then probe again)')
            return
        best = None
        for off in range(0x40, 0x400, 4):
            b, e, cap = self.u32(gump + off), self.u32(gump + off + 4), self.u32(gump + off + 8)
            if not b or not e or cap is None or not (b < e <= cap) or e - b > 0x10000:
                continue
            for size in [0x1B0] + [s for s in range(0x100, 0x300, 4) if s != 0x1B0]:
                if (e - b) % size or (e - b) // size > 64:
                    continue
                n = (e - b) // size
                if all(self.buff_entry(b + i * size) for i in range(n)):
                    if best is None or n > best[0]:
                        best = (n, off, size, b)
                    break
        if not best:
            self.notes.append('buff bar: no pointer pair in the gump holds buff icon entries (is a buff active?)')
            return
        n, off, size, b = best
        self.found['B_BUFFVEC'] = (off, '%d buff entries of $%X bytes from the pointer pair at gump+$%X' % (n, size, off))
        self.found['B_BUFFSIZE'] = (size, 'entry size: the vector spans %d x $%X' % (n, size))
        link = self.c.v.get('C_CLILOC')
        mgr = self.u32(self.c.at(link)) if link else None
        if not mgr:
            self.notes.append('buff bar: C_CLILOC unusable, so B_STLHEAD / B_CLILOCKEY stay inherited')
            return
        titles = [self.u32(b + i * size + 0xC) for i in range(n)]
        for hoff in (0, 4, 8):
            hd = self.u32(mgr + hoff)
            if not hd:
                continue
            for koff in (0x0C, 0x10, 0x14):
                hits = 0
                for t in titles:
                    nd = stl_find(self.p, hd, t, koff)
                    s = self.text_at(self.u32(nd + koff + 4) or 0, 64)[0] if nd else None
                    hits += bool(s and len(s) >= 2)
                if hits == len(titles):
                    self.found['B_STLHEAD'] = (hoff, 'cliloc manager keeps its tree head at +$%X' % hoff)
                    self.found['B_CLILOCKEY'] = (koff, 'all %d title cliloc numbers resolve with the key at node+$%X' % (n, koff))
                    return
        self.notes.append('buff bar: no head/key offset resolves the %d title cliloc numbers' % n)

    # ---- journal --------------------------------------------------------------------------
    def text_at(self, a, n=0x100):
        """(text, unicode) if a holds a printable ASCII or UTF-16 string, else (None, None)"""
        d = self.p.read(a, n)
        if not d:
            return None, None
        if len(d) > 3 and d[1] == 0 and d[3] == 0 and 32 <= d[0] < 127:
            s = d.decode('utf-16le', 'replace').split('\0')[0]
            if s and all(32 <= ord(ch) < 0x10000 for ch in s):
                return s, True
        s = d.split(b'\0')[0]
        if s and all(32 <= c < 127 or c >= 0xA0 for c in s):
            return s.decode('latin1'), False
        return None, None

    def journal(self):
        """Two layouts (uocommands.pas ScanJournal): the old fixed record -- text POINTER at +0,
        colour +4, kind byte +8, next at +$1C -- or, from 7.0.108.0, the text INLINE at the node
        start, colour/kind dwords at B_JCOL/B_JKIND (kind $12 = UTF-16) and the next-older node at
        B_JNEXTPTR. The newest node is the head, so the longest chain picks the older-direction
        pointer (the newer-direction one is 0 there)."""
        head = self.u32(self.c.at(self.c.v['C_JOURNALPTR']))
        if not head:
            self.notes.append('journal: empty (say something in game, then probe again)')
            return
        # old record layout
        n, old = head, 0
        while n and old < 50:
            t, _ = self.text_at(self.u32(n) or 0)
            if t is None:
                break
            old += 1
            n = self.u32(n + 0x1C)
        # inline layout
        best = (0, None)
        if self.text_at(head)[0] is not None:
            for off in range(0x100, 0x1000, 4):
                n, k, seen = head, 0, set()
                while n and n not in seen and k < 60:
                    seen.add(n)
                    if self.text_at(n)[0] is None:
                        break
                    k += 1
                    n = self.u32(n + off)
                if n == 0 or k >= 60:
                    if k > best[0]:
                        best = (k, off)
        k, off = best
        if old >= 2 and old >= k:
            self.found['F_JOURNALDIRECT'] = (0, '%d entries in the old record layout (text pointer +0, next +$1C)' % old)
            return
        if k < 2:
            self.notes.append('journal: fewer than two entries in either layout (say something, probe again)')
            return
        self.found['F_JOURNALDIRECT'] = (1, '%d entries with the text inline' % k)
        self.found['B_JNEXTPTR'] = (off, '%d entries chained toward older ones by +$%X' % (k, off))
        # colour / kind: kind is $12 exactly on the UTF-16 entries, the colour a hue
        nodes, n = [], head
        while n and len(nodes) < k:
            nodes.append(n)
            n = self.u32(n + off)
        for koff in [0x804] + list(range(0x104, off, 4)):
            kinds = [(self.u32(nd + koff), self.text_at(nd)[1]) for nd in nodes]
            if any(v is None or v > 0x40 for v, u in kinds):
                continue
            if any((v == 0x12) != bool(u) for v, u in kinds):
                continue
            cols = [self.u32(nd + koff - 4) for nd in nodes]
            # hues; 0 is the default colour (the welcome line), but not all of them
            if all(c is not None and c <= 0xFFFF for c in cols) and any(cols):
                self.found['B_JKIND'] = (koff, 'kind dword at +$%X: $12 on exactly the UTF-16 entries (%d of %d)' % (
                    koff, sum(1 for v, u in kinds if u), len(kinds)))
                self.found['B_JCOL'] = (koff - 4, 'colour dword at +$%X: hues %s' % (koff - 4, sorted(set(cols))[:6]))
                break
        else:
            self.notes.append('journal: no kind/colour pair fits all %d entries' % len(nodes))

    def sysmsg(self):
        """the newest system message: its text inline at B_SYSMSGSTR (F_SYSMSGDIRECT) or behind a
        pointer there"""
        m = self.u32(self.c.at(self.c.v['C_SYSMSG']))
        if not m:
            self.notes.append('sysmsg: no system message yet')
            return
        for off in (0x800, 0x100):
            t, _ = self.text_at(m + off)
            if t and len(t) >= 3:
                self.found['F_SYSMSGDIRECT'] = (1, 'text inline at +$%X: %r' % (off, t[:40]))
                self.found['B_SYSMSGSTR'] = (off, 'text inline at +$%X' % off)
                return
            t, _ = self.text_at(self.u32(m + off) or 0)
            if t and len(t) >= 3:
                self.found['F_SYSMSGDIRECT'] = (0, 'text behind the pointer at +$%X: %r' % (off, t[:40]))
                self.found['B_SYSMSGSTR'] = (off, 'text pointer at +$%X' % off)
                return
        self.notes.append('sysmsg: no text at +$800 inline or behind +$100')


def run(ctx, title=None):
    pr = Probe(ctx)
    title = title if title is not None else window_title(ctx.p.pid)
    name, shard = name_and_shard(title)
    pr.objects()
    pr.statname(name)
    pr.gumps()
    pr.buffbar()
    pr.journal()
    pr.sysmsg()
    return pr.found, pr.notes, (name, shard)
