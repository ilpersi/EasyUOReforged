"""The uoclidata.pas reader against the repository's golden fixture, and the Pascal emitter."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from euomig.tables import UoCliData, golden, GOLDEN     # noqa: E402
from euomig import emit as EM                           # noqa: E402


class Tables(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.u = UoCliData()

    @unittest.skipUnless(os.path.exists(GOLDEN), 'golden fixture not found')
    def test_matches_golden_fixture(self):
        bad = []
        n = 0
        for cli, want in golden().items():
            got = self.u.resolve(cli)
            for f, v in want.items():
                n += 1
                if got.get(f, 0) != v:
                    bad.append((cli, f, got.get(f), v))
        self.assertGreater(n, 1000)
        self.assertEqual(bad[:5], [])

    def test_lookup(self):
        idx, exact = self.u.milestone_index('7.0.117.1')
        self.assertTrue(exact)
        idx2, exact2 = self.u.milestone_index('7.0.29.97')       # between two known versions
        self.assertFalse(exact2)
        self.assertGreater(idx2, idx)

    def test_modern_build(self):
        st = self.u.modern_stamps()
        self.assertTrue(st)
        t = self.u.exact_table('7.0.117.1', st[0], True)
        self.assertTrue(t['C_CHARPTR'])
        self.assertIsNone(self.u.exact_table('7.0.117.1', 0x12345678, True))


def fake(u, relocatable, values, statuses=None):
    statuses = statuses or {}
    fields = {}
    for f in u.fields:
        v = values.get(f, 0)
        st = statuses.get(f, 'accepted' if v else 'unused')
        if f[:2] in ('B_', 'F_'):
            st = 'inherited'
        fields[f] = {'value': v, 'conf': 0.9, 'status': st, 'how': 'test', 'alts': [], 'checks': []}
    return {'tool': '1', 'created': '2026-01-01T00:00:00', 'base': 'test', 'references': [],
            'target': {'path': 'x.exe', 'version': '7.0.29.97', 'stamp': 0x515F178B,
                       'relocatable': relocatable, 'sha256': '0', 'id': 'test'},
            'fields': fields}


class Pascal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.u = UoCliData()

    def test_relocatable_entry(self):
        c = fake(self.u, True, {'C_CHARPTR': 0x00B33F44, 'E_REDIR': 0x0057C6F9, 'E_OLDDIR': 0x006A1160})
        s = EM.pascal(c, self.u)
        self.assertIn('SysVarModernAddrs_515F178B', s)
        self.assertIn('(Expr: C_CHARPTR; Val: $00B33F44)', s)
        self.assertIn('(Expr: E_REDIR; Val: $0057C6F9)', s)
        self.assertIn('(Stamp: $515F178B; Layout: @SysVarModernLayout', s)

    def test_unverified_and_incomplete_groups_are_zero(self):
        c = fake(self.u, True, {'C_CHARPTR': 0x00B33F44, 'E_REDIR': 0x0057C6F9, 'E_OLDDIR': 0x006A1160},
                 {'E_OLDDIR': 'candidate'})
        s = EM.pascal(c, self.u)
        self.assertIn('(Expr: E_OLDDIR; Val: $00000000)', s)
        self.assertIn('(Expr: E_REDIR; Val: $00000000)', s)        # its partner is not usable
        self.assertIn('event hook group is incomplete', s)

    def test_fixed_base_delta(self):
        floor, idx = self.u.floor_state('7.0.29.97')
        v = dict((f, floor[f]) for f in floor if f[:2] in ('C_', 'E_') and floor[f])
        v['C_CHARPTR'] = 0x00ABC6D4
        c = fake(self.u, False, v)
        s = EM.pascal(c, self.u)
        self.assertIn('SysVarMS_7_0_29_97', s)
        self.assertIn('(Expr: C_CHARPTR; Val: $00ABC6D4)', s)
        self.assertIn("(Cli: '7.0.29.97'; Milestone: %d)" % idx, s)
        # unchanged fields are not repeated in the delta
        same = [f for f in v if f != 'C_CHARPTR' and v[f] == floor[f]]
        self.assertTrue(same)
        self.assertNotIn('(Expr: %s;' % same[0], s)


if __name__ == '__main__':
    unittest.main()
