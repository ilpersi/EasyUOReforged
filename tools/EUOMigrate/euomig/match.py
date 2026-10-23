"""Function matching between a reference build R and a target build T (both FuncDB, hashed tokens),
then mapping of global variables through the matched functions.

Order of evidence, strongest first:
  1. anchors      a token found in exactly one function on each side (a unique string, API, class)
  2. vtables      the same RTTI class: slot i of R's vtable <-> slot i of T's vtable
  3. similarity   rare-token overlap (weighted), mutual best with a margin
  4. propagation  aligned call sequences / pointer references of already matched pairs
Nothing is matched on a single weak hint: every acceptance needs a mutual best and a margin, so an
unmatched function is preferred to a wrong one.

Speed (a large build has ~35,000 functions, run() up to 36 rounds over all of them): the rounds
reuse what has not changed -- the alignments of call and global-access sequences whose labels are
the same as last round, the free candidate lists of each matched function within a pass of
neighbours() -- and neighbours() does not walk the long candidate lists of hub functions (operator
new, ...) where they cannot change its decision. Every shortcut gives exactly the decisions of the
full computation, in the same order.
"""
import collections
import difflib
import heapq
import math
import operator
import time

KIND_W = {'S': 1.0, 'V': 1.0, 'I': 0.6, 'K': 0.35}


def tw(t):
    return KIND_W.get(t[0], 0.3)


def size_ok(a, b, lo=0.25, hi=4.0):
    a, b = max(a, 1), max(b, 1)
    r = b / a
    return lo <= r <= hi


class Matcher:
    def __init__(self, R, T, log=None, opts=None):
        self.R, self.T = R, T
        self.opts = dict(order=True, prune=True)
        self.opts.update(opts or {})
        self.m = {}            # R idx -> T idx
        self.rev = {}          # T idx -> R idx
        self.conf = {}         # R idx -> confidence 0..1
        self.how = {}          # R idx -> evidence label
        self.log = log or (lambda *a: None)
        self.dfR = R.token_freq()
        self.dfT = T.token_freq()
        self.nR, self.nT = len(R.start), len(T.start)
        self._rare = ({}, {})  # R / T idx -> its tokens with df <= 8
        self._calign = {}      # (r, t, calls|prefs) -> (labels R, labels T, votes): propagate()
        self._galign = {}      # (r, t) -> aligned global pairs: global_votes()

    # ---- bookkeeping ------------------------------------------------------------------------
    def accept(self, r, t, conf, how):
        if r in self.m or t in self.rev:
            return False
        self.m[r] = t
        self.rev[t] = r
        self.conf[r] = conf
        self.how[r] = how
        return True

    def run(self, rounds=12):
        """one progress line per phase and per round: 'round 3: 21450 matched (+812), 41s'"""
        t0 = time.time()
        last = [0]

        def progress(what):
            n = len(self.m)
            self.log('%s: %d matched (%+d), %.0fs' % (what, n, n - last[0], time.time() - t0))
            last[0] = n

        self.anchors()
        progress('anchors')
        self.vtables()
        progress('vtables')
        self.similarity()
        progress('similarity')
        self._adjacency()
        k = 0
        for p in range(3):
            for i in range(rounds):
                before = len(self.m)
                self.propagate()
                self.neighbours()
                if self.opts['order']:
                    self.order()
                self.coreference()
                self.similarity(restrict=True)
                k += 1
                progress('round %d' % k)
                if len(self.m) == before:
                    break
            dropped = self.prune() if self.opts['prune'] else 0
            progress('pruned')
            if not dropped:
                break
        return self

    # ---- call-graph adjacency (both directions, calls and pointer refs) --------------------------
    def _adjacency(self):
        def adj(db):
            out = [set() for _ in db.start]
            inn = [set() for _ in db.start]
            for i in range(len(db.start)):
                for j in db.calls[i]:
                    out[i].add(j)
                    inn[j].add(i)
                for j in db.prefs[i]:
                    out[i].add(j)
                    inn[j].add(i)
            return out, inn
        self.outR, self.inR = adj(self.R)
        self.outT, self.inT = adj(self.T)
        self.nbR = [a | b for a, b in zip(self.inR, self.outR)]
        self.nbT = [a | b for a, b in zip(self.inT, self.outT)]

    # ---- structural agreement of a (candidate) pair ----------------------------------------------
    def agreement(self, x, y):
        """(agree, disagree): matched neighbours of x whose image is / is not a neighbour of y, plus
        matched neighbours of y that are not images of x's neighbours"""
        nx = self.nbR[x]
        ny = self.nbT[y]
        agree = dis = 0
        for n in nx:
            if n in self.m:
                if self.m[n] in ny:
                    agree += 1
                else:
                    dis += 1
        for n in ny:
            if n in self.rev and self.rev[n] not in nx:
                dis += 1
        return agree, dis

    def rare(self, side, i):
        """the tokens of function i of R (side 0) / T (side 1) that occur in at most 8 functions"""
        c = self._rare[side]
        r = c.get(i)
        if r is None:
            db, df = (self.R, self.dfR) if side == 0 else (self.T, self.dfT)
            r = c[i] = {t for t in db.tok[i] if df[t] <= 8}
        return r

    def tokens_clash(self, x, y):
        rt = self.rare(0, x)
        tt = self.rare(1, y)
        return bool(rt and tt and not (rt & tt))

    def _sources(self, x, free_only=True, memo=None):
        """where neighbour_candidates' votes for x come from, in its order: per matched caller n of x
        the callees of m[n], per matched callee n the callers of m[n] (only the unmatched ones if
        free_only), as [ys, weight, set(ys) or None, {y: position} or None]. memo keeps these per
        (T function, direction) while rev does not change."""
        out = []
        for d, nb, adj in ((0, self.inR[x], self.outT), (1, self.outR[x], self.inT)):
            for n in nb:
                if n in self.m:
                    t = self.m[n]
                    e = memo.get((t, d)) if memo is not None else None
                    if e is None:
                        ys = [y for y in adj[t] if not (free_only and y in self.rev)]
                        e = [ys, 1.0 / math.log2(1 + len(ys)) if ys else 0.0, None, None]
                        if memo is not None:
                            memo[(t, d)] = e
                    if e[0]:
                        out.append(e)
        return out

    def neighbour_candidates(self, x, top=6, free_only=True, src=None):
        """[(score*agreement, score, agree, agreement, y)] best first, for ref function x"""
        sc = {}
        for ys, w, _, _ in (src if src is not None else self._sources(x, free_only)):
            for y in ys:
                sc[y] = sc.get(y, 0) + w
        # = Counter.most_common(top): ties stay in the order the candidates were first seen
        return self._scored(x, heapq.nlargest(top, sc.items(), key=operator.itemgetter(1)))

    def _scored(self, x, top):
        R, T = self.R, self.T
        scored = []
        for y, s in top:
            if not size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0) or self.tokens_clash(x, y):
                continue
            ag, dis = self.agreement(x, y)
            jac = ag / max(1, ag + dis)
            scored.append((s * jac, s, ag, jac, y))
        scored.sort(reverse=True)
        return scored

    HUB = 24        # a candidate list longer than this is a hub's (operator new, ...) in neighbours()

    def _neighbour_scored(self, x, src, top=6):
        """neighbour_candidates(x) as far as neighbours() needs it, without walking hub lists.

        neighbours() keeps x only if the winner has comb = score * agreement >= 0.8 and
        comb >= 1.5 * the runner-up's comb. The hubs' lists get weights 1/log2(1 + len) that add up
        to H <= 0.5; a candidate found only through hubs, or with a score <= H anyway, cannot
        reach 0.8 nor, at <= 1.5 * H < 0.8, make the winner miss its margin. So only the candidates
        of the other lists (with their hub weights added, in the same order) that score above H
        are ranked; they are exactly the top of the full ranking. Floats only ever add positive
        weights in the original order, so no sum here exceeds the one it bounds."""
        tot = 0.0
        for e in src:
            tot += e[1]
        if tot < 0.8:                       # no candidate can score 0.8
            return []
        big = sorted((i for i, e in enumerate(src) if len(e[0]) > self.HUB), key=lambda i: -len(src[i][0]))
        hub, acc = set(), 0.0
        for i in big:                       # longest lists = smallest weights first
            if acc + src[i][1] > 0.5:
                break
            hub.add(i)
            acc += src[i][1]
        H = 0.0
        for i in sorted(hub):
            H += src[i][1]
        if not hub or H > 0.52:
            return self.neighbour_candidates(x, top, src=src)
        sc = {}
        for i, e in enumerate(src):
            if i not in hub:
                for y in e[0]:
                    sc[y] = 0
        for i, e in enumerate(src):         # each score adds its weights in the original order
            ys, w = e[0], e[1]
            if i in hub:
                if e[2] is None:
                    e[2] = set(ys)
                st = e[2]
                for y in sc:
                    if y in st:
                        sc[y] += w
            else:
                for y in ys:
                    sc[y] += w
        above = [y for y, s in sc.items() if s > H]
        if len(above) > top:
            def first_seen(y):
                for i, e in enumerate(src):
                    if e[3] is None:
                        e[3] = {v: k for k, v in enumerate(e[0])}
                    k = e[3].get(y)
                    if k is not None:
                        return i, k
            above.sort(key=lambda y: (-sc[y], first_seen(y)))
            del above[top:]
        return self._scored(x, [(y, sc[y]) for y in above])

    def twins(self, y, x=None, min_jac=0.6):
        """target functions that look like copies of y (same rare tokens, mostly the same callees):
        e.g. two renderer variants of the main loop. Only one of them may be the live one."""
        T = self.T
        toks = set(T.tok[y])
        callees = set(T.calls[y])
        if len(callees) < 3:
            return []
        cand = collections.Counter()
        for j in callees:
            for i in self.inT[j]:
                if i != y:
                    cand[i] += 1
        out = []
        for i, n in cand.most_common(10):
            if n < 3:
                break
            cj = set(T.calls[i])
            # mostly the same callees, seen from the smaller of the two
            share = len(callees & cj) / max(1, min(len(callees), len(cj)))
            if share < 0.75 or len(toks & set(T.tok[i])) < 0.8 * len(toks):
                continue
            out.append((share, i))
        out.sort(reverse=True)
        return [i for _, i in out]

    # ---- 5. neighbours: an unmatched function whose callers/callees are matched -----------------
    def neighbours(self):
        """Candidates come from matched callers (their unmatched callees) and matched callees (their
        unmatched callers); a pointer from a neighbour with few unmatched alternatives weighs more.
        The winner must also agree structurally: most of its matched neighbours are images of x's."""
        cand = {}
        memo = {}                          # rev does not change before the accepts below
        for x in range(self.nR):
            if x in self.m:
                continue
            c = self._neighbour_pick(x, self._neighbour_scored(x, self._sources(x, memo=memo)))
            if c is not None:
                cand[x] = c
        bestT = {}
        for x, (y, s, jac) in cand.items():
            if s > bestT.get(y, (None, 0))[1]:
                bestT[y] = (x, s)
        for x, (y, s, jac) in cand.items():
            if bestT[y][0] == x:
                self.accept(x, y, min(0.85, 0.3 + 0.1 * s) * (0.5 + 0.5 * jac), 'neighbours')

    def _neighbour_pick(self, x, scored):
        """neighbours()' candidate for x from its scored list: (y, comb, jac), or None"""
        if not scored:
            return None
        comb, s, ag, jac, y = scored[0]
        comb2 = scored[1][0] if len(scored) > 1 else 0.0
        if jac < 0.4 or comb < 0.8 or comb < 1.5 * comb2:
            return None
        if ag < 2 and not (s >= 1.0 and size_ok(self.R.ninsn[x], self.T.ninsn[y], 0.5, 2.0)):
            return None
        return y, comb, jac

    # ---- 5b. address order: functions of one object file stay in order ----------------------------
    def order(self, maxgap=8):
        """Between two consecutive matched functions whose images are in the same order, the
        unmatched functions in between pair up one to one when the gaps are equally long (tiny
        compiler-generated helpers on the target side are skipped first)."""
        R, T = self.R, self.T
        ms = sorted(self.m.items())
        for (a, ta), (b, tb) in zip(ms, ms[1:]):
            if b - a < 2 or not (ta < tb) or tb - ta > 4 * maxgap:
                continue
            ur = [x for x in range(a + 1, b) if x not in self.m]
            ut = [y for y in range(ta + 1, tb) if y not in self.rev]
            if not ur or len(ur) > maxgap:
                continue
            if len(ut) != len(ur):
                small = min(R.ninsn[x] for x in ur)
                ut = [y for y in ut if T.ninsn[y] >= min(8, small)]
                if len(ut) != len(ur):
                    continue
            for x, y in zip(ur, ut):
                if not size_ok(R.ninsn[x], T.ninsn[y], 0.4, 2.5) or self.tokens_clash(x, y):
                    continue
                ag, dis = self.agreement(x, y)
                if dis > ag:
                    continue
                self.accept(x, y, 0.45 + 0.1 * min(ag, 3), 'order')

    # ---- consistency cleanup ---------------------------------------------------------------------
    def prune(self, keep=('anchor',)):
        """drop matches that their matched neighbours contradict. Across a compiler change a right
        match still loses some neighbours to different inlining (anchors, which are nearly always
        right, agree ~80% there), so only a near-total contradiction counts."""
        drop = []
        for x, y in self.m.items():
            if self.how[x] in keep:
                continue
            ag, dis = self.agreement(x, y)
            if (ag == 0 and dis >= 3) or (ag + dis >= 6 and ag < 0.2 * (ag + dis)):
                drop.append(x)
        for x in drop:
            y = self.m.pop(x)
            del self.rev[y]
            del self.conf[x]
            del self.how[x]
        return len(drop)

    def consistency(self, x):
        y = self.m.get(x)
        if y is None:
            return None
        ag, dis = self.agreement(x, y)
        return ag, dis

    # ---- 6. global co-reference: functions touching the same (already mapped) globals ------------
    def coreference(self, minshared=2):
        R, T = self.R, self.T
        gmap = self.global_map(min_weight=1.5)
        if not gmap:
            return
        usersT = collections.defaultdict(set)
        for j, ga in enumerate(T.gacc):
            if j in self.rev:
                continue
            for g in ga:
                usersT[g[0]].add(j)
        cand = {}
        for x, ga in enumerate(R.gacc):
            if x in self.m or not ga:
                continue
            mapped = {gmap[g[0]] for g in ga if g[0] in gmap}
            if len(mapped) < minshared:
                continue
            sc = collections.Counter()
            for g in mapped:
                us = usersT.get(g, ())
                if len(us) > 60:
                    continue
                w = 1.0 / math.log2(len(us) + 1.5)
                for j in us:
                    sc[j] += w
            if not sc:
                continue
            best = sc.most_common(2)
            y, s = best[0]
            s2 = best[1][1] if len(best) > 1 else 0
            if s < 1.0 or s < 1.5 * s2:
                continue
            if not size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0):
                continue
            cand[x] = (y, s)
        bestT = {}
        for x, (y, s) in cand.items():
            if s > bestT.get(y, (None, 0))[1]:
                bestT[y] = (x, s)
        for x, (y, s) in cand.items():
            if bestT[y][0] == x:
                self.accept(x, y, min(0.8, 0.3 + 0.15 * s), 'globals')

    def global_map(self, min_weight=1.5, margin=2.0):
        """confident R global -> T global (top vote clearly ahead of the runner-up)"""
        out = {}
        for a, c in self.global_votes(replace=False).items():
            top = c.most_common(2)
            w = top[0][1]
            w2 = top[1][1] if len(top) > 1 else 0
            if w >= min_weight and w >= margin * w2:
                out[a] = top[0][0]
        return out

    # ---- 1. anchors -------------------------------------------------------------------------
    def anchors(self):
        R, T = self.R, self.T
        uniqR = {t for t, n in self.dfR.items() if n == 1}
        uniqT = {t for t, n in self.dfT.items() if n == 1}
        both = uniqR & uniqT
        whereR, whereT = {}, {}
        for i, d in enumerate(R.tok):
            for t in d:
                if t in both:
                    whereR[t] = i
        for i, d in enumerate(T.tok):
            for t in d:
                if t in both:
                    whereT[t] = i
        score = collections.defaultdict(float)
        for t in both:
            score[(whereR[t], whereT[t])] += tw(t)
        bestR, bestT = {}, {}
        for (r, t), s in score.items():
            if s > bestR.get(r, (None, 0))[1]:
                bestR[r] = (t, s)
            if s > bestT.get(t, (None, 0))[1]:
                bestT[t] = (r, s)
        for r, (t, s) in bestR.items():
            if bestT.get(t, (None,))[0] != r or s < 0.6:
                continue
            if not size_ok(R.ninsn[r], T.ninsn[t], 0.15, 6.0):
                continue
            # a second, different target with a comparable score means ambiguity
            alt = max((s2 for (r2, t2), s2 in score.items() if r2 == r and t2 != t), default=0)
            if alt > 0.7 * s:
                continue
            self.accept(r, t, min(1.0, 0.5 + 0.25 * s), 'anchor')

    # ---- 2. vtables ---------------------------------------------------------------------------
    def vtables(self):
        R, T = self.R, self.T
        votes = collections.Counter()
        for cls, vtsR in R.vtables.items():
            vtsT = T.vtables.get(cls)
            if not vtsT or not vtsR:
                continue
            a, b = vtsR[0], vtsT[0]
            if len(a) != len(b):
                # slot counts differ: only trust the common prefix when it is long
                if min(len(a), len(b)) < 6:
                    continue
            for x, y in zip(a, b):
                if x >= 0 and y >= 0:
                    votes[(x, y)] += 1
        byR = collections.defaultdict(list)
        for (x, y), n in votes.items():
            byR[x].append((n, y))
        byT = collections.defaultdict(list)
        for (x, y), n in votes.items():
            byT[y].append((n, x))
        for x, lst in byR.items():
            lst.sort(reverse=True)
            n, y = lst[0]
            if len(lst) > 1 and lst[1][0] * 2 > n:
                continue
            lt = sorted(byT[y], reverse=True)
            if lt[0][1] != x or (len(lt) > 1 and lt[1][0] * 2 > lt[0][0]):
                continue
            if size_ok(R.ninsn[x], T.ninsn[y], 0.2, 5.0):
                self.accept(x, y, 0.8, 'vtable')

    # ---- 3. rare-token similarity -------------------------------------------------------------
    def similarity(self, restrict=False, maxdf=8):
        R, T = self.R, self.T
        idx = collections.defaultdict(list)
        for j, d in enumerate(T.tok):
            if j in self.rev:
                continue
            for t in d:
                if self.dfT[t] <= maxdf:
                    idx[t].append(j)

        def wt(t):
            return tw(t) * (1.0 / math.sqrt(self.dfR.get(t, 1) * self.dfT.get(t, 1)))

        cand = {}
        for i, d in enumerate(R.tok):
            if i in self.m:
                continue
            sc = collections.defaultdict(float)
            tot = 0.0
            for t in d:
                if self.dfR[t] > maxdf:
                    continue
                w = wt(t)
                tot += w
                for j in idx.get(t, ()):
                    sc[j] += w
            if not sc:
                continue
            best = sorted(sc.items(), key=lambda kv: -kv[1])[:2]
            j, s = best[0]
            s2 = best[1][1] if len(best) > 1 else 0.0
            if s < 0.5 or s < 1.6 * s2:
                continue
            totT = sum(wt(t) for t in T.tok[j] if self.dfT[t] <= maxdf)
            jac = s / max(tot + totT - s, 1e-9)
            if jac < 0.35:
                continue
            cand[i] = (j, s, jac)
        # mutual best
        bestT = {}
        for i, (j, s, jac) in cand.items():
            if s > bestT.get(j, (None, 0))[1]:
                bestT[j] = (i, s)
        for i, (j, s, jac) in cand.items():
            if bestT[j][0] == i and size_ok(R.ninsn[i], T.ninsn[j], 0.2, 5.0):
                self.accept(i, j, min(0.95, 0.3 + 0.6 * jac), 'similar')

    # ---- 4. propagation through call sequences ----------------------------------------------------
    def propagate(self):
        R, T = self.R, self.T
        votes = {}
        for r, t in list(self.m.items()):
            for which, seqR, seqT in ((0, R.calls[r], T.calls[t]), (1, R.prefs[r], T.prefs[t])):
                if not seqR or not seqT:
                    continue
                # a matched function is labelled with its image (>= 0), an unmatched one with its
                # size class (-1 .. -5); a pair whose labels did not change votes as last round
                la = [self.m[x] if x in self.m else -1 - min(4, int(math.log2(R.ninsn[x] + 1)) // 2) for x in seqR]
                lb = [y if y in self.rev else -1 - min(4, int(math.log2(T.ninsn[y] + 1)) // 2) for y in seqT]
                c = self._calign.get((r, t, which))
                if c is None or c[0] != la or c[1] != lb:
                    vs = []
                    sm = difflib.SequenceMatcher(None, la, lb, autojunk=False)
                    for tag, i1, i2, j1, j2 in sm.get_opcodes():
                        if tag == 'equal':
                            for d in range(i2 - i1):
                                x, y = seqR[i1 + d], seqT[j1 + d]
                                if x not in self.m and y not in self.rev:
                                    vs.append(((x, y), 1))
                        elif tag == 'replace' and (i2 - i1) == (j2 - j1) == 1:
                            x, y = seqR[i1], seqT[j1]
                            if x not in self.m and y not in self.rev and size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0):
                                vs.append(((x, y), 0.5))
                    c = self._calign[(r, t, which)] = (la, lb, vs)
                for k, n in c[2]:
                    votes[k] = votes.get(k, 0) + n
        byR = collections.defaultdict(list)
        byT = collections.defaultdict(list)
        for (x, y), n in votes.items():
            byR[x].append((n, y))
            byT[y].append((n, x))
        for x, lst in byR.items():
            lst.sort(reverse=True)
            n, y = lst[0]
            if n < 1 or (len(lst) > 1 and lst[1][0] >= n):
                continue
            lt = sorted(byT[y], reverse=True)
            if lt[0][1] != x or (len(lt) > 1 and lt[1][0] >= lt[0][0]):
                continue
            if not size_ok(R.ninsn[x], T.ninsn[y], 0.25, 4.0):
                continue
            # token sanity: if both have rare tokens they should share some
            if self.tokens_clash(x, y):
                continue
            self.accept(x, y, min(0.9, 0.4 + 0.15 * n), 'calls')

    # ---- global variables -----------------------------------------------------------------------
    def global_votes(self, replace=True, support=None):
        """R global addr -> Counter(T addr -> weight), from aligned access sequences of matched pairs.
        support, if a dict: (R addr, T addr) -> set of the R functions the votes came from"""
        R, T = self.R, self.T
        votes = collections.defaultdict(collections.Counter)

        def vote(a, b, w, r):
            votes[a][b] += w
            if support is not None:
                support.setdefault((a, b), set()).add(r)

        for r, t in self.m.items():
            al = self._galign.get((r, t))
            if al is None:              # the access lists never change: align each pair once
                al = self._galign[(r, t)] = []
                ga, gb = R.gacc[r], T.gacc[t]
                if ga and gb:
                    la = [(k, s, mn) for (_a, k, s, mn) in ga]
                    lb = [(k, s, mn) for (_a, k, s, mn) in gb]
                    sm = difflib.SequenceMatcher(None, la, lb, autojunk=False)
                    for tag, i1, i2, j1, j2 in sm.get_opcodes():
                        if tag == 'equal' or (tag == 'replace' and (i2 - i1) == (j2 - j1)):
                            for d in range(i2 - i1):
                                al.append((ga[i1 + d][0], gb[j1 + d][0], tag == 'equal'))
            w = self.conf.get(r, 0.5)
            for a, b, equal in al:
                if equal:
                    vote(a, b, w, r)
                elif replace:
                    vote(a, b, 0.3 * w, r)
        return votes

    def map_function(self, r_start):
        r = self.R.index_of(r_start)
        if r < 0 or r not in self.m:
            return None
        return self.T.start[self.m[r]], self.conf[r], self.how[r]
