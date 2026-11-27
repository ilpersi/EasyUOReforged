"""propfields.py and the C_PROPCACHE oracle: the tooltip cache layout (scanprops).

The code is assembled by hand in the shapes the real clients have (docs/property-cache-analysis.md):
the fixed-base property check and name builder, the betas' check and their walk over announced
entries; then disassembled with capstone like the real sweep. The oracle runs on a synthetic cache.
"""
import os
import struct
import sys
import types
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from capstone import Cs, CS_ARCH_X86, CS_MODE_32  # noqa: E402

from euomig import propfields as PF, oracles as OR  # noqa: E402

BASE = 0x401000


def d(v):
    return struct.pack('<I', v & 0xFFFFFFFF)


class FakeCode:
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

    def func_of(self, va):
        best = None
        for f in self.funcs:
            if f <= va:
                best = f
        return best


FIX_CACHE = 0x75F004
BETA_CACHE = 0x22F8FD8


def fixed_check():
    # mov ecx,CACHE; call +0; mov ecx,[eax]; xor eax,eax; cmp byte [ecx+10h],4; pop esi; sete al; ret
    return (b'\x56\xB9' + d(FIX_CACHE) + b'\xE8' + d(0) + b'\x8B\x08\x33\xC0\x80\x79\x10\x04\x5E\x0F\x94\xC0\xC3')


def fixed_name_builder():
    # mov ecx,CACHE; call +0; mov esi,[eax]; test esi,esi; je +7; mov eax,[esi+4]; mov eax,[eax]; ret
    return (b'\xB9' + d(FIX_CACHE) + b'\xE8' + d(0) + b'\x8B\x30\x85\xF6\x74\x05\x8B\x46\x04\x8B\x00\xC3')


def beta_check():
    # push ebp; mov ebp,esp; call +0; mov eax,[ebp-0Ch]; mov eax,[eax+14h]; mov eax,[eax+4]; pop esi; ...; ret
    return (b'\x55\x8B\xEC\xE8' + d(0) + b'\x8B\x45\xF4\x8B\x40\x14\x8B\x40\x04\x5E\x8B\xE5\x5D\xC3')


def beta_walk():
    # mov ecx,[CACHE]; mov esi,[ecx]; mov eax,[esi+14h]; test eax,eax; je; cmp byte [eax+0Ch],4; jne; ret
    return (b'\x8B\x0D' + d(BETA_CACHE) + b'\x8B\x31\x8B\x46\x14\x85\xC0\x74\x06'
            b'\x80\x78\x0C\x04\x75\x00\xC3')


class Derive(unittest.TestCase):
    def test_fixed_base(self):
        code = FakeCode(fixed_check(), fixed_name_builder())
        r = PF.derive(code, {'C_PROPCACHE': FIX_CACHE, 'E_ITEMCHECKADDR': code.funcs[0], 'B_CLILOCKEY': 0xC})
        self.assertEqual(r['B_PROPSTATE'][0], 0x10)
        self.assertEqual(r['B_PROPLIST'][0], 4)

    def test_beta(self):
        code = FakeCode(beta_walk(), beta_check())
        r = PF.derive(code, {'C_PROPCACHE': BETA_CACHE, 'E_ITEMCHECKADDR': code.funcs[1], 'B_CLILOCKEY': 0x10})
        self.assertEqual(r['B_PROPSTATE'][0], 0xC)
        self.assertEqual(r['B_PROPLIST'][0], 0)

    def test_nothing_without_the_cache(self):
        code = FakeCode(fixed_check(), fixed_name_builder())
        self.assertEqual(PF.derive(code, {}), {})

    def test_another_global_is_not_the_cache(self):
        code = FakeCode(fixed_check(), fixed_name_builder())
        self.assertNotIn('B_PROPSTATE', PF.derive(code, {'C_PROPCACHE': FIX_CACHE + 0x40}))


BASEMEM = 0x1000000


class FakeProc:
    def __init__(self):
        self.mem = bytearray(0x4000)

    def read(self, addr, n):
        o = addr - BASEMEM
        if o < 0 or o + n > len(self.mem):
            return b''
        return bytes(self.mem[o:o + n])

    def u8(self, a):
        x = self.read(a, 1)
        return x[0] if x else None

    def u32(self, a):
        x = self.read(a, 4)
        return struct.unpack('<I', x)[0] if len(x) == 4 else None

    def readable(self, a, n=4):
        return len(self.read(a, n)) == n

    def put32(self, a, v):
        struct.pack_into('<I', self.mem, a - BASEMEM, v & 0xFFFFFFFF)

    def put8(self, a, v):
        self.mem[a - BASEMEM] = v


def cache_world(state=0, cliloc=1020000):
    """the beta's layout: map object = head pointer; node key +$10, entry +$14; list +0, state +$C"""
    p = FakeProc()
    obj, head, node, ent = BASEMEM + 0x10, BASEMEM + 0x100, BASEMEM + 0x200, BASEMEM + 0x300
    p.put32(obj, head)
    p.put32(head + 4, node)
    p.put32(node, head)
    p.put32(node + 8, head)
    p.put32(node + 0x10, 0x40000001)
    p.put32(node + 0x14, ent)
    lh, ln, line = BASEMEM + 0x400, BASEMEM + 0x420, BASEMEM + 0x440
    p.put32(ent, lh)
    p.put8(ent + 0xC, state)
    p.put32(lh, ln)
    p.put32(ln, lh)
    p.put32(ln + 8, line)
    p.put32(line, cliloc)
    v = {'B_STLHEAD': 0, 'B_CLILOCKEY': 0x10, 'B_PROPLIST': 0, 'B_PROPSTATE': 0xC}
    return p, obj, v


def ctx_of(p, values):
    return types.SimpleNamespace(p=p, v=dict(values), at=lambda a: a, cls_of_object=lambda o: None)


class Oracle(unittest.TestCase):
    def test_pass(self):
        p, obj, v = cache_world()
        r, note = OR.o_propcache(ctx_of(p, v), obj)
        self.assertEqual(r, 'pass', note)

    def test_bad_state_fails(self):
        p, obj, v = cache_world(state=9)
        self.assertEqual(OR.o_propcache(ctx_of(p, v), obj)[0], 'fail')

    def test_line_without_a_cliloc_fails(self):
        p, obj, v = cache_world(cliloc=7)
        self.assertEqual(OR.o_propcache(ctx_of(p, v), obj)[0], 'fail')

    def test_wrong_list_offset_is_not_a_pass(self):
        p, obj, v = cache_world()
        v['B_PROPLIST'] = 4
        self.assertNotEqual(OR.o_propcache(ctx_of(p, v), obj)[0], 'pass')

    def test_registered(self):
        self.assertIs(OR.ORACLES['C_PROPCACHE'], OR.o_propcache)


if __name__ == '__main__':
    unittest.main()
