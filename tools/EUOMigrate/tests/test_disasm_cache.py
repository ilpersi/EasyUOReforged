"""Code's on-disk cache (tests/synth.py build, cache in a temp dir): the cached function starts are the
ones found without a cache, and every extra_starts set gets an entry of its own."""
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

import synth                                            # noqa: E402
from euomig.pe import PE                               # noqa: E402
from euomig.disasm import Code                         # noqa: E402


class DisasmCache(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix='euomig-test-')
        self.cache = os.path.join(self.dir, 'cache')
        env = mock.patch.dict(os.environ, {'EUOMIGRATE_CACHE': self.cache})
        env.start()
        self.addCleanup(env.stop)
        path, self.A = synth.build('A', directory=self.dir)
        self.pe = PE(path)
        self.fresh = Code(self.pe, use_cache=False)

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def test_cached_starts_equal_fresh_ones(self):
        self.assertFalse(os.path.exists(self.cache) and os.listdir(self.cache))
        first = Code(self.pe)                              # sweeps, finds the starts, writes both
        self.assertEqual(len(os.listdir(self.cache)), 2)
        with mock.patch.object(Code, '_find_functions', side_effect=AssertionError('not cached')), \
                mock.patch.object(Code, '_sweep', side_effect=AssertionError('not cached')):
            second = Code(self.pe)
        for c in (first, second):
            self.assertEqual(c.funcs, self.fresh.funcs)
            self.assertEqual(c._fidx, self.fresh._fidx)
            self.assertEqual(c.func_range(self.A['f1']), self.fresh.func_range(self.A['f1']))

    def test_extra_starts_get_their_own_entry(self):
        extra = self.fresh.addr[self.fresh.index(self.A['f1']) + 1]
        self.assertNotIn(extra, self.fresh.funcs)
        plain = Code(self.pe)
        with_extra = Code(self.pe, extra_starts=[extra])
        self.assertIn(extra, with_extra.funcs)
        self.assertEqual(with_extra.funcs, Code(self.pe, use_cache=False, extra_starts=[extra]).funcs)
        self.assertEqual(Code(self.pe, extra_starts=(extra, extra)).funcs, with_extra.funcs)
        self.assertEqual(Code(self.pe).funcs, plain.funcs)
        self.assertEqual(len([n for n in os.listdir(self.cache) if '.funcs-' in n]), 2)


if __name__ == '__main__':
    unittest.main()
