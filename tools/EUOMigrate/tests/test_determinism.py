"""The matcher gives the same result in every process. Tokens are strings, and Python salts the hash
of a string per process (PYTHONHASHSEED), so a loop over a set of tokens runs in a different order
each time; through ties and float sums that order once changed which functions were matched."""
import json
import os
import random
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from euomig.features import FuncDB                     # noqa: E402
from euomig.match import Matcher                       # noqa: E402


def dbs(n=300, seed=5):
    """R and T = R with its functions shuffled and a few calls dropped. Half the functions have a
    token of their own on both sides (anchors), every fourth of those is in T next to the token of
    another function (two R functions tie for one T function), and globals are read through a
    shifted address."""
    rnd = random.Random(seed)
    perm = list(range(n))
    rnd.shuffle(perm)
    R, T = FuncDB(), FuncDB()
    for d in (R, T):
        d.start = [0x401000 + 0x10 * i for i in range(n)]
        d.ninsn = [0] * n
        d.tok = [{} for _ in range(n)]
        d.calls = [[] for _ in range(n)]
        d.prefs = [[] for _ in range(n)]
        d.gacc = [[] for _ in range(n)]
    for i in range(n):
        j = perm[i]
        R.ninsn[i] = T.ninsn[j] = rnd.choice((10, 20, 40))
        R.calls[i] = [rnd.randrange(n) for _ in range(rnd.randint(0, 5))]
        T.calls[j] = [perm[c] for c in R.calls[i] if rnd.random() > 0.1]
        gs = [0x800000 + 4 * rnd.randrange(60) for _ in range(rnd.randint(0, 4))]
        R.gacc[i] = [(g, 'r', 4, 'mov') for g in gs]
        T.gacc[j] = [(g + 0x1000, 'r', 4, 'mov') for g in gs]
        for k in rnd.sample(range(40), rnd.randint(0, 3)):         # shared, for similarity
            R.tok[i]['K:%x' % (0x1000 + k)] = T.tok[j]['K:%x' % (0x1000 + k)] = 1
        if rnd.random() < 0.5:
            t = rnd.choice('SIV') + ':%012x' % rnd.getrandbits(48)
            R.tok[i][t] = 1
            T.tok[perm[i - 1] if rnd.random() < 0.25 else j][t] = 1
    return R, T


def result():
    M = Matcher(*dbs()).run()
    return {'m': list(M.m.items()), 'conf': list(M.conf.items()), 'how': list(M.how.items()),
            'votes': [(a, list(c.items())) for a, c in M.global_votes().items()]}


class SameInEveryProcess(unittest.TestCase):
    def test_hash_seeds(self):
        code = 'import json, test_determinism as t; print(json.dumps(t.result()))'
        outs = []
        for seed in ('0', '1', '2', '3'):
            p = subprocess.run([sys.executable, '-c', code], cwd=HERE, capture_output=True, text=True,
                               env=dict(os.environ, PYTHONHASHSEED=seed))
            self.assertEqual(p.returncode, 0, p.stderr)
            outs.append(json.loads(p.stdout))
        self.assertTrue(outs[0]['m'] and outs[0]['votes'])
        for o in outs[1:]:
            self.assertEqual(o, outs[0])


if __name__ == '__main__':
    unittest.main()
