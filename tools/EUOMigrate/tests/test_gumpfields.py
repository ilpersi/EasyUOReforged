"""gumpfields.py: the gump object offsets read from code shapes (ScanGumps).

The code is assembled here by hand, byte by byte, in the shapes the real clients have (see the module's
header and docs/gump-analysis.md section 10), then disassembled with capstone like the real sweep.
"""
import bisect
import os
import struct
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from capstone import Cs, CS_ARCH_X86, CS_MODE_32  # noqa: E402

from euomig import gumpfields as GF  # noqa: E402

BASE = 0x401000


def d(v):
    return struct.pack('<I', v & 0xFFFFFFFF)


class FakeCode:
    """addr / mn / op of a few functions laid end to end, and func_of over their starts"""

    def __init__(self, *funcs):
        blob = bytearray()
        self.funcs = []
        for f in funcs:
            self.funcs.append(BASE + len(blob))
            blob += f
            blob += b'\xCC' * 4
        md = Cs(CS_ARCH_X86, CS_MODE_32)
        md.skipdata = True
        self.addr, self.mn, self.op = [], [], []
        for a, sz, m, o in md.disasm_lite(bytes(blob), BASE):
            self.addr.append(a)
            self.mn.append(m)
            self.op.append(o)

    def index(self, va):
        k = bisect.bisect_left(self.addr, va)
        return k if k < len(self.addr) and self.addr[k] == va else -1

    def func_of(self, va):
        i = bisect.bisect_right(self.funcs, va) - 1
        return self.funcs[i] if i >= 0 else None


def fixed_reply(serial, type_id):
    """the fixed-base builds' reply: mov ebp,ecx; cmp [ebp+serial],0; push 0B1h; call; loads"""
    return (b'\xB8' + d(0x1E60) +                 # mov eax, 1E60h
            b'\x55' + b'\x8B\xE9' +               # push ebp; mov ebp, ecx
            b'\x83\xBD' + d(serial) + b'\x00' +   # cmp dword [ebp+serial], 0
            b'\x57' + b'\x8D\x44\x24\x14' +       # push edi; lea eax, [esp+14h]
            b'\x68' + d(0xB1) + b'\x50' +         # push 0B1h; push eax
            b'\xE8' + d(0x100) +                  # call (packet start)
            b'\x8B\x8D' + d(serial) + b'\x51' +   # mov ecx, [ebp+serial]; push ecx
            b'\xE8' + d(0x100) +                  # call (append dword)
            b'\x8B\x85' + d(type_id) +            # mov eax, [ebp+type_id]
            b'\xC3')


def beta_reply(serial, type_id):
    """the beta's reply: mov esi,ecx; mov edx,[esi+serial]; mov byte [esp+10h],0B1h; ...; type load"""
    return (b'\x55\x8B\xEC' + b'\x56' + b'\x8B\xF1' +   # push ebp; mov ebp,esp; push esi; mov esi,ecx
            b'\x8B\x96' + d(serial) +                    # mov edx, [esi+serial]
            b'\x85\xD2' +                                # test edx, edx
            b'\xC6\x44\x24\x10\xB1' +                    # mov byte [esp+10h], 0B1h
            b'\x8D\x4C\x24\x10' + b'\xE8' + d(0x100) +   # lea ecx,[esp+10h]; call
            b'\x8B\x96' + d(type_id) +                   # mov edx, [esi+type_id]
            b'\xC3')


def art_store(reg_byte, off, const):
    """mov dword [reg+off8], const"""
    return b'\xC7' + bytes([reg_byte, off]) + d(const) + b'\xC3'


def bring_to_front(flag, size=0x24, width='dword'):
    """cmp [edi+flag], ebp; jne; mov eax/ecx from size pair; jmp; mov from minimized pair"""
    if width == 'dword':
        test = b'\x39\xAF' + d(flag)                    # cmp dword [edi+flag32], ebp
    else:
        test = b'\x80\xBF' + d(flag) + b'\x00'          # cmp byte [edi+flag32], 0
    return (test + b'\x75\x08' +
            b'\x8B\x47' + bytes([size]) + b'\x8B\x4F' + bytes([size + 4]) +
            b'\xEB\x06' +
            b'\x8B\x47' + bytes([size + 8]) + b'\x8B\x4F' + bytes([size + 12]) +
            b'\xC3')


class ReplyFields(unittest.TestCase):
    def test_fixed_base_shape(self):
        r = GF.reply_fields(FakeCode(fixed_reply(0xE0, 0xE4)))
        self.assertEqual(r[:2], (0xE0, 0xE4))
        self.assertIn('$B1 gump reply', r[2])

    def test_old_fixed_base_offsets(self):
        self.assertEqual(GF.reply_fields(FakeCode(fixed_reply(0xD8, 0xDC)))[:2], (0xD8, 0xDC))

    def test_beta_shape(self):
        self.assertEqual(GF.reply_fields(FakeCode(beta_reply(0x178, 0x17C)))[:2], (0x178, 0x17C))

    def test_type_id_must_follow_the_serial(self):
        self.assertIsNone(GF.reply_fields(FakeCode(fixed_reply(0xE0, 0xF0))))

    def test_two_different_answers_give_none(self):
        self.assertIsNone(GF.reply_fields(FakeCode(fixed_reply(0xE0, 0xE4), beta_reply(0x178, 0x17C))))

    def test_no_reply_code(self):
        self.assertIsNone(GF.reply_fields(FakeCode(art_store(0x40, 0x6C, 0x4EC))))


class ArtOffset(unittest.TestCase):
    def test_buff_and_status_agree(self):
        r = GF.art_offset(FakeCode(art_store(0x40, 0x6C, 0x4EC), art_store(0x46, 0x6C, 0x2A6C)))
        self.assertEqual(r[0], 0x6C)
        self.assertIn('$2A6C', r[1])

    def test_buff_alone(self):
        self.assertEqual(GF.art_offset(FakeCode(art_store(0x40, 0x70, 0x4EC)))[0], 0x70)

    def test_disagreement_gives_none(self):
        self.assertIsNone(GF.art_offset(FakeCode(art_store(0x40, 0x6C, 0x4EC), art_store(0x46, 0x70, 0x2A6C))))

    def test_status_alone_is_not_enough(self):
        self.assertIsNone(GF.art_offset(FakeCode(art_store(0x46, 0x6C, 0x2A6C))))


class MinimizedOffset(unittest.TestCase):
    def test_fixed_base(self):
        r = GF.minimized_offset(FakeCode(bring_to_front(0x7C)), 0x24)
        self.assertEqual(r[:2], (0x7C, 4))

    def test_beta(self):
        self.assertEqual(GF.minimized_offset(FakeCode(bring_to_front(0x80)), 0x24)[:2], (0x80, 4))

    def test_byte_flag_reports_its_width(self):
        self.assertEqual(GF.minimized_offset(FakeCode(bring_to_front(0x73, width='byte')), 0x24)[:2], (0x73, 1))

    def test_needs_the_size_offset(self):
        self.assertIsNone(GF.minimized_offset(FakeCode(bring_to_front(0x7C)), 0))
        self.assertIsNone(GF.minimized_offset(FakeCode(bring_to_front(0x7C)), 0x20))

    def test_a_tie_gives_none(self):
        self.assertIsNone(GF.minimized_offset(FakeCode(bring_to_front(0x7C), bring_to_front(0x80)), 0x24))


class Derive(unittest.TestCase):
    def test_all_four(self):
        code = FakeCode(fixed_reply(0xE0, 0xE4), art_store(0x40, 0x6C, 0x4EC), bring_to_front(0x7C))
        got = {f: v for f, (v, how) in GF.derive(code, {'B_CONTSIZEX': 0x24}).items()}
        self.assertEqual(got, {'B_GUMPSERIAL': 0xE0, 'B_GUMPTYPE': 0xE4, 'B_GUMPART': 0x6C, 'B_GUMPMIN': 0x7C})

    def test_a_byte_flag_is_flagged(self):
        code = FakeCode(bring_to_front(0x73, width='byte'))
        self.assertIn('NOTE', GF.derive(code, {'B_CONTSIZEX': 0x24})['B_GUMPMIN'][1])

    def test_nothing_found(self):
        self.assertEqual(GF.derive(FakeCode(b'\xC3'), {'B_CONTSIZEX': 0x24}), {})


# ---- the live probe, over synthetic memory -----------------------------------------------------
sys.path.insert(0, os.path.dirname(__file__))
from test_buffbar import FakeProc, ctx_of, BASE as MEMBASE  # noqa: E402
from euomig import probe as PR  # noqa: E402

LAYOUT = {'C_CONTPOS': MEMBASE + 0x10, 'B_CONTNEXT': 0x58, 'B_CONTSIZEX': 0x24, 'B_CONTITEM': 0x4C, 'B_ITEMID': 0xA8}
PACK = 0x40000003


def gump_world(art=0x6C, minflag=0x7C, serial=0xE0, generic=True, minimized=True):
    """front to back: [server gump], buff bar, status bar, the backpack, an item-properties gump"""
    p = FakeProc()
    names = MEMBASE + 0x8000
    item = MEMBASE + 0x9000
    p.put32(item + 0xA8, PACK)
    gumps = []

    def gump(name, art_id, w, h, minw, minh, mn=0, obj=0):
        g = MEMBASE + 0x1000 + 0x300 * len(gumps)
        nm = names + 0x40 * len(gumps)
        p.put(nm, name.encode() + b'\0')
        p.put32(g, 0x50E694)
        p.put32(g + 4, 0xFEEDBEEF)
        p.put32(g + 8, nm)
        for off, v in ((0x24, w), (0x28, h), (0x2C, minw), (0x30, minh)):
            p.put32(g + off, v)
        p.put32(g + 0x4C, obj)
        p.put32(g + art, art_id)
        p.put32(g + minflag, mn)
        p.put32(g + 0xC4, 1)                  # flags that stay 1 on every gump
        p.put32(g + 0xC8, 1)
        gumps.append(g)
        return g

    if generic:
        g = gump('generic gump', 0xFFFFFFFF, 400, 300, 0, 0)
        p.put32(g + serial, 0xE)
        p.put32(g + serial + 4, 0x9E26D92D)
    gump('BuffIcons Gump', 0x4EC, 200, 40, 30, 30)
    gump('status gump', 0x2A6C, 400, 200, 100, 50)
    gump('container gump', 0x3C, 230, 204, 50, 50, obj=item)
    if minimized:
        gump('new item Prop gump', 0x243A, 56, 60, 56, 60, mn=1)
    p.put32(LAYOUT['C_CONTPOS'], gumps[0])
    for a, b in zip(gumps, gumps[1:]):
        p.put32(a + 0x58, b)
    return p, gumps


def probe_of(p):
    pr = PR.Probe(ctx_of(p, LAYOUT))
    pr.backpack_id = PACK
    return pr


class Probe(unittest.TestCase):
    def reopen_for(self, p, gumps, serial):
        def reopen():
            p.put32(gumps[0] + serial, 0x10)      # the server's new serial; the type ID stays
            p.put32(gumps[0] + 0x100, 0x1234)     # and something else changes too, with no fixed neighbour
        return reopen

    def test_fixed_base(self):
        p, gumps = gump_world()
        pr = probe_of(p)
        pr.gumpfields(self.reopen_for(p, gumps, 0xE0))
        got = {f: v for f, (v, how) in pr.found.items()}
        self.assertEqual(got, {'B_GUMPART': 0x6C, 'B_GUMPMIN': 0x7C, 'B_GUMPSERIAL': 0xE0, 'B_GUMPTYPE': 0xE4}, pr.notes)

    def test_beta(self):
        p, gumps = gump_world(art=0x70, minflag=0x80, serial=0x178)
        pr = probe_of(p)
        pr.gumpfields(self.reopen_for(p, gumps, 0x178))
        got = {f: v for f, (v, how) in pr.found.items()}
        self.assertEqual(got, {'B_GUMPART': 0x70, 'B_GUMPMIN': 0x80, 'B_GUMPSERIAL': 0x178, 'B_GUMPTYPE': 0x17C}, pr.notes)

    def test_without_reopen_the_serial_stays_inherited(self):
        p, gumps = gump_world()
        pr = probe_of(p)
        pr.gumpfields()
        self.assertNotIn('B_GUMPSERIAL', pr.found)
        self.assertTrue(any('--gump' in n for n in pr.notes), pr.notes)

    def test_no_server_gump(self):
        p, gumps = gump_world(generic=False)
        pr = probe_of(p)
        pr.gumpfields(lambda: None)
        self.assertNotIn('B_GUMPTYPE', pr.found)
        self.assertIn('B_GUMPART', pr.found)
        self.assertTrue(any('no server gump' in n for n in pr.notes), pr.notes)

    def test_nothing_minimized_is_a_note(self):
        p, gumps = gump_world(minimized=False)
        pr = probe_of(p)
        pr.gumpfields()
        self.assertNotIn('B_GUMPMIN', pr.found)
        self.assertTrue(any('minimized' in n for n in pr.notes), pr.notes)

    def test_one_art_anchor_is_not_enough(self):
        p, gumps = gump_world()
        pr = probe_of(p)
        pr.backpack_id = None
        p.put(MEMBASE + 0x8000 + 0x40 * 2, b'other gump\0')     # the status gump renamed
        pr.gumpfields()
        self.assertNotIn('B_GUMPART', pr.found)

    def test_walk_stops_without_the_marker(self):
        p, gumps = gump_world()
        p.put32(gumps[2] + 4, 0)
        self.assertEqual(len(probe_of(p).gump_list()), 2)


if __name__ == '__main__':
    unittest.main()
