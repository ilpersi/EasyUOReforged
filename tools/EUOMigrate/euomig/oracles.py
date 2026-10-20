"""Live plausibility checks ("oracles") for candidate values, read-only.

check(ctx, field, value) -> (verdict, note) with verdict
   'pass'  the live memory looks exactly like what the field means
   'fail'  it cannot be that field (wrong kind of thing there)
   'weak'  nothing contradicts it, nothing confirms it
Where an oracle needs a structure offset (B_ITEMID, B_SKILLDIST, ...), it takes the value from the
candidates file -- inherited from the closest known layout, so a 'fail' there can also mean that
the LAYOUT changed (probe checks those).
"""
import struct

NSKILLS = 58


class Ctx:
    def __init__(self, proc, target, values):
        self.p = proc
        self.t = target
        self.v = values            # field -> current value (link-time / offsets)
        self.d = proc.delta
        self._live = None
        from .probe import window_title, name_and_shard
        self.title = window_title(proc.pid)
        self.name, self.shard = name_and_shard(self.title)

    def at(self, link):
        return (link + self.d) & 0xFFFFFFFF

    def cls_of_object(self, ptr):
        """RTTI class name of the object at (live) ptr, or None"""
        vt = self.p.u32(ptr) if ptr else None
        if not vt:
            return None
        return self.t.vtables.get((vt - self.d) & 0xFFFFFFFF)

    def live_functions(self, samples=20):
        if self._live is None:
            import collections
            import time
            seen = collections.Counter()
            for _ in range(samples):
                for a in self.p.return_addresses(self.t.code):
                    seen[self.t.code.func_of(a)] += 1
                time.sleep(0.05)
            self._live = seen
        return self._live


def printable(b):
    s = b.split(b'\0')[0]
    return len(s) >= 2 and all(32 <= c < 127 for c in s), s.decode('latin1')


def _words(p, a, n):
    d = p.read(a, 2 * n)
    return list(struct.unpack('<%dH' % n, d)) if len(d) == 2 * n else None


# ---- per-field oracles ---------------------------------------------------------------------------
def o_charptr(c, v):
    obj = c.p.u32(c.at(v))
    if not obj:
        return 'fail', 'null pointer'
    cls = c.cls_of_object(obj)
    bid = c.v.get('B_ITEMID', 0)
    serial = c.p.u32(obj + bid) if bid else None
    if serial is None:
        return 'fail', 'pointer %08X unreadable' % obj
    ok = 0 < serial < 0x40000000
    return ('pass' if ok and cls else 'weak' if ok else 'fail',
            'object %08X class %s, serial at +$%X = %d' % (obj, cls or '?', bid, serial))


def o_skills(kind):
    def f(c, v):
        a = c.at(v)
        if kind == 'lock':
            d = c.p.read(a, NSKILLS)
            if len(d) != NSKILLS:
                return 'fail', 'unreadable'
            ok = all(x in (0, 1, 2) for x in d)
            return ('pass' if ok and any(d) else 'weak' if ok else 'fail'), 'locks %s' % list(d[:12])
        w = _words(c.p, a, NSKILLS)
        if w is None:
            return 'fail', 'unreadable'
        lim = 1500 if kind != 'cap' else 2000
        ok = all(x <= lim for x in w) and any(w)
        note = '%s %s...' % (kind, w[:10])
        if kind == 'real' and ok and c.v.get('B_SKILLDIST'):
            base = _words(c.p, (a + c.v['B_SKILLDIST']) & 0xFFFFFFFF, NSKILLS)
            if base is None or not all(x <= 1500 for x in base):
                return 'fail', note + ', base array (at +B_SKILLDIST) implausible'
            note += ' base %s...' % base[:10]
            # base values follow the real ones (items add a little on top): a trained skill
            # with a zero base means the pair is not real/base
            trained = [i for i in range(NSKILLS) if w[i] >= 100]
            if trained and sum(1 for i in trained if base[i] == 0) > len(trained) // 5:
                return 'fail', note + ', base array zero where real values are trained'
            if any(w[i] != base[i] for i in range(NSKILLS)):
                note += ' (real and base differ: two distinct arrays)'
        return ('pass' if ok else 'fail'), note
    return f


def o_contpos(c, v):
    g = c.p.u32(c.at(v))
    if not g:
        return 'weak', 'no gump open (null)'
    cls = c.cls_of_object(g)
    if cls and 'Gump' in cls:
        return 'pass', 'head gump %08X is a %s' % (g, cls)
    return ('fail' if cls else 'weak'), 'head %08X class %s' % (g, cls or '?')


def o_clixres(c, v):
    d = c.p.read(c.at(v), 8)
    if len(d) != 8:
        return 'fail', 'unreadable'
    w, h = struct.unpack('<II', d)
    ok = 320 <= w <= 16384 and 240 <= h <= 16384
    return ('pass' if ok else 'fail'), '%d x %d' % (w, h)


def o_string(c, v):
    ok, s = printable(c.p.read(c.at(v), 64))
    return ('pass' if ok else 'fail'), repr(s[:40])


def o_shard(c, v):
    """the shard name is in the window title: 'Ultima Online - <name> (<shard>)'"""
    ok, s = printable(c.p.read(c.at(v), 64))
    if c.shard:
        return ('pass' if s == c.shard else 'fail'), '%r, title says %r' % (s[:40], c.shard)
    return ('weak' if ok else 'fail'), repr(s[:40])


def o_small(lo, hi, size=4):
    def f(c, v):
        d = c.p.read(c.at(v), size)
        if len(d) != size:
            return 'fail', 'unreadable'
        x = int.from_bytes(d, 'little', signed=True)
        return ('weak' if lo <= x <= hi else 'fail'), 'value %d' % x
    return f


def o_ptr_or_null(c, v):
    x = c.p.u32(c.at(v))
    if x is None:
        return 'fail', 'unreadable'
    if x == 0:
        return 'weak', 'null'
    cls = c.cls_of_object(x)
    if c.p.readable(x):
        return 'weak', 'points to %08X%s' % (x, ' (%s)' % cls if cls else '')
    return 'fail', '%08X is not a readable pointer' % x


# ---- buff bar: the cliloc table and the buff-timer map are MSVC std::map<int,...> trees ----------
# A tree is addressed by its head (sentinel) node: root at head+4, left at +0, right at +8; every
# leaf points back at the head. The head pointer sits at +B_STLHEAD in the container object.
def _s32(x):
    return x - 0x100000000 if x & 0x80000000 else x


def stl_find(p, head, key, koff):
    """the node holding int `key` (at node+koff) in the tree under `head`, or None"""
    if not head:
        return None
    node, best, guard = p.u32(head + 4), head, 0
    while node and node != head and guard < 256:
        k = p.u32(node + koff)
        if k is None:
            return None
        if _s32(k) < key:
            node = p.u32(node + 8)
        else:
            best, node = node, p.u32(node)
        guard += 1
    if best != head:
        k = p.u32(best + koff)
        if k is not None and _s32(k) == key:
            return best
    return None


def stl_nodes(p, head, koff, limit=64):
    """[(node, key)] in key order, or None when head is not a consistent small tree. An empty tree
    (root == head) is []. At most `limit` nodes are walked."""
    root = p.u32(head + 4) if head else None
    if root is None:
        return None
    if root == head:
        return []
    out, stack, node = [], [], root
    while (node and node != head) or stack:
        while node and node != head:
            if len(stack) > 64 or not p.readable(node, koff + 4):
                return None
            stack.append(node)
            node = p.u32(node)
        if not stack:
            break
        node = stack.pop()
        out.append((node, _s32(p.u32(node + koff))))
        if len(out) > limit:
            return None
        node = p.u32(node + 8)
    keys = [k for _, k in out]
    if not out or keys != sorted(set(keys)):
        return None
    return out


CLILOC_PROBES = (1075847, 1075655, 1075835)       # Bless, Hidden/Stealthing, Curse


def o_cliloc(c, v):
    """C_CLILOC: a global -> the cliloc manager, whose tree maps cliloc numbers to texts"""
    hoff, koff = c.v.get('B_STLHEAD'), c.v.get('B_CLILOCKEY')
    if hoff is None or not koff:
        return o_ptr_or_null(c, v)
    mgr = c.p.u32(c.at(v))
    if mgr is None:
        return 'fail', 'unreadable'
    if not mgr:
        return 'weak', 'null (cliloc table not loaded yet)'
    head = c.p.u32(mgr + hoff)
    if not head or not c.p.readable(head, 12):
        return 'fail', 'manager %08X has no tree head at +$%X' % (mgr, hoff)
    for key in CLILOC_PROBES:
        node = stl_find(c.p, head, key, koff)
        if node:
            ok, s = printable(c.p.read(c.p.u32(node + koff + 4) or 0, 64))
            if ok:
                return 'pass', 'cliloc %d = %r' % (key, s[:40])
            return 'fail', 'cliloc %d found but its text pointer (+$%X) is no text' % (key, koff + 4)
    return 'weak', 'tree at %08X, none of the probe cliloc numbers %s in it' % (head, list(CLILOC_PROBES))


def o_bufftimers(c, v):
    """C_BUFFTIMERS: the buff-timer map (key = timer id, a double at node+$28 = seconds left)"""
    hoff = c.v.get('B_STLHEAD')
    if hoff is None:
        return o_ptr_or_null(c, v)
    head = c.p.u32((c.at(v) + hoff) & 0xFFFFFFFF)
    if not head:
        return 'fail', 'no tree head at +$%X' % hoff
    nodes = stl_nodes(c.p, head, 0x10)
    if nodes is None:
        return 'fail', 'head %08X is not a consistent std::map tree' % head
    if not nodes:
        return 'weak', 'an empty tree (no timed buff yet)'
    left = []
    for n, k in nodes:
        d = c.p.read(n + 0x28, 8)
        x = struct.unpack('<d', d)[0] if len(d) == 8 else -1
        if not (0 <= x < 1e7) or not (0 <= k < 100000):
            return 'fail', 'node %08X: timer id %d, seconds %r' % (n, k, x)
        left.append((k, round(x)))
    return 'pass', '%d timers (id, seconds left) %s' % (len(nodes), left[:6])


def o_code(c, v):
    live = c.p.read(c.at(v), 8)
    file = c.t.pe.read(v, 8)
    if live == file:
        return 'weak', 'code bytes match the exe'
    return 'weak', 'code bytes differ from the exe (already hooked?) %s vs %s' % (live.hex(), file.hex())


def o_tick_site(c, v):
    """the per-frame hook: a direct call in a function that is running (seen on a thread stack).
    Necessary, not sufficient -- it tells a live copy of the tick function from a dead twin, not
    which call inside it is the right one -- so the best verdict is 'weak'."""
    k = c.t.code.index(v)
    if k < 0 or c.t.code.mn[k] != 'call' or not c.t.code.op[k].startswith('0x'):
        return 'fail', 'not a direct call'
    f = c.t.code.func_of(v)
    n = c.live_functions().get(f, 0)
    return ('weak' if n else 'fail'), 'function %08X on a thread stack in %d of 20 samples' % (f, n)


def o_import(c, v):
    x = c.p.u32(c.at(v))
    return ('pass' if x and not (c.t.pe.base <= ((x - c.d) & 0xFFFFFFFF) < c.t.pe.hi) else 'weak'), 'IAT slot -> %08X' % (x or 0)


ORACLES = {
    'C_CHARPTR': o_charptr,
    'C_SKILLLOCK': o_skills('lock'), 'C_SKILLCAPS': o_skills('cap'), 'C_SKILLSPOS': o_skills('real'),
    'C_CONTPOS': o_contpos,
    'C_CLIXRES': o_clixres,
    'C_SHARDPOS': o_shard,
    'C_CLILEFT': o_small(-16384, 16384), 'C_NEXTCPOS': o_small(-16384, 16384),
    'C_CLILOGGED': o_small(0, 1, 1), 'C_CURSORKIND': o_small(0, 255, 1),
    'C_SYSMSG': o_ptr_or_null, 'C_JOURNALPTR': o_ptr_or_null, 'C_ENEMYHITS': o_ptr_or_null,
    'C_CLILOC': o_cliloc, 'C_BUFFTIMERS': o_bufftimers, 'E_SENDECX': o_ptr_or_null,
    'E_REDIR': o_tick_site,
    'E_SLEEPADDR': o_import,
}


def check(ctx, field, value):
    if value is None:
        return 'fail', 'no value'
    fn = ORACLES.get(field)
    if fn is None:
        if field.startswith('E_') and ctx.t.pe.is_code(value):
            fn = o_code
        elif field.startswith('C_') or field.startswith('E_'):
            fn = o_ptr_or_null if not ctx.t.pe.is_code(value) else o_code
        else:
            return 'weak', 'no oracle'
    try:
        return fn(ctx, value)
    except Exception as e:                     # an oracle must never stop the run
        return 'weak', 'oracle error: %s' % e
