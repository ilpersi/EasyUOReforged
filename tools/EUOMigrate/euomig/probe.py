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


def run(ctx, title=None):
    pr = Probe(ctx)
    title = title if title is not None else window_title(ctx.p.pid)
    name, shard = name_and_shard(title)
    pr.objects()
    pr.statname(name)
    pr.gumps()
    return pr.found, pr.notes, (name, shard)
