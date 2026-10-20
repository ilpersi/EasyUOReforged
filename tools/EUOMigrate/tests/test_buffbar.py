"""The buff bar oracle and probe against synthetic client memory (no game files, no process).

The memory is laid out the way the clients keep it: a gump list with a 'BuffIcons Gump' whose
std::vector of $1B0-byte icon entries sits at a gump offset, a cliloc manager (std::map<int,char*>)
and a buff-timer map. Two generations are built: the beta's (tree head in the first dword, cliloc key
at +$10) and the fixed-base clients' (head one dword in, key at +$0C).
"""
import os
import struct
import sys
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from euomig import oracles as OR, probe as PR           # noqa: E402

BASE = 0x1000000
ARR = BASE + 0x10000


class FakeProc:
    """just enough of live.Process over a byte array"""
    def __init__(self):
        self.mem = bytearray(0x20000)

    def read(self, addr, n):
        o = addr - BASE
        if o < 0 or o + n > len(self.mem):
            return b''
        return bytes(self.mem[o:o + n])

    def u8(self, a):
        d = self.read(a, 1)
        return d[0] if d else None

    def u16(self, a):
        d = self.read(a, 2)
        return struct.unpack('<H', d)[0] if len(d) == 2 else None

    def u32(self, a):
        d = self.read(a, 4)
        return struct.unpack('<I', d)[0] if len(d) == 4 else None

    def readable(self, a, n=4):
        return len(self.read(a, n)) == n

    def put32(self, a, v):
        struct.pack_into('<I', self.mem, a - BASE, v & 0xFFFFFFFF)

    def put(self, a, b):
        self.mem[a - BASE:a - BASE + len(b)] = b

    def putd(self, a, v):
        struct.pack_into('<d', self.mem, a - BASE, v)


def build(old_stl):
    """(proc, values, expected) for one client generation"""
    p = FakeProc()
    hoff, koff, vec = (4, 0x0C, 0xD0) if old_stl else (0, 0x10, 0x15C)
    nxt = 0x58
    # gump list: menubar -> BuffIcons Gump
    p.put(BASE + 0x100, b'menubar\0')
    p.put(BASE + 0x120, b'BuffIcons Gump\0')
    G1, G2 = BASE + 0x1000, BASE + 0x2000
    p.put32(BASE + 0x40, G1)                              # C_CONTPOS (link == live here)
    p.put32(G1 + 8, BASE + 0x100)
    p.put32(G1 + nxt, G2)
    p.put32(G2 + 8, BASE + 0x120)
    ents = BASE + 0x4000
    p.put32(G2 + vec, ents)
    p.put32(G2 + vec + 4, ents + 3 * 0x1B0)
    p.put32(G2 + vec + 8, ents + 4 * 0x1B0)
    for i, (icon, dur, timer, title, desc) in enumerate([
            (0x7565, 0, -1, 1075655, 1075656),
            (0x7542, 120, 4, 1075847, 1075848),
            (0x7548, 120, 5, 1075835, 1075836)]):
        e = ents + i * 0x1B0
        p.put32(e, icon)
        p.put32(e + 4, dur)
        p.put32(e + 8, timer)
        p.put32(e + 0xC, title)
        p.put32(e + 0xDC, desc)
    # cliloc: global -> manager -> head; node key at koff, text pointer after it
    mgr, head = BASE + 0x6000, BASE + 0x6100
    p.put32(BASE + 0x50, mgr)                             # C_CLILOC
    p.put32(mgr + hoff, head)
    texts = {1075655: b'Hidden/Stealthing', 1075656: b'You are hidden.', 1075835: b'Curse',
             1075836: b'-~1_STR~% Strength.', 1075847: b'Bless', 1075848: b'+~1_STR~% Strength.'}
    keys = sorted(texts)
    nodes = {k: BASE + 0x6200 + 0x40 * i for i, k in enumerate(keys)}
    for i, k in enumerate(keys):                          # a chain: each node's right child is the next
        n = nodes[k]
        p.put32(n, head)
        p.put32(n + 8, nodes[keys[i + 1]] if i + 1 < len(keys) else head)
        p.put32(n + koff, k)
        t = BASE + 0x7000 + 0x40 * i
        p.put(t, texts[k] + b'\0')
        p.put32(n + koff + 4, t)
    p.put32(head + 4, nodes[keys[0]])
    # timers: C_BUFFTIMERS is the head pointer itself (beta) or the map object (head at +4)
    timers_obj = BASE + 0x60
    thead = BASE + 0x8000
    p.put32(timers_obj + hoff, thead)
    t4, t5 = BASE + 0x8100, BASE + 0x8200
    p.put32(thead + 4, t4)
    p.put32(t4, thead)
    p.put32(t4 + 8, t5)
    p.put32(t4 + 0x10, 4)
    p.putd(t4 + 0x28, 104.0)
    p.put32(t5, thead)
    p.put32(t5 + 8, thead)
    p.put32(t5 + 0x10, 5)
    p.putd(t5 + 0x28, 55.5)
    # the fake image sits at BASE, so link-time addresses are BASE + offset
    values = {'C_CONTPOS': BASE + 0x40, 'C_CLILOC': BASE + 0x50, 'C_BUFFTIMERS': BASE + 0x60, 'B_CONTNEXT': nxt}
    return p, values, {'B_BUFFVEC': vec, 'B_BUFFSIZE': 0x1B0, 'B_STLHEAD': hoff, 'B_CLILOCKEY': koff}


def ctx_of(p, values):
    return types.SimpleNamespace(p=p, v=dict(values), at=lambda a: a, cls_of_object=lambda o: None)


class BuffBar(unittest.TestCase):
    def check_generation(self, old_stl):
        p, values, want = build(old_stl)
        # the oracles, given the right layout
        c = ctx_of(p, dict(values, **want))
        v, note = OR.o_cliloc(c, values['C_CLILOC'])
        self.assertEqual(v, 'pass', note)
        self.assertIn('Bless', note)
        v, note = OR.o_bufftimers(c, values['C_BUFFTIMERS'])
        self.assertEqual(v, 'pass', note)
        self.assertIn('(4, 104)', note)
        # ... and a wrong layout is not accepted
        bad = ctx_of(p, dict(values, B_STLHEAD=8, B_CLILOCKEY=want['B_CLILOCKEY']))
        self.assertNotEqual(OR.o_cliloc(bad, values['C_CLILOC'])[0], 'pass')
        self.assertEqual(OR.o_bufftimers(bad, values['C_BUFFTIMERS'])[0], 'fail')
        # the probe finds all four offsets from nothing but the memory
        pr = PR.Probe(ctx_of(p, values))
        pr.buffbar()
        got = {f: v for f, (v, how) in pr.found.items()}
        self.assertEqual(got, want, pr.notes)

    def test_beta_generation(self):
        self.check_generation(False)

    def test_fixed_base_generation(self):
        self.check_generation(True)

    def test_no_buff_window_is_a_note_not_a_guess(self):
        p, values, _ = build(False)
        p.put(BASE + 0x120, b'paperdoll gump\0')
        pr = PR.Probe(ctx_of(p, values))
        pr.buffbar()
        self.assertEqual(pr.found, {})
        self.assertTrue(any('BuffIcons' in n for n in pr.notes))

    def test_empty_bar_finds_no_vector(self):
        p, values, _ = build(False)
        G2 = BASE + 0x2000
        p.put32(G2 + 0x15C + 4, p.u32(G2 + 0x15C))        # end == begin
        pr = PR.Probe(ctx_of(p, values))
        pr.buffbar()
        self.assertNotIn('B_BUFFVEC', pr.found)

    def test_empty_timer_map_is_weak_and_a_wrong_address_fails(self):
        p, values, want = build(False)
        thead = p.u32(values['C_BUFFTIMERS'])
        p.put32(thead + 4, thead)                         # root == head: no timers
        c = ctx_of(p, dict(values, **want))
        self.assertEqual(OR.o_bufftimers(c, values['C_BUFFTIMERS'])[0], 'weak')
        self.assertEqual(OR.o_bufftimers(c, BASE + 0x9000)[0], 'fail')

    def test_cliloc_oracle_without_layout_falls_back(self):
        p, values, _ = build(False)
        v, _ = OR.o_cliloc(ctx_of(p, values), values['C_CLILOC'])      # no B_STLHEAD in the values
        self.assertEqual(v, 'weak')


if __name__ == '__main__':
    unittest.main()
