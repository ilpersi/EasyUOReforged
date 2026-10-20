"""Function matching between a reference build R and a target build T (both FuncDB, hashed tokens),
then mapping of global variables through the matched functions.

Order of evidence, strongest first:
  1. anchors      a token found in exactly one function on each side (a unique string, API, class)
  2. vtables      the same RTTI class: slot i of R's vtable <-> slot i of T's vtable
  3. similarity   rare-token overlap (weighted), mutual best with a margin
  4. propagation  aligned call sequences / pointer references of already matched pairs
Nothing is matched on a single weak hint: every acceptance needs a mutual best and a margin, so an
unmatched function is preferred to a wrong one.
"""
import collections
import difflib
import math

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
        self.anchors()
        self.log('anchors', len(self.m))
        self.vtables()
        self.log('vtables', len(self.m))
        self.similarity()
        self.log('similarity', len(self.m))
        self._adjacency()
        for p in range(3):
            for i in range(rounds):
                before = len(self.m)
                self.propagate()
                self.neighbours()
                if self.opts['order']:
                    self.order()
                self.coreference()
                self.similarity(restrict=True)
                self.log('round', i, len(self.m))
                if len(self.m) == before:
                    break
            dropped = self.prune() if self.opts['prune'] else 0
            self.log('pruned', dropped)
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

    # ---- structural agreement of a (candidate) pair ----------------------------------------------
    def agreement(self, x, y):
        """(agree, disagree): matched neighbours of x whose image is / is not a neighbour of y, plus
        matched neighbours of y that are not images of x's neighbours"""
        nx = self.inR[x] | self.outR[x]
        ny = self.inT[y] | self.outT[y]
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

    def tokens_clash(self, x, y):
        rt = {t for t in self.R.tok[x] if self.dfR[t] <= 8}
        tt = {t for t in self.T.tok[y] if self.dfT[t] <= 8}
        return bool(rt and tt and not (rt & tt))

    def neighbour_candidates(self, x, top=6, free_only=True):
        """[(score*agreement, score, agree, agreement, y)] best first, for ref function x"""
        R, T = self.R, self.T
        sc = collections.Counter()
        for n in self.inR[x]:              # x is called by n  ->  y is called by m[n]
            if n in self.m:
                ys = [y for y in self.outT[self.m[n]] if not (free_only and y in self.rev)]
                for y in ys:
                    sc[y] += 1.0 / math.log2(1 + len(ys))
        for n in self.outR[x]:             # x calls n  ->  y calls m[n]
            if n in self.m:
                ys = [y for y in self.inT[self.m[n]] if not (free_only and y in self.rev)]
                for y in ys:
                    sc[y] += 1.0 / math.log2(1 + len(ys))
        scored = []
        for y, s in sc.most_common(top):
            if not size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0) or self.tokens_clash(x, y):
                continue
            ag, dis = self.agreement(x, y)
            jac = ag / max(1, ag + dis)
            scored.append((s * jac, s, ag, jac, y))
        scored.sort(reverse=True)
        return scored

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
        R, T = self.R, self.T
        cand = {}
        for x in range(self.nR):
            if x in self.m:
                continue
            scored = self.neighbour_candidates(x)
            if not scored:
                continue
            comb, s, ag, jac, y = scored[0]
            comb2 = scored[1][0] if len(scored) > 1 else 0.0
            if jac < 0.4 or comb < 0.8 or comb < 1.5 * comb2:
                continue
            if ag < 2 and not (s >= 1.0 and size_ok(R.ninsn[x], T.ninsn[y], 0.5, 2.0)):
                continue
            cand[x] = (y, comb, jac)
        bestT = {}
        for x, (y, s, jac) in cand.items():
            if s > bestT.get(y, (None, 0))[1]:
                bestT[y] = (x, s)
        for x, (y, s, jac) in cand.items():
            if bestT[y][0] == x:
                self.accept(x, y, min(0.85, 0.3 + 0.1 * s) * (0.5 + 0.5 * jac), 'neighbours')

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
        votes = collections.Counter()
        for r, t in list(self.m.items()):
            for seqR, seqT in ((R.calls[r], T.calls[t]), (R.prefs[r], T.prefs[t])):
                if not seqR or not seqT:
                    continue
                la = [('M%d' % self.m[x]) if x in self.m else ('U%d' % min(4, int(math.log2(R.ninsn[x] + 1)) // 2)) for x in seqR]
                lb = [('M%d' % y) if y in self.rev else ('U%d' % min(4, int(math.log2(T.ninsn[y] + 1)) // 2)) for y in seqT]
                sm = difflib.SequenceMatcher(None, la, lb, autojunk=False)
                for tag, i1, i2, j1, j2 in sm.get_opcodes():
                    if tag == 'equal':
                        for d in range(i2 - i1):
                            x, y = seqR[i1 + d], seqT[j1 + d]
                            if x not in self.m and y not in self.rev:
                                votes[(x, y)] += 1
                    elif tag == 'replace' and (i2 - i1) == (j2 - j1) == 1:
                        x, y = seqR[i1], seqT[j1]
                        if x not in self.m and y not in self.rev and size_ok(R.ninsn[x], T.ninsn[y], 0.33, 3.0):
                            votes[(x, y)] += 0.5
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
            rt = {t for t in R.tok[x] if self.dfR[t] <= 8}
            tt = {t for t in T.tok[y] if self.dfT[t] <= 8}
            if rt and tt and not (rt & tt):
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
            ga, gb = R.gacc[r], T.gacc[t]
            if not ga or not gb:
                continue
            la = [(k, s, mn) for (_a, k, s, mn) in ga]
            lb = [(k, s, mn) for (_a, k, s, mn) in gb]
            sm = difflib.SequenceMatcher(None, la, lb, autojunk=False)
            w = self.conf.get(r, 0.5)
            for tag, i1, i2, j1, j2 in sm.get_opcodes():
                if tag == 'equal':
                    for d in range(i2 - i1):
                        vote(ga[i1 + d][0], gb[j1 + d][0], w, r)
                elif replace and tag == 'replace' and (i2 - i1) == (j2 - j1):
                    for d in range(i2 - i1):
                        vote(ga[i1 + d][0], gb[j1 + d][0], 0.3 * w, r)
        return votes

    def map_function(self, r_start):
        r = self.R.index_of(r_start)
        if r < 0 or r not in self.m:
            return None
        return self.T.start[self.m[r]], self.conf[r], self.how[r]
