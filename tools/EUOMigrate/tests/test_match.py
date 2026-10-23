"""The matcher's shortcuts against the full computation they replace, on random call graphs with hub
functions (called by most others), noise and many ties."""
import collections
import math
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from euomig.features import FuncDB                     # noqa: E402
from euomig.match import Matcher, size_ok              # noqa: E402


def reference_candidates(M, x, top=6, lists=None):
    """neighbour_candidates() as it was before the shortcuts: every candidate list walked in full
    (lists: the candidate lists to use instead of the matcher's)"""
    R, T = M.R, M.T
    sc = collections.Counter()
    if lists is None:
        lists = [[y for y in M.outT[M.m[n]] if y not in M.rev] for n in M.inR[x] if n in M.m]
        lists += [[y for y in M.inT[M.m[n]] if y not in M.rev] for n in M.outR[x] if n in M.m]
    for ys in lists:
        for y in ys:
            sc[y] += 1.0 / math.log2(1 + len(ys))
    scored = []
    for y, s in sc.most_common(top):
        if not size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0) or M.tokens_clash(x, y):
            continue
        ag, dis = M.agreement(x, y)
        jac = ag / max(1, ag + dis)
        scored.append((s * jac, s, ag, jac, y))
    scored.sort(reverse=True)
    return scored


def graphs(rnd, n=400, nhubs=6):
    """R and T = R with its functions shuffled and a few calls changed"""
    hubs = rnd.sample(range(n), nhubs)
    calls = [rnd.sample(hubs, rnd.randint(0, nhubs)) + [rnd.randrange(n) for _ in range(rnd.randint(1, 8))]
             for _ in range(n)]
    sizes = [rnd.choice((6, 8, 12, 20)) for _ in range(n)]       # few sizes: many equal scores
    perm = list(range(n))
    rnd.shuffle(perm)

    def db(calls, sizes):
        d = FuncDB()
        d.start = [0x401000 + 0x10 * i for i in range(n)]
        d.ninsn = sizes
        d.tok = [{} for _ in range(n)]
        d.calls = calls
        d.prefs = [[] for _ in range(n)]
        d.gacc = [[] for _ in range(n)]
        return d
    tcalls, tsizes = [None] * n, [None] * n
    for i in range(n):
        cs = [perm[j] for j in calls[i] if rnd.random() > 0.1]
        if rnd.random() < 0.2:
            cs.append(rnd.randrange(n))
        tcalls[perm[i]] = cs
        tsizes[perm[i]] = sizes[i]
    return db(calls, sizes), db(tcalls, tsizes), perm


def plain(n):
    d = FuncDB()
    d.start = [0x401000 + 0x10 * i for i in range(n)]
    d.ninsn = [10] * n
    d.tok = [{} for _ in range(n)]
    d.calls, d.prefs, d.gacc = [[] for _ in range(n)], [[] for _ in range(n)], [[] for _ in range(n)]
    return d


class HubShortcut(unittest.TestCase):
    def test_same_decisions_on_adversarial_lists(self):
        """many hubs, overlapping lists of few distinct lengths (ties), hubs often listed first,
        random agreements: a candidate seen only through hubs that could win, and ties at the
        sixth place decided by where a candidate was first seen"""
        rnd = random.Random(7)
        U = 120
        M = Matcher(plain(1), plain(U))
        agree = {}
        M.agreement = lambda x, y: agree[y]
        seen = collections.Counter()
        for trial in range(4000):
            for y in range(U):
                agree[y] = (rnd.randint(0, 6), rnd.randint(0, 3))
            pool = rnd.sample(range(U), rnd.choice((40, 60, U)))
            lists = [rnd.sample(pool, rnd.choice((25, 25, 30, 40))) for _ in range(rnd.randint(0, 10))]
            small = [rnd.sample(pool, rnd.choice((1, 2, 3, 3, 4))) for _ in range(rnd.randint(1, 8))]
            lists = lists + small if rnd.random() < 0.5 else rnd.sample(lists + small, len(lists) + len(small))
            src = [[ys, 1.0 / math.log2(1 + len(ys)), None, None] for ys in lists]
            want = M._neighbour_pick(0, reference_candidates(M, 0, lists=lists))
            self.assertEqual(M._neighbour_pick(0, M.neighbour_candidates(0, src=src)), want, trial)
            self.assertEqual(M._neighbour_pick(0, M._neighbour_scored(0, src)), want, trial)
            seen['accepted'] += want is not None
        self.assertGreater(seen['accepted'], 500, seen)

    def test_same_decisions_as_the_full_ranking(self):
        seen = collections.Counter()
        for seed in range(12):
            rnd = random.Random(seed)
            R, T, perm = graphs(rnd)
            for share in (0.3, 0.6, 0.85):
                M = Matcher(R, T)
                M._adjacency()
                for x in rnd.sample(range(len(perm)), int(share * len(perm))):
                    y = perm[x] if rnd.random() > 0.05 else rnd.randrange(len(perm))   # a few wrong
                    M.accept(x, y, 0.5, 'test')
                for x in range(M.nR):
                    if x in M.m:
                        continue
                    want = M._neighbour_pick(x, reference_candidates(M, x))
                    src = M._sources(x)
                    self.assertEqual(M._neighbour_pick(x, M.neighbour_candidates(x, src=src)), want, x)
                    self.assertEqual(M._neighbour_pick(x, M._neighbour_scored(x, src)), want, x)
                    if sum(e[1] for e in src) >= 0.8 and any(len(e[0]) > M.HUB for e in src):
                        seen['hub path'] += 1
                        seen['accepted via hub path'] += want is not None
                    seen['accepted'] += want is not None
        # the cases that matter were exercised
        self.assertGreater(seen['hub path'], 200, seen)
        self.assertGreater(seen['accepted via hub path'], 50, seen)


if __name__ == '__main__':
    unittest.main()
