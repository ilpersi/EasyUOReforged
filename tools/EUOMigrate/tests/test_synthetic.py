"""End-to-end on two synthetic builds of the same program (tests/synth.py): fingerprint build A,
locate its fields in build B, generate signatures on A and scan B, read calling conventions."""
import os
import re
import shutil
import sys
import tempfile
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

import synth                                            # noqa: E402
from euomig.pe import PE                               # noqa: E402
from euomig.disasm import Code                         # noqa: E402
from euomig.features import FuncDB                     # noqa: E402
from euomig.match import Matcher                       # noqa: E402
from euomig import fields as FD, resolve as RS, siggen as SG, conv as CV   # noqa: E402
from euomig.sigs import scan, scan_file                # noqa: E402

FIELDS = ['C_G1', 'C_G2', 'C_G3', 'C_G4', 'E_F2', 'E_F3', 'E_SITE']


def table_of(addrs):
    return {'C_G1': addrs['G1'], 'C_G2': addrs['G2'], 'C_G3': addrs['G3'], 'C_G4': addrs['G4'],
            'E_F2': addrs['f2'], 'E_F3': addrs['f3'], 'E_SITE': addrs['site']}


class Synthetic(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp(prefix='euomig-test-')
        pa, cls.A = synth.build('A', directory=cls.dir)
        pb, cls.B = synth.build('B', directory=cls.dir)
        cls.pa, cls.pb = PE(pa), PE(pb)
        cls.ca, cls.cb = Code(cls.pa, use_cache=False), Code(cls.pb, use_cache=False)
        cls.da, cls.db = FuncDB.from_code(cls.ca), FuncDB.from_code(cls.cb)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def test_pe(self):
        self.assertEqual(self.pa.base, 0x400000)
        self.assertFalse(self.pa.relocatable)
        self.assertTrue(self.pa.is_code(self.A['f1']))
        self.assertFalse(self.pa.is_code(self.A['G1']))
        self.assertIn(self.A['S1'], self.pa.strings())
        self.assertEqual(self.pa.strings()[self.A['S1']], 'SyntheticUniqueString')

    def test_function_starts(self):
        for f in ('f1', 'f2', 'f3', 'f4'):
            self.assertIn(self.A[f], self.ca.funcs, f)
        self.assertEqual(self.ca.func_of(self.A['site']), self.A['f1'])

    def test_features(self):
        i = self.da.index_of(self.A['f1'])
        self.assertIn('S:SyntheticUniqueString', self.da.tok[i])
        self.assertEqual([self.da.start[j] for j in self.da.calls[i]], [self.A['f2']])
        kinds = {(a, k) for a, k, s, m in self.da.gacc[i]}
        self.assertIn((self.A['G1'], 'r'), kinds)
        self.assertIn((self.A['G2'], 'w'), kinds)

    def test_migration(self):
        descs = FD.build(self.ca, self.da, table_of(self.A), FIELDS)
        self.assertEqual(descs['E_SITE']['kind'], 'site')
        self.assertEqual(descs['E_F2']['kind'], 'func')
        self.assertEqual(descs['C_G1']['kind'], 'data')
        M = Matcher(self.da.hashed_view(), self.db.hashed_view()).run()
        res = RS.resolve(descs, M, self.cb)
        want = table_of(self.B)
        for f in FIELDS:
            self.assertEqual(res[f].value, want[f], '%s: %r' % (f, res[f]))

    def test_signatures_survive_the_rebuild(self):
        descs = FD.build(self.ca, self.da, table_of(self.A), FIELDS)
        pairs = SG.generate(self.ca, table_of(self.A), {f: d['kind'] for f, d in descs.items()})
        self.assertTrue(pairs)
        for f, s in pairs:
            self.assertEqual(scan(self.pa, s), [table_of(self.A)[f]], s.to_line())
        found = scan_file(self.pb, [s for f, s in pairs])
        want = table_of(self.B)
        hit = {f for f, s in pairs if found.get(s.name) == want[f]}
        self.assertGreaterEqual(len(hit), 4, found)
        for name, v in found.items():                 # nothing resolves to a wrong value
            self.assertEqual(v, want['C_' + name] if 'C_' + name in want else want['E_' + name])

    def test_progress(self):
        """one line per phase and round; the counts and the deltas add up to the final match"""
        lines = []
        M = Matcher(self.da.hashed_view(), self.db.hashed_view(), log=lines.append).run()
        line = re.compile(r'^(anchors|vtables|similarity|round \d+|pruned): (\d+) matched \(([+-]\d+)\), \d+s$')
        phases, n = [], 0
        for s in lines:
            m = line.match(s)
            self.assertTrue(m, s)
            n += int(m.group(3))
            self.assertEqual(int(m.group(2)), n, s)
            phases.append(m.group(1))
        self.assertEqual(phases[:4], ['anchors', 'vtables', 'similarity', 'round 1'])
        self.assertEqual(phases[-1], 'pruned')
        self.assertEqual(n, len(M.m))

    def test_migrate_reports_progress(self):
        """migrate() prints the matcher's progress under each reference, then its summary"""
        from euomig import kb as KB
        from euomig.consensus import migrate
        descs = FD.build(self.ca, self.da, table_of(self.A), FIELDS)
        ref = KB.KBEntry(KB.make(self.ca, self.da, table_of(self.A), descs, 'test'))
        target = types.SimpleNamespace(db=self.db, pe=self.pb, code=self.cb, relocatable=False)
        lines = []
        migrate(target, [ref], FIELDS, log=lines.append)
        self.assertTrue(lines[0].startswith('matching against '), lines)
        self.assertTrue(lines[1].startswith('  anchors: '), lines)
        self.assertTrue(any(s.startswith('  round 1: ') for s in lines), lines)
        self.assertRegex(lines[-1], r'^  \d+ of \d+ reference functions matched \(closeness [\d.]+\), '
                                    r'\d+ of its signatures hit, \d+s$')

    def test_conventions(self):
        c2 = CV.convention(self.ca, self.A['f2'])
        self.assertEqual(c2['ret'], 4)
        self.assertEqual(c2['inputs'], set())
        c3 = CV.convention(self.ca, self.A['f3'])
        self.assertEqual(c3['ret'], 0)
        self.assertEqual(c3['inputs'], {'ecx'})


if __name__ == '__main__':
    unittest.main()
