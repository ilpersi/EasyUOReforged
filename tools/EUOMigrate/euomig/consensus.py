"""Migrate a target build from every reference in the knowledge base and combine the answers.

Each reference is matched on its own (Matcher + resolve). How CLOSE a reference is to the target is
measured by how many of its non-trivial functions found a partner; the closest one is the primary:
  - the "form" of a field group follows it. A field the primary does not use (0 there, e.g.
    E_PATHFINDMID on a fixed-base build) stays 0 even if a farther reference has it, because the
    Pascal side switches behaviour on whether such a field is set;
For C_*/E_* fields the candidates of all references are pooled: a value that several references
agree on gains confidence, one that only a far reference proposes stays weak.
B_* layouts and F_* flags are not addresses and cannot be matched: they are inherited from the
state uoclidata.pas already gives the target (the floor milestone of a fixed-base build, the modern
layout of a relocatable one) until conv / probe / verify say otherwise.
"""
from .match import Matcher
from .resolve import Result, resolve, MIN_CONF
from .sigs import scan


def closeness(M):
    nR = sum(1 for n in M.R.ninsn if n > 4)
    nT = sum(1 for n in M.T.ninsn if n > 4)
    return len(M.m) / max(1, min(nR, nT))


SIG_WEIGHT = 0.85      # a unique hit of a reference's validated signature


class Run:
    def __init__(self, ref, matcher, results, sighits):
        self.ref = ref
        self.M = matcher
        self.res = results
        self.sighits = sighits          # field -> value: the reference's signatures on the target
        self.closeness = closeness(matcher)


def sig_hits(pe, sigs):
    """EUOUpdtr semantics: per field, the first line that matches exactly once"""
    out = {}
    for f, s in sigs:
        if f in out:
            continue
        h = scan(pe, s, maxhits=2)
        if len(h) == 1:
            out[f] = h[0]
    return out


class Migration:
    """the combined outcome: results (field -> Result), runs (closest first), primary run"""

    def __init__(self, target, runs, fields, base_state, base_label, newer_state=None):
        self.target = target
        self.runs = runs
        self.primary = runs[0]
        self.fields = fields
        self.base_state = base_state or {}
        self.base_label = base_label
        self.newer_state = newer_state
        self.results = {}
        self._combine()

    def _combine(self):
        P = self.primary
        top = P.closeness or 1e-9
        pseudo = [k for k in P.ref.fields if k.startswith('@')]
        for f in list(self.fields) + pseudo:
            d = P.ref.fields.get(f, {'kind': 'absent'})
            if f[:2] in ('B_', 'F_'):
                self.results[f] = Result(f, self.base_state.get(f, 0), 0.0, 'inherited from %s' % self.base_label)
                continue
            if d['kind'] == 'absent':
                others = [r.ref.id for r in self.runs[1:] if r.ref.fields.get(f, {}).get('kind') not in (None, 'absent')]
                note = 'not used by the closest reference %s' % P.ref.id
                if others:
                    note += ' (set in %s)' % ', '.join(others)
                if self.base_state.get(f):
                    note += '; %s has $%08X, an address of another build' % (self.base_label, self.base_state[f])
                self.results[f] = Result(f, 0, 1.0, note)
                continue
            if d['kind'] in ('value', 'unknown'):
                self.results[f] = Result(f, P.ref.table.get(f, 0), 0.0, 'copied from %s (not an address)' % P.ref.id)
                continue
            pool = {}
            for run in self.runs:
                w = run.closeness / top
                r = run.res.get(f)
                if r is not None:
                    for v, c, h in r.candidates():
                        e = pool.setdefault(v, [1.0, []])
                        e[0] *= (1 - min(1.0, c * w))
                        e[1].append('%s: %s %.2f' % (run.ref.id, h, c))
                v = run.sighits.get(f)
                if v:
                    e = pool.setdefault(v, [1.0, []])
                    e[0] *= (1 - SIG_WEIGHT * w)
                    e[1].append('%s: signature' % run.ref.id)
            if not pool:
                r = P.res.get(f)
                self.results[f] = Result(f, None, 0.0, r.how if r else 'no candidates')
                continue
            # A fixed-base build sits between two known milestones. A candidate equal to what the
            # older one already has means the address did not move: independent corroboration
            # (stronger when the newer milestone has the same value too).
            bv = self.base_state.get(f, 0)
            if bv and not self.target.relocatable and bv in pool:
                same_newer = self.newer_state is not None and self.newer_state.get(f) == bv
                e = pool[bv]
                e[0] *= 0.3 if same_newer else 0.5
                e[1].append('unchanged from %s%s' % (self.base_label, ' and the next newer milestone' if same_newer else ''))
            scored = sorted(((1 - e[0], v, e[1]) for v, e in pool.items()), key=lambda t: -t[0])
            s1, v1, h1 = scored[0]
            s2 = scored[1][0] if len(scored) > 1 else 0.0
            conf = s1 * (s1 / (s1 + s2)) if s1 > 0 else 0.0
            alts = [(v, s * (s / (s + s1)) if s > 0 else 0.0, '; '.join(h)) for s, v, h in scored[1:5]]
            self.results[f] = Result(f, v1, conf, '; '.join(h1), alts)
        # a field that IS "the target of the hooked call" is only as good as the hook site: the
        # same function found elsewhere (E_OLDDIR = __allmul) is no use if the hook moved
        for f, d in P.ref.fields.items():
            src = d.get('derived', {}).get('of')
            r, s = self.results.get(f), self.results.get(src)
            if r is None or s is None or r.value is None:
                continue
            if s.value is None or s.conf < r.conf:
                r.conf = min(r.conf, s.conf if s.value is not None else 0.0)
                r.how += ' (capped: follows %s)' % src

    def accepted(self, f):
        r = self.results.get(f)
        return r is not None and r.value is not None and r.conf >= MIN_CONF

    def relative_layout(self):
        """B_* offsets between two globals, from the located pseudo field and its base field:
        {B_X: (value, evidence)} for pairs where both ends are accepted"""
        out = {}
        for k, d in self.primary.ref.fields.items():
            if not k.startswith('@'):
                continue
            f, base, sign = d['rel']
            r, rb = self.results.get(k), self.results.get(base)
            if not (r and rb and r.value and rb.value) or min(r.conf, rb.conf) < MIN_CONF:
                continue
            v = (sign * (r.value - rb.value)) & 0xFFFFFFFF
            out[f] = (v, '%s = %s %s $%X: the global at %08X (%s) is located like %s %08X' % (
                f, base, '+' if sign > 0 else '-', v if sign > 0 else (-v) & 0xFFFFFFFF, r.value,
                r.how[:60], base, rb.value))
        return out


def migrate(target, refs, fields, base_state=None, base_label='', newer_state=None, log=None, opts=None):
    log = log or (lambda *a: None)
    th = target.db.hashed_view()
    runs = []
    for ref in refs:
        if ref.build.get('sha256') == target.pe.sha256():
            log('skipping %s: it is the target itself' % ref.id)
            continue
        log('matching against %s' % ref.label())
        M = Matcher(ref.funcdb, th, opts=opts).run()
        res = resolve(ref.fields, M, target.code)
        run = Run(ref, M, res, sig_hits(target.pe, ref.sigs))
        log('  %d of %d reference functions matched (closeness %.2f), %d of its signatures hit' % (
            len(M.m), len(ref.funcdb.start), run.closeness, len(run.sighits)))
        runs.append(run)
    if not runs:
        raise SystemExit('no usable reference in the knowledge base')
    runs.sort(key=lambda r: -r.closeness)
    return Migration(target, runs, fields, base_state, base_label, newer_state)
