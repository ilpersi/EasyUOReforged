"""End-to-end on two synthetic builds of the same program (tests/synth.py): fingerprint build A,
locate its fields in build B, generate signatures on A and scan B, read calling conventions.
Also: objects and gumps without RTTI (probe, oracles), the message-flag oracle, the global-relative
offsets (fields.RELATIVE / FOLLOWS), superseded knowledge-base values, the runtime-scan emulation and
the macro executor's convention behind an SEH prologue."""
import os
import re
import shutil
import struct
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
from euomig.sigs import scan, scan_file, runtime_scan  # noqa: E402
from euomig import oracles as OR, probe as PR           # noqa: E402
from euomig import kb as KB                             # noqa: E402
from euomig.consensus import Migration, migrate        # noqa: E402
from euomig.resolve import Result                       # noqa: E402
from test_buffbar import FakeProc, BASE as MEMBASE      # noqa: E402

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


# ---- objects without RTTI (7.0.119.0) --------------------------------------------------------------
ID = 0x120              # where the serial sits on 7.0.119.0
CHARPTR = MEMBASE + 0x40


def object_world(vt, rep=(3, 7), extra=None):
    """a player, its backpack with four items, and a vendor, chained by [obj+ID+$C]; each object's first
    dword is vt. rep: the notoriety of the player and the vendor at id+$218; extra: {offset: (player,
    vendor)} more dwords on the two mobiles"""
    p = FakeProc()
    slot = [MEMBASE + 0x1000 + 0x600 * i for i in range(7)]
    player, pack, items, vendor = slot[0], slot[1], slot[2:6], slot[6]
    order = [player, pack] + items + [vendor]
    for i, o in enumerate(order):
        p.put32(o, vt)
        p.put32(o + ID + 0xC, order[i + 1] if i + 1 < len(order) else 0)
    p.put32(CHARPTR, player)
    p.put32(player + ID, 1)
    p.put(player + 0x70, struct.pack('<H', 0x190))           # human body
    p.put32(pack + ID, 0x40000003)
    p.put32(pack + ID + 4, player)
    p.put(pack + 0x70, struct.pack('<H', 0x0E75))           # backpack
    p.put(pack + ID + 0x25, bytes([21]))                    # layer 21
    for i, o in enumerate(items):
        p.put32(o + ID, 0x40000010 + i)
        p.put32(o + ID + 4, pack)
        p.put(o + 0x70, struct.pack('<H', 0x0EED))
    p.put32(vendor + ID, 0x2A)
    p.put(vendor + 0x70, struct.pack('<H', 0x190))
    p.put32(player + ID + 0x218, rep[0])
    p.put32(vendor + ID + 0x218, rep[1])
    for off, (a, b) in (extra or {}).items():
        p.put32(player + ID + off, a)
        p.put32(vendor + ID + off, b)
    return p, player


def live_ctx(p, pe, values):
    """an oracles.Ctx over fake memory at delta 0: no RTTI anywhere, the vtable test reads the exe"""
    c = types.SimpleNamespace(p=p, t=types.SimpleNamespace(pe=pe), d=0, v=dict(values),
                              at=lambda a: a, cls_of_object=lambda o: None)
    c.has_vtable = lambda ptr: OR.Ctx.has_vtable(c, ptr)
    return c


class ObjectsWithoutRTTI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp(prefix='euomig-test-')
        path, cls.A = synth.build('A', directory=cls.dir)
        cls.pe = PE(path)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def probe(self, vt, **kw):
        p, player = object_world(vt, **kw)
        pr = PR.Probe(live_ctx(p, self.pe, {'C_CHARPTR': CHARPTR, 'B_ITEMID': 0x118}))
        pr.objects()
        pr.findrep()
        return pr

    def test_vtable_rule(self):
        self.assertTrue(OR.vtable_at(self.pe, self.A['VT']))
        self.assertFalse(OR.vtable_at(self.pe, self.A['S1']))          # text, not code pointers
        self.assertFalse(OR.vtable_at(self.pe, self.A['G1']))          # writable data
        self.assertFalse(OR.vtable_at(self.pe, self.A['f1']))          # code itself

    def test_object_list_and_notoriety(self):
        pr = self.probe(self.A['VT'])
        got = {f: v for f, (v, how) in pr.found.items()}
        self.assertEqual(got.get('B_ITEMID'), ID, pr.notes)
        self.assertIn('vtable (no RTTI)', pr.found['B_ITEMID'][1])
        self.assertEqual(got.get('B_ITEMTYPE'), 0x70)
        self.assertEqual(got.get('B_ITEMSLOT'), 0x25)
        self.assertEqual(got.get('B_FINDREP'), 0x218, pr.notes)
        self.assertIn('player 3', pr.found['B_FINDREP'][1])

    def test_no_vtable_no_objects(self):
        for bad in (self.A['G1'], self.A['S1']):
            pr = self.probe(bad)
            self.assertNotIn('B_ITEMID', pr.found)
            self.assertTrue(any('no offset gives' in n for n in pr.notes), pr.notes)

    def test_notoriety_prefers_the_offset_that_varies(self):
        pr = self.probe(self.A['VT'], extra={0x300: (2, 2)})        # a constant 2 on both mobiles
        self.assertEqual(pr.found['B_FINDREP'][0], 0x218, pr.notes)

    def test_notoriety_ambiguous_is_a_note(self):
        pr = self.probe(self.A['VT'], rep=(3, 3), extra={0x300: (2, 2)})
        self.assertNotIn('B_FINDREP', pr.found)
        self.assertTrue(any('notoriety: 2 offsets' in n for n in pr.notes), pr.notes)

    def test_gump_list_without_rtti(self):
        p = FakeProc()
        g1, g2 = MEMBASE + 0x1000, MEMBASE + 0x2000
        for g, name in ((g1, b'status gump\0'), (g2, b'paperdoll gump\0')):
            p.put32(g, self.A['VT'])
            p.put32(g + 4, 0xFEEDBEEF)
            p.put32(g + 8, g + 0x400)
            p.put(g + 0x400, name)
        p.put32(g1 + 0x58, g2)
        p.put32(MEMBASE + 0x50, g1)
        c = live_ctx(p, self.pe, {'C_CONTPOS': MEMBASE + 0x50})
        pr = PR.Probe(c)
        pr.gumps()
        self.assertEqual(pr.found.get('B_CONTNEXT', (None,))[0], 0x58, pr.notes)
        self.assertIn('status gump', pr.found['B_CONTNEXT'][1])
        self.assertEqual(OR.o_contpos(c, MEMBASE + 0x50)[0], 'pass')
        p.put32(g1 + 4, 0)                                          # no marker: not a gump
        self.assertEqual(OR.o_contpos(c, MEMBASE + 0x50)[0], 'weak')

    def test_charptr_oracle(self):
        p, player = object_world(self.A['VT'])
        c = live_ctx(p, self.pe, {'B_ITEMID': ID})
        self.assertEqual(OR.o_charptr(c, CHARPTR)[0], 'pass')
        # the inherited offset, 8 before the serial: weak (probe tells the offset), not fail
        c.v['B_ITEMID'] = 0x118
        v, note = OR.o_charptr(c, CHARPTR)
        self.assertEqual(v, 'weak', note)
        self.assertIn('+$120', note)
        # no serial anywhere near, or a null pointer: fail
        c.v['B_ITEMID'] = 0x300
        self.assertEqual(OR.o_charptr(c, CHARPTR)[0], 'fail')
        self.assertEqual(OR.o_charptr(c, MEMBASE + 0x44)[0], 'fail')


class FlagOracle(unittest.TestCase):
    def test_message_flags(self):
        p = FakeProc()
        c = types.SimpleNamespace(p=p, at=lambda a: a)
        fa, fb = OR.ORACLES['E_MSGFLAGA'], OR.ORACLES['E_MSGFLAGB']
        for byte, want in ((0, 'weak'), (1, 'weak'), (5, 'fail')):
            p.put(MEMBASE + 0x10, bytes([byte]))
            self.assertEqual(fa(c, MEMBASE + 0x10)[0], want, byte)
        for dw, want in ((0, 'weak'), (1, 'weak'), (0x00D99000, 'fail')):
            p.put32(MEMBASE + 0x20, dw)
            self.assertEqual(fb(c, MEMBASE + 0x20)[0], want, dw)
        self.assertEqual(fa(c, 0x10)[0], 'fail')                  # unreadable

    def test_direction(self):
        """C_CHARDIR holds the last step's direction byte, not a pointer: 7.0.119.0's read 06 06 42 00
        after walking, which the pointer check used to reject"""
        p = FakeProc()
        c = types.SimpleNamespace(p=p, at=lambda a: a)
        fd = OR.ORACLES['C_CHARDIR']
        for b, want in ((0, 'weak'), (6, 'weak'), (0x86, 'weak'), (0x42, 'fail')):
            p.put(MEMBASE + 0x10, bytes([b, 6, 0x42, 0]))
            self.assertEqual(fd(c, MEMBASE + 0x10)[0], want, b)


# ---- global-relative offsets ---------------------------------------------------------------------
class RelativeFields(unittest.TestCase):
    TABLE = {'C_LHANDID': 0x500000, 'B_LHAND': 0x24, 'B_LTARGTILE': 0x38, 'B_LTARGKIND': 0,
             'C_LLIFTEDID': 0x600000, 'B_LLIFTEDTYPE': 0x24, 'B_LLIFTEDKIND': 0xFFFFFFCC}

    def test_pseudo_fields(self):
        ps = FD.pseudo_fields(self.TABLE, lambda a: True)
        self.assertEqual(ps['@B_LHAND']['addr'], 0x500020)          # the slot before the left hand
        self.assertEqual(ps['@B_LHAND']['rel'], ['B_LHAND', 'C_LHANDID', 1, -4])
        self.assertEqual(ps['@B_LTARGKIND']['addr'], 0x50003C)      # 0: B_LTARGTILE + 4
        self.assertEqual(ps['@B_LLIFTEDTYPE']['addr'], 0x600000 - 0x24)   # read at id - B_LLIFTEDTYPE
        self.assertEqual(ps['@B_LLIFTEDKIND']['addr'], 0x600000 - 0x34)
        self.assertNotIn('@B_RHAND', ps)                             # follows B_LHAND instead
        legacy = FD.pseudo_fields({'C_LHANDID': 0x500000}, lambda a: True)
        self.assertEqual(legacy['@B_LHAND']['addr'], 0x500000 - 4)  # B_LHAND 0: left hand at the base

    def test_getter_defaults(self):
        self.assertEqual(FD.relative_value({'B_LTARGTILE': 0x20}, 'B_LTARGKIND'), 0x24)
        self.assertEqual(FD.getter_default({'B_LHAND': 0xFFFFFFFC}, 'B_RHAND'), 0)    # 7.0.118.132
        self.assertEqual(FD.getter_default({}, 'B_RHAND'), 4)
        self.assertIsNone(FD.getter_default({}, 'B_LLIFTEDTYPE'))

    def test_relative_layout(self):
        ps = FD.pseudo_fields(self.TABLE, lambda a: True)
        t, lift = 0x700000, 0x800000
        res = {'C_LHANDID': Result('C_LHANDID', t, 0.9, 'x'), 'C_LLIFTEDID': Result('C_LLIFTEDID', lift, 0.9, 'x'),
               '@B_LHAND': Result('@B_LHAND', t + 0x20, 0.9, 'votes'),
               '@B_LTARGKIND': Result('@B_LTARGKIND', t + 0x40, 0.9, 'votes'),
               '@B_LLIFTEDTYPE': Result('@B_LLIFTEDTYPE', lift - 0x30, 0.9, 'votes'),
               '@B_LLIFTEDKIND': Result('@B_LLIFTEDKIND', lift + 0x1C, 0.4, 'votes')}    # too unsure
        fake = types.SimpleNamespace(primary=types.SimpleNamespace(ref=types.SimpleNamespace(fields=ps)), results=res)
        out = {f: v for f, (v, how) in Migration.relative_layout(fake).items()}
        self.assertEqual(out, {'B_LHAND': 0x24, 'B_RHAND': 0x28, 'B_LTARGKIND': 0x40, 'B_LLIFTEDTYPE': 0x30})

    def test_kb_entry_fills_in_pseudo_fields(self):
        d = {'schema': KB.KB_SCHEMA, 'build': {'version': '1.0', 'stamp': 1, 'base': 0x400000, 'image_size': 0x1000000},
             'table': self.TABLE, 'funcdb': FuncDB().to_json(),
             'fields': {'@B_RHAND': {'kind': 'data', 'addr': 1, 'value': 1, 'rel': ['B_RHAND', 'C_LHANDID', 1]},
                        '@B_LHAND': {'kind': 'data', 'addr': 0x500010, 'value': 0x500010,
                                     'rel': ['B_LHAND', 'C_LHANDID', 1, -4]}}}
        e = KB.KBEntry(d)
        self.assertNotIn('@B_RHAND', e.fields)                       # no longer a RELATIVE field
        self.assertEqual(e.fields['@B_LHAND']['addr'], 0x500010)     # what the fingerprint stored stays
        self.assertEqual(e.fields['@B_LLIFTEDTYPE']['addr'], 0x600000 - 0x24)    # added from the table
        self.assertEqual(e.superseded, {})

    def test_hands_table_located_through_the_matcher(self):
        """the arm/disarm code names the hands table only as [hand*4 + table]: it is found anyway, and
        build B moved it 4 bytes further from C_LHANDID"""
        d = tempfile.mkdtemp(prefix='euomig-test-')
        try:
            pa, A = synth.build('A', directory=d, program=synth.program_hands)
            pb, B = synth.build('B', directory=d, program=synth.program_hands)
            ca, cb = Code(PE(pa), use_cache=False), Code(PE(pb), use_cache=False)
            da, db = FuncDB.from_code(ca), FuncDB.from_code(cb)
            table = {'C_LHANDID': A['LH'], 'B_LHAND': A['LHAND']}
            descs = FD.build(ca, da, table, ['C_LHANDID', 'B_LHAND'])
            self.assertEqual(descs['@B_LHAND']['addr'], A['TABLE'])
            M = Matcher(da.hashed_view(), db.hashed_view()).run()
            res = RS.resolve(descs, M, cb)
            self.assertEqual(res['C_LHANDID'].value, B['LH'], res['C_LHANDID'])
            self.assertEqual(res['@B_LHAND'].value, B['TABLE'], res['@B_LHAND'])
            self.assertEqual(res['@B_LHAND'].value + 4 - res['C_LHANDID'].value, B['LHAND'])
            self.assertNotEqual(A['LHAND'], B['LHAND'])
        finally:
            shutil.rmtree(d, ignore_errors=True)


# ---- a knowledge-base value EasyUO no longer means --------------------------------------------------
class Superseded(unittest.TestCase):
    setUpClass = classmethod(Synthetic.setUpClass.__func__)          # the two synthetic builds
    tearDownClass = classmethod(Synthetic.tearDownClass.__func__)

    def ref(self, superseded=None):
        descs = FD.build(self.ca, self.da, table_of(self.A), FIELDS)
        r = KB.KBEntry(KB.make(self.ca, self.da, table_of(self.A), descs, 'test'))
        r.superseded = superseded or {}
        return r

    def run_migration(self, refs):
        target = types.SimpleNamespace(db=self.db, pe=self.pb, code=self.cb, relocatable=False)
        return migrate(target, refs, FIELDS)

    def test_left_out_of_the_pool(self):
        mig = self.run_migration([self.ref({'C_G1': 'another meaning'}), self.ref()])
        r = mig.results['C_G1']
        self.assertEqual(r.value, table_of(self.B)['C_G1'])
        self.assertIn('left out: another meaning', r.how)
        self.assertEqual(mig.results['C_G2'].value, table_of(self.B)['C_G2'])

    def test_only_reference_gives_nothing(self):
        mig = self.run_migration([self.ref({'C_G1': 'another meaning'})])
        self.assertIsNone(mig.results['C_G1'].value)
        self.assertIn('left out', mig.results['C_G1'].how)

    def test_known_entry(self):
        self.assertIn('C_ENEMYHITS', KB.SUPERSEDED['7.0.117.1-6AC94360'])


# ---- the runtime scan, emulated -------------------------------------------------------------------
class RuntimeScan(unittest.TestCase):
    setUpClass = classmethod(Synthetic.setUpClass.__func__)          # the two synthetic builds
    tearDownClass = classmethod(Synthetic.tearDownClass.__func__)

    def test_modes_and_last_wins(self):
        A = self.A
        hx = bytes.fromhex
        entries = [
            ('C_X', hx('B968245713A111111111'), 0x11, 3, 6, 0),       # mov ecx,imm; mov eax,[G1]: the dword
            ('E_F1', hx('558BECB9'), 0x11, 1, 0, 0),                  # the address (f1, not f4)
            ('E_F2', hx('6811111111E811111111A3'), 0x11, 2, 6, 0),    # follow the call: f2
            ('C_D', hx('B968245713A111111111'), 0x11, 4, 1, 6),       # a distance: imm - [G1 operand]
            ('C_X', hx('A3111111115EC3'), 0x11, 3, 1, 0),             # a later line for C_X decides: G4
            ('C_X', hx('DEADBEEF'), 0x11, 3, 0, 0),                   # no match: changes nothing
        ]
        got = runtime_scan(self.pa, entries)
        self.assertEqual(got['C_X'], A['G4'])
        self.assertEqual(got['E_F1'], A['f1'])
        self.assertEqual(got['E_F2'], A['f2'])
        self.assertEqual(got['C_D'], (0x13572468 - A['G1']) & 0xFFFFFFFF)


# ---- calling conventions: the macro executor ------------------------------------------------------
class MacroConvention(unittest.TestCase):
    def test_fastcall_behind_seh_and_chkstk(self):
        d = tempfile.mkdtemp(prefix='euomig-test-')
        try:
            for variant, inputs, word in (('A', {'ecx', 'edx'}, 'fastcall'), ('B', set(), 'no register inputs')):
                path, addrs = synth.build(variant, directory=d, program=synth.program_macro)
                code = Code(PE(path), use_cache=False)
                c = CV.convention(code, addrs['f1'])
                self.assertEqual(c['inputs'], inputs, variant)
                notes = CV.notes(code, {'E_MACROADDR': addrs['f1']})
                self.assertEqual(len(notes), 1)
                self.assertIn(word, notes[0])
            self.assertEqual(CV.notes(code, {}), [])
        finally:
            shutil.rmtree(d, ignore_errors=True)


if __name__ == '__main__':
    unittest.main()
