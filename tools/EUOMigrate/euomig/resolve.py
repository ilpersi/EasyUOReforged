"""Apply the field descriptors of one reference build to a target build through a Matcher.

Every field gets a ranked candidate list, not just one value: static evidence alone cannot always
decide (two copies of the main loop, two arrays accessed the same way, a wrapper the new compiler
inlined), and the live verifier then picks among the candidates. Result.value is the best one,
Result.conf its calibrated confidence; Result.alts the runners-up as (value, conf, how).
"""
import bisect
import collections
import difflib
import math

from .disasm import shape

MIN_CONF = 0.5          # below this a value is a candidate for verification, not an answer


class Result:
    __slots__ = ('field', 'value', 'conf', 'how', 'alts')

    def __init__(self, field, value, conf, how, alts=()):
        self.field, self.value, self.conf, self.how, self.alts = field, value, conf, how, list(alts)

    @property
    def accepted(self):
        return self.value is not None and self.conf >= MIN_CONF

    def candidates(self):
        out = [(self.value, self.conf, self.how)] if self.value is not None else []
        return out + [a for a in self.alts if a[0] is not None]

    def __repr__(self):
        return '%s=%s (%.2f, %s)' % (self.field, ('%08X' % self.value) if self.value is not None else 'N/A',
                                    self.conf, self.how)


def vote_strength(w):
    return 1 - math.exp(-w)


def ranked(field, cands, note='', strength=None):
    """cands: [(value, score, how)] -> Result. Confidence = strength(top score) x its share of the
    top two scores; strength maps a raw score to 0..1 (identity for scores that already are)."""
    strength = strength or (lambda s: min(1.0, s))
    best = {}
    for v, s, h in cands:
        if v is not None and (v not in best or s > best[v][0]):
            best[v] = (s, h)
    if not best:
        return Result(field, None, 0.0, note or 'no candidates')
    order = sorted(best.items(), key=lambda kv: -kv[1][0])
    (v1, (s1, h1)) = order[0]
    s2 = order[1][1][0] if len(order) > 1 else 0.0
    conf = strength(s1) * (s1 / (s1 + s2)) if s1 > 0 else 0.0
    alts = [(v, strength(s) * (s / (s + s1)) if s > 0 else 0.0, h) for v, (s, h) in order[1:5]]
    return Result(field, v1, conf, h1 + note, alts)


# ---- sites ---------------------------------------------------------------------------------------
def site_in(code_t, t_start, desc):
    """best position for a site window inside the target function; returns (addr, similarity)"""
    k0, k1 = code_t.func_range(t_start)
    shapes = [shape(code_t.mn[j], code_t.op[j]) for j in range(k0, k1)]
    win, c = desc['win'], desc['center']
    n = len(win)
    pad = [''] * n + shapes + [''] * n
    want_mn = win[c].split(' ')[0]
    rel_ref = desc['pos'] / max(1, desc.get('flen', 1))
    best = (None, 0.0)
    for s in range(len(shapes)):
        if shapes[s].split(' ')[0] != want_mn:          # the site itself must be the same kind of insn
            continue
        seg = pad[n + s - c:n + s - c + n]
        r = difflib.SequenceMatcher(None, win, seg, autojunk=False).ratio()
        r -= 0.01 * abs(s / max(1, len(shapes)) - rel_ref)   # tie-break: same relative position
        if r > best[1]:
            best = (code_t.addr[k0 + s], r)
    return best


# ---- data ----------------------------------------------------------------------------------------
class DataContext:
    """shared state for resolving data fields: votes, which R global 'owns' each T global, confident
    global pairs and the target's accessed globals for layout predictions.
    (Relative ORDER of globals is not used as evidence: a new compiler/linker reorders the BSS.)"""

    def __init__(self, matcher, gv, support=None):
        self.gv = gv
        self.support = support or {}
        self.owner = {}
        for a, c in gv.items():
            for t, w in c.items():
                if w > self.owner.get(t, (None, 0.0))[1]:
                    self.owner[t] = (a, w)
        self.gmap = matcher.global_map(min_weight=1.5, margin=2.0)
        self.keys = sorted(self.gmap)
        self.accR = collections.defaultdict(set)
        for ga in matcher.R.gacc:
            for (a, k, s, mn) in ga:
                self.accR[a].add((k, s))
        self.accT = collections.defaultdict(set)
        for ga in matcher.T.gacc:
            for (a, k, s, mn) in ga:
                self.accT[a].add((k, s))
        self.gT = sorted(self.accT)

    def near_anchors(self, a, span=0x100):
        i = bisect.bisect_left(self.keys, a - span)
        out = []
        while i < len(self.keys) and self.keys[i] <= a + span:
            k = self.keys[i]
            if k != a:
                out.append((k, self.gmap[k]))
            i += 1
        return out

    def layout_candidates(self, a, span=0x100, snap=0x40):
        """T globals near where confident neighbours put a, with a compatible access kind"""
        out = []
        want = self.accR.get(a, set())
        for k, tk in self.near_anchors(a, span):
            p = tk + (a - k)
            lo = bisect.bisect_left(self.gT, p - snap)
            hi = bisect.bisect_right(self.gT, p + snap)
            for g in self.gT[lo:hi]:
                if self.accT[g] & want and self.owner.get(g, (None,))[0] in (None, a):
                    out.append((g, abs(g - p), k))
        return out


def resolve_data(f, a, ctx):
    cands = []
    notes = ''
    c = ctx.gv.get(a)
    if c:
        for t, w in c.most_common(6):
            o, ow = ctx.owner.get(t, (a, w))
            if o != a and ow >= 2 * w:
                notes = notes or ' (%08X is another global\'s)' % t
                continue
            n = len(ctx.support.get((a, t), ())) or 1
            cands.append((t, w, 'votes %.1f from %d function%s' % (w, n, 's' if n > 1 else '')))
    # layout: weak candidates from where confident neighbours put the field
    for g, dist, k in ctx.layout_candidates(a):
        cands.append((g, 0.15 * (1 - min(dist, 0x40) / 0x40), 'layout via %08X' % k))
    r = ranked(f, cands, notes, strength=vote_strength)
    # evidence from a single function pair can be one misaligned access sequence: cap it
    if r.value is not None and ctx.support:
        n = len(ctx.support.get((a, r.value), ()))
        r.conf *= {0: 1.0, 1: 0.6, 2: 0.85}.get(n, 1.0)
    return r


# ---- functions -----------------------------------------------------------------------------------
def func_plausibility(matcher, r, y):
    """matched function sanity: the same order of callers, structural agreement"""
    nr, ny = len(matcher.inR[r]), len(matcher.inT[y])
    p = 1.0
    if max(nr, ny) >= 4:
        ratio = (min(nr, ny) + 1) / (max(nr, ny) + 1)
        p *= 0.4 + 0.6 * min(1.0, ratio * 2)        # within a factor 2: no penalty
    ag, dis = matcher.agreement(r, y)
    if ag + dis >= 3:
        p *= 0.5 + 0.5 * min(1.0, ag / (ag + dis) / 0.7)
    return p


def func_candidates(matcher, r):
    """[(T index, score, how)]"""
    out = []
    if r in matcher.m:
        y = matcher.m[r]
        s = matcher.conf[r] * func_plausibility(matcher, r, y)
        out.append((y, s, matcher.how[r]))
        # a near copy of the matched function (two renderer variants of the main loop, ...): the
        # static match stands, the copy is kept as the runner-up for the live check
        for tw in matcher.twins(y):
            out.append((tw, 0.5 * s, 'twin of %08X' % matcher.T.start[y]))
    else:
        for comb, s, ag, jac, y in matcher.neighbour_candidates(r, top=6, free_only=False)[:3]:
            out.append((y, min(0.45, 0.15 * comb), 'neighbour candidate (agree %d, %.0f%%)' % (ag, 100 * jac)))
    return out


def resolve(descs, matcher, code_t, global_votes=None):
    T = matcher.T
    support = {}
    gv = global_votes if global_votes is not None else matcher.global_votes(support=support)
    ctx = DataContext(matcher, gv, support)
    imports_t = {v: k for k, v in code_t.pe.imports().items()}
    res = {}
    pending_derived = []
    for f, d in descs.items():
        k = d['kind']
        if k in ('value', 'absent', 'unknown'):
            continue
        if k == 'import':
            slot = imports_t.get(d['import'])
            res[f] = Result(f, slot, 1.0 if slot else 0.0, 'import %s' % d['import'])
        elif k == 'func':
            if 'derived' in d:
                pending_derived.append(f)
            cands = [(T.start[y], s, h) for y, s, h in func_candidates(matcher, d['func'])]
            res[f] = ranked(f, cands, '' if cands else 'function not matched')
        elif k == 'site':
            cands = []
            for y, s, h in func_candidates(matcher, d['func']):
                addr, sim = site_in(code_t, T.start[y], d)
                if addr:
                    cands.append((addr, s * sim, 'site in %08X (%.2f, %s)' % (T.start[y], sim, h)))
            res[f] = ranked(f, cands, '' if cands else 'site: function not matched')
        elif k == 'data':
            res[f] = resolve_data(f, d['addr'], ctx)
    # derived: the call target of each candidate of the source site. The field MEANS "what the
    # hooked call called", so this wins over a direct match of the reference's callee (a new
    # compiler may call a different helper there); the direct match only adds confidence.
    for f in pending_derived:
        g = descs[f]['derived']['of']
        src = res.get(g)
        if src is None:
            continue
        cands = []
        for v, s, h in src.candidates():
            kk = code_t.index(v)
            if kk >= 0 and code_t.mn[kk] == 'call' and code_t.op[kk].startswith('0x'):
                cands.append((int(code_t.op[kk], 16), s, 'call target of %s at %08X' % (g, v)))
        mine = res.get(f)
        if not cands:
            if mine is not None:
                mine.conf *= 0.5
                mine.how += ' (no direct call at %s)' % g
            continue
        if mine is not None and mine.value is not None:
            for i, (v, s, h) in enumerate(cands):
                if v == mine.value:
                    cands[i] = (v, 1 - (1 - s) * (1 - mine.conf), h + ' + direct match')
        res[f] = ranked(f, cands)
    return res
