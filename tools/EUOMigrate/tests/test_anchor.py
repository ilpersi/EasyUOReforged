"""A base-only field (fields.ANCHOR) on two synthetic builds whose globals around the base were
reordered: C_LHANDID must follow the member EasyUO reads (+$0C), not the global at the base.

The 7.0.117.1 beta (6AC94360) keeps a macro wait counter at C_LHANDID and its limit elsewhere; the
7.0.117.31 beta (6AD6CEB3) keeps the limit at the base and the counter at base+4. Locating the
counter put C_LHANDID, and every B_ distance measured from it, 4 too high there."""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

import synth                                            # noqa: E402
from euomig.pe import PE                               # noqa: E402
from euomig.disasm import Code                         # noqa: E402
from euomig.features import FuncDB                     # noqa: E402
from euomig.match import Matcher                       # noqa: E402
from euomig import fields as FD, resolve as RS, siggen as SG   # noqa: E402
from euomig.sigs import scan                           # noqa: E402


def cluster(variant):
    """counter, limit, flag byte, last used object. Build B swaps the counter and the limit and
    moves every global by 16, the code stays the same."""
    base = synth.BASE + synth.DATA + (16 if variant == 'B' else 0)
    cnt, lim = (base + 4, base) if variant == 'B' else (base, base + 4)
    flag, lobj = base + 8, base + 0x0C
    a = synth.Asm(synth.BASE + synth.TEXT)
    a.label('f1')                              # tick: counter += 1, compared with its limit, reset
    a.raw(0x56)                                # push esi
    a.raw(0xB9); a.d(0x13572468)               # mov ecx, 13572468h  (two constants per function:
    a.raw(0xBA); a.d(0x0BADBEEF)               # mov edx, 0BADBEEFh   enough for an anchor match)
    a.raw(0xA1); a.d(cnt)                      # mov eax, [cnt]
    a.raw(0x40)                                # inc eax
    a.raw(0xA3); a.d(cnt)                      # mov [cnt], eax
    a.raw(0x3B, 0x05); a.d(lim)                # cmp eax, [lim]
    a.raw(0xC7, 0x05); a.d(cnt); a.d(0)        # mov dword [cnt], 0
    a.raw(0xC6, 0x05); a.d(flag); a.raw(0x00)  # mov byte [flag], 0
    a.raw(0x5E, 0xC3)                          # pop esi; ret
    a.pad()
    a.label('use')                             # use an object: stores it as the last used one
    a.raw(0x55, 0x8B, 0xEC)                    # push ebp; mov ebp, esp
    a.raw(0xBA); a.d(0x2468ACE0)               # mov edx, 2468ACE0h
    a.raw(0x8B, 0x45, 0x08)                    # mov eax, [ebp+8]
    a.raw(0xA3); a.d(lobj)                     # mov [lobj], eax
    a.raw(0xB9); a.d(0x11223344)               # mov ecx, 11223344h
    a.raw(0x5D, 0xC3)                          # pop ebp; ret
    a.pad()
    a.label('macro')                           # starts the wait, reads the last used object
    a.raw(0x56)                                # push esi
    a.raw(0x8B, 0xF1)                          # mov esi, ecx
    a.raw(0xB8); a.d(0x5A5A1234)               # mov eax, 5A5A1234h
    a.raw(0xBA); a.d(0x7654ABCD)               # mov edx, 7654ABCDh
    a.raw(0xC6, 0x05); a.d(flag); a.raw(0x01)  # mov byte [flag], 1
    a.raw(0xC7, 0x05); a.d(cnt); a.d(0)        # mov dword [cnt], 0
    a.raw(0x8B, 0x0D); a.d(lobj)               # mov ecx, [lobj]
    a.raw(0x89, 0x4E, 0x04)                    # mov [esi+4], ecx
    a.raw(0x5E, 0xC3)                          # pop esi; ret
    a.pad(16)
    addrs = dict(a.labels, base=base, cnt=cnt, lim=lim, lobj=lobj)
    return a.done(), b'ClusterTest\0', addrs


class BaseOnlyField(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp(prefix='euomig-test-')
        pa, cls.A = synth.build('A', directory=cls.dir, program=cluster)
        pb, cls.B = synth.build('B', directory=cls.dir, program=cluster)
        cls.pa, cls.pb = PE(pa), PE(pb)
        cls.ca, cls.cb = Code(cls.pa, use_cache=False), Code(cls.pb, use_cache=False)
        cls.da, cls.db = FuncDB.from_code(cls.ca), FuncDB.from_code(cls.cb)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def test_layout(self):
        self.assertEqual(FD.ANCHOR['C_LHANDID'], self.A['lobj'] - self.A['base'])
        self.assertEqual(self.A['cnt'], self.A['base'])
        self.assertEqual(self.B['cnt'], self.B['base'] + 4)

    def test_located_through_its_member(self):
        descs = FD.build(self.ca, self.da, {'C_LHANDID': self.A['base']}, ['C_LHANDID'])
        self.assertEqual(descs['C_LHANDID'], {'kind': 'data', 'addr': self.A['base'], 'value': self.A['base']})
        M = Matcher(self.da.hashed_view(), self.db.hashed_view()).run()
        r = RS.resolve(descs, M, self.cb)['C_LHANDID']
        self.assertEqual(r.value, self.B['base'], r)
        self.assertTrue(r.accepted, r)
        self.assertIn('+$C', r.how)
        self.assertNotIn(self.B['cnt'], [v for v, c, h in r.alts])

    def test_signatures_read_the_member(self):
        for (code, pe, mine), (other_pe, theirs) in (((self.ca, self.pa, self.A), (self.pb, self.B)),
                                                     ((self.cb, self.pb, self.B), (self.pa, self.A))):
            pairs = SG.generate(code, {'C_LHANDID': mine['base']}, {'C_LHANDID': 'data'})
            self.assertTrue(pairs)
            for f, s in pairs:
                self.assertEqual(s.adjust, -0x0C, s.to_line())
                self.assertEqual(scan(pe, s), [mine['base']], s.to_line())
                self.assertEqual(scan(other_pe, s), [theirs['base']], s.to_line())


if __name__ == '__main__':
    unittest.main()
