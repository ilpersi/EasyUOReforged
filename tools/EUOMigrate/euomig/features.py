"""Per-function fingerprints of one exe ("FuncDB"), in a form that can be stored in the knowledge
base and compared with another build without the original exe.

For every function (index i, ordered by address):
  start[i], ninsn[i]
  tok[i]     token -> count. Tokens survive recompilation: referenced strings (S:), imported APIs
             (I:), RTTI classes whose vtable is stored (V:), and unusual immediates (K:).
             In the KB they are stored as short hashes.
  calls[i]   callee function indices in call-site order (direct calls only)
  prefs[i]   function indices referenced as pointers (push offset fn, mov [x], fn, ...)
  gacc[i]    ordered global-data accesses: (addr, kind, size, mnemonic) with kind
             r = read, w = write, a = address taken, x = indexed table base
Plus vtables: RTTI class name -> list of slot function indices.
"""
import collections
import hashlib

from .disasm import HEX, BRACKET, mem_operands, immediates, first_operand_is_mem, WRITES

TOKEN_HASH_LEN = 12


def htok(t):
    """'S:some text' -> 'S:1a2b3c4d5e6f': the kind prefix stays readable (it sets the weight)"""
    return t[:2] + hashlib.blake2b(t[2:].encode('utf-8', 'surrogateescape'),
                                   digest_size=TOKEN_HASH_LEN // 2).hexdigest()


class FuncDB:
    """Fingerprints of one build. Built from an exe (from_code) or loaded from a KB file."""

    def __init__(self):
        self.meta = {}
        self.start = []
        self.ninsn = []
        self.tok = []          # list of dict token->count (hashed tokens in KB form)
        self.calls = []
        self.prefs = []
        self.gacc = []
        self.vtables = {}      # class -> [func index or -1]
        self.hashed = False
        self._index = None

    # ---- lookups -------------------------------------------------------------------------
    def index_of(self, start):
        if self._index is None:
            self._index = {a: i for i, a in enumerate(self.start)}
        return self._index.get(start, -1)

    def func_containing(self, va):
        import bisect
        i = bisect.bisect_right(self.start, va) - 1
        return i

    def token_freq(self):
        c = collections.Counter()
        for d in self.tok:
            for t in d:
                c[t] += 1
        return c

    def callers(self):
        res = [[] for _ in self.start]
        for i, cs in enumerate(self.calls):
            for j in cs:
                res[j].append(i)
        return res

    def hashed_copy_tokens(self):
        return [{htok(t): n for t, n in d.items()} for d in self.tok]

    # ---- building from an exe ----------------------------------------------------------------
    @classmethod
    def from_code(cls, code):
        pe = code.pe
        db = cls()
        db.meta = {
            'version': pe.file_version(), 'stamp': pe.stamp, 'base': pe.base,
            'relocatable': pe.relocatable, 'image_size': pe.image_size, 'sha256': pe.sha256(),
        }
        strings = pe.strings()
        imports = pe.imports()
        vtables = pe.rtti_vtables(strings)
        lo, hi = pe.base, pe.hi
        data_ranges = [(pe.base + s.va, pe.base + s.va + s.size) for s in pe.data_sections()]

        def is_data(v):
            for a, b in data_ranges:
                if a <= v < b:
                    return True
            return False

        db.start = list(code.funcs)
        fidx = {a: i for i, a in enumerate(db.start)}
        addr, mn, op = code.addr, code.mn, code.op
        nf = len(db.start)
        for i in range(nf):
            k0, k1 = code.func_range(db.start[i])
            tok = collections.Counter()
            calls, prefs, gacc = [], [], []
            for k in range(k0, k1):
                m = mn[k]
                o = op[k]
                if m == 'int3' or m == '.byte':
                    continue
                if '0x' not in o:
                    continue
                # direct calls
                if m == 'call' and o.startswith('0x'):
                    t = int(o, 16)
                    j = fidx.get(t)
                    if j is not None:
                        calls.append(j)
                    continue
                if m.startswith('j') and o.startswith('0x'):
                    continue                                   # branch targets are not data
                mems = mem_operands(o)
                for (sz, inner, absval, has_base) in mems:
                    if absval is None or has_base:
                        continue
                    if absval in imports:
                        tok['I:' + imports[absval]] += 1
                        continue
                    if lo <= absval < hi and is_data(absval):
                        if '*' in inner:
                            kind = 'x'
                        elif first_operand_is_mem(o) and m in WRITES:
                            kind = 'w'
                        elif m == 'lea':
                            kind = 'a'
                        else:
                            kind = 'r'
                        gacc.append((absval, kind, sz, m))
                for v in immediates(o):
                    if lo <= v < hi:
                        if v in strings:
                            tok['S:' + strings[v]] += 1
                        elif v in vtables:
                            tok['V:' + vtables[v]] += 1
                        elif v in fidx:
                            prefs.append(fidx[v])
                        elif is_data(v):
                            gacc.append((v, 'a', 0, m))
                    elif v >= 0x100 and v not in (0xFFFFFFFF, 0xFFFFFFFE, 0xFFFF, 0xFF00, 0xFF0000, 0xFF000000):
                        tok['K:%x' % v] += 1
                # string / vtable referenced through memory form too (e.g. push dword ptr [str])
            db.ninsn.append(k1 - k0)
            db.tok.append(dict(tok))
            db.calls.append(calls)
            db.prefs.append(prefs)
            db.gacc.append(gacc)
        # vtables: class -> slot functions
        bycls = collections.defaultdict(list)
        for vt, name in vtables.items():
            slots = []
            a = vt
            while True:
                v = pe.u32(a)
                if not pe.is_code(v):
                    break
                slots.append(fidx.get(v, -1))
                a += 4
                if len(slots) > 400:
                    break
            bycls[name].append(slots)
        # several vtables per class (multiple inheritance): keep the longest one first
        db.vtables = {c: sorted(v, key=len, reverse=True) for c, v in bycls.items()}
        return db

    # ---- (de)serialisation ------------------------------------------------------------------
    def to_json(self):
        toks = self.tok if self.hashed else self.hashed_copy_tokens()
        return {
            'meta': self.meta,
            'start': self.start, 'ninsn': self.ninsn,
            'tok': toks, 'calls': self.calls, 'prefs': self.prefs,
            'gacc': [[list(g) for g in ga] for ga in self.gacc],
            'vtables': self.vtables,
        }

    @classmethod
    def from_json(cls, d):
        db = cls()
        db.meta = d['meta']
        db.start, db.ninsn = d['start'], d['ninsn']
        db.tok, db.calls, db.prefs = d['tok'], d['calls'], d['prefs']
        db.gacc = [[tuple(g) for g in ga] for ga in d['gacc']]
        db.vtables = d['vtables']
        db.hashed = True
        return db

    def hashed_view(self):
        """same DB with hashed tokens (to compare with a KB-loaded DB)"""
        if self.hashed:
            return self
        h = FuncDB()
        h.meta, h.start, h.ninsn = self.meta, self.start, self.ninsn
        h.tok = self.hashed_copy_tokens()
        h.calls, h.prefs, h.gacc = self.calls, self.prefs, self.gacc
        h.vtables = self.vtables
        h.hashed = True
        return h
