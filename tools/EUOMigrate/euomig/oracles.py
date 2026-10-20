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
                note += ' (real and base differ: the pair order is confirmed)'
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
    'C_CLILOC': o_ptr_or_null, 'E_SENDECX': o_ptr_or_null,
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
