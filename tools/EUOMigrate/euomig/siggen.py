"""Generate EUOUpdtr-style signatures for resolved fields, so that the NEXT build of the same
compiler is handled by the runtime scan (TCstDB's ScannerTable / EUO Updtr) with no tool at all.

Masking (what a rebuild changes): in-image absolute operands (globals, IAT slots, code pointers),
rel32 branch/call targets, ebp/esp displacements (frame layout) -- the latter are kept as a second
try when a window is not unique without them (two near-identical functions). The joker byte is
chosen per pattern so it never equals a fixed byte. A pattern is accepted only if it matches
exactly once in the code sections and resolves to the expected value.

Strategies per field kind (each yields at most one line per function, two lines per field):
  data / import   C  : a unique window around an instruction whose absolute operand is the
                       global (or global+d: then adjust = -d)
  func            X  : a unique window starting at the function's first instruction
                  CB : a unique window around a direct call to the function
  site            X  : a unique window containing the instruction
"""
import re

from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_GRP_JUMP, CS_GRP_CALL
from capstone.x86 import X86_OP_MEM, X86_OP_IMM, X86_REG_EBP, X86_REG_ESP

from .sigs import Sig

JOKERS = (0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x01, 0x02)
MODE_PAS = {'X': 1, 'CB': 2, 'C': 3}


class SigGen:
    def __init__(self, code):
        self.code = code
        self.pe = code.pe
        self.md = Cs(CS_ARCH_X86, CS_MODE_32)
        self.md.detail = True
        self.secs = [(self.pe.base + s.va, self.pe.section_bytes(s)) for s in self.pe.code_sections()]
        self._mask = {}
        self._xref = None

    # ---- masking ---------------------------------------------------------------------------
    def mask(self, k, keep_frame=False):
        key = (k, keep_frame)
        if key in self._mask:
            return self._mask[key]
        raw = self.code.raw(k)
        wild = [False] * len(raw)
        d = next(self.md.disasm(raw, self.code.addr[k]), None)
        info = {'abs': {}}           # value -> byte offset of a 4-byte absolute field
        if d is not None and d.size == len(raw):
            is_branch = (CS_GRP_JUMP in d.groups or CS_GRP_CALL in d.groups or d.mnemonic.startswith('j')
                         or d.mnemonic.startswith('loop'))
            for o in d.operands:
                if o.type == X86_OP_IMM and is_branch and d.imm_size:
                    for i in range(d.imm_offset, d.imm_offset + d.imm_size):
                        wild[i] = True
                    info['rel'] = (d.imm_offset, o.imm & 0xFFFFFFFF)
                elif o.type == X86_OP_MEM and d.disp_size:
                    disp = o.mem.disp & 0xFFFFFFFF
                    if o.mem.base in (X86_REG_EBP, X86_REG_ESP):
                        if not keep_frame:
                            for i in range(d.disp_offset, d.disp_offset + d.disp_size):
                                wild[i] = True
                    elif d.disp_size == 4 and self.pe.in_image(disp):
                        for i in range(d.disp_offset, d.disp_offset + 4):
                            wild[i] = True
                        info['abs'][disp] = d.disp_offset
                elif o.type == X86_OP_IMM and d.imm_size == 4 and self.pe.in_image(o.imm & 0xFFFFFFFF):
                    for i in range(d.imm_offset, d.imm_offset + 4):
                        wild[i] = True
                    info['abs'][o.imm & 0xFFFFFFFF] = d.imm_offset
        r = (raw, wild, info)
        self._mask[key] = r
        return r

    def window(self, k0, k1, keep_frame=False):
        raw, wild = b'', []
        for k in range(k0, k1):
            r, w, _ = self.mask(k, keep_frame)
            raw += r
            wild += w
        return raw, wild

    def count(self, raw, wild, limit=2):
        rx = re.compile(b''.join(b'.' if w else re.escape(bytes([b])) for b, w in zip(raw, wild)), re.S)
        out = []
        for base, data in self.secs:
            pos = 0
            while True:
                m = rx.search(data, pos)
                if not m:
                    break
                out.append(base + m.start())
                if len(out) >= limit:
                    return out
                pos = m.start() + 1
        return out

    def unique_window(self, k, before_max=8, after_max=10, min_fixed=16, start_at_k=False):
        """smallest window [k0, k1) containing instruction k, unique in the code. -> (k0, k1, keep_frame)"""
        c = self.code
        f = c.func_of(c.addr[k])
        k_lo = c.index(f) if f is not None else 0
        for keep_frame in (False, True):
            for tot in range(0, before_max + after_max + 1):
                for b in ([0] if start_at_k else range(0, min(tot, before_max) + 1)):
                    a = tot - b
                    if a > after_max or k - b < k_lo:
                        continue
                    k0, k1 = k - b, k + a + 1
                    if any(c.mn[j] in ('int3', '.byte') for j in range(k0, k1)):
                        continue
                    raw, wild = self.window(k0, k1, keep_frame)
                    if sum(1 for w in wild if not w) < min_fixed:
                        continue
                    m = self.count(raw, wild)
                    if len(m) == 1 and m[0] == c.addr[k0]:
                        return k0, k1, keep_frame
        return None

    def make(self, name, k0, k1, keep_frame, offset, mode, adjust):
        raw, wild = self.window(k0, k1, keep_frame)
        fixed = set(b for b, w in zip(raw, wild) if not w)
        joker = next((j for j in JOKERS if j not in fixed), None)
        if joker is None:
            return None
        pat = bytes(joker if w else b for b, w in zip(raw, wild))
        return Sig(pat, joker, offset, mode, adjust, name)

    # ---- references -------------------------------------------------------------------------
    def xrefs(self):
        """value -> [instruction index] for every absolute in-image operand and every direct call"""
        if self._xref is None:
            c = self.code
            hexre = re.compile(r'0x([0-9a-f]{6,8})\b')
            x = {}
            for k in range(len(c)):
                o = c.op[k]
                if '0x' not in o:
                    continue
                for h in hexre.findall(o):
                    v = int(h, 16)
                    if self.pe.in_image(v):
                        x.setdefault(v, []).append(k)
            self._xref = x
        return self._xref

    def refs_near(self, value, span=0x20):
        """[(k, delta)]: instructions referencing value+delta, nearest delta first"""
        x = self.xrefs()
        out = []
        for d in sorted(range(-span, span + 1), key=abs):
            for k in x.get((value + d) & 0xFFFFFFFF, ()):
                out.append((k, d))
        return out

    # ---- per field --------------------------------------------------------------------------
    def for_field(self, field, value, kind, nmax=2, budget=60):
        name = field[2:]
        c = self.code
        out = []
        used_funcs = set()

        def add(sig, k):
            if sig is None:
                return
            out.append(sig)
            used_funcs.add(c.func_of(c.addr[k]))

        tries = 0
        if kind in ('data', 'import'):
            for k, d in self.refs_near(value, 0 if kind == 'import' else 0x20):
                if len(out) >= nmax or tries >= budget:
                    break
                if c.func_of(c.addr[k]) in used_funcs:
                    continue
                _r, _w, info = self.mask(k)
                field_off = info['abs'].get((value + d) & 0xFFFFFFFF)
                if field_off is None:
                    continue
                tries += 1
                w = self.unique_window(k)
                if not w:
                    continue
                k0, k1, kf = w
                off = sum(c.size[j] for j in range(k0, k)) + field_off
                add(self.make(name, k0, k1, kf, off, 'C', -d), k)
        elif kind == 'func':
            k = c.index(value)
            if k >= 0:
                w = self.unique_window(k, before_max=0, after_max=14, start_at_k=True)
                if w:
                    add(self.make(name, w[0], w[1], w[2], 0, 'X', 0), k)
            for kk, d in self.refs_near(value, 0):
                if len(out) >= nmax or tries >= budget:
                    break
                if c.mn[kk] not in ('call', 'jmp') or not c.op[kk].startswith('0x'):
                    continue
                if c.func_of(c.addr[kk]) in used_funcs:
                    continue
                tries += 1
                w = self.unique_window(kk)
                if not w:
                    continue
                _r, _w, info = self.mask(kk)
                if 'rel' not in info:
                    continue
                k0, k1, kf = w
                off = sum(c.size[j] for j in range(k0, kk)) + info['rel'][0]
                add(self.make(name, k0, k1, kf, off, 'CB', 0), kk)
        elif kind == 'site':
            k = c.index(value)
            if k >= 0:
                w = self.unique_window(k)
                if w:
                    k0, k1, kf = w
                    add(self.make(name, k0, k1, kf, sum(c.size[j] for j in range(k0, k)), 'X', 0), k)
        return out[:nmax]


def generate(code, values, kinds, derived=None, log=None):
    """values: field -> address (link-time), kinds: field -> descriptor kind, derived: field ->
    the site field whose call it is the target of (E_OLDDIR -> E_REDIR).
    -> [(field, Sig)], each validated: exactly one match, resolving to the value"""
    from .sigs import scan
    g = SigGen(code)
    derived = derived or {}
    out = []
    by_field = {}
    order = [f for f in values if f not in derived] + [f for f in values if f in derived]
    for f in order:
        v = values[f]
        if not v or f[:2] not in ('C_', 'E_'):
            continue
        kind = kinds.get(f) or ('func' if code.pe.is_code(v) and code.func_of(v) == v else
                                'site' if code.pe.is_code(v) else 'data')
        if kind == 'import' or v in code.pe.imports():
            kind = 'import'
        sigs = []
        # "what the hooked call calls": the hook's own pattern, following the rel32 (CB), keeps
        # the two fields consistent on the next build -- the callee may change, the hook site not
        for s in by_field.get(derived.get(f), ()):
            if s.mode == 'X':
                sigs.append(Sig(s.pattern, s.joker, s.offset + 1, 'CB', 0, f[2:]))
        sigs += g.for_field(f, v, kind)
        good = [s for s in sigs if scan(code.pe, s) == [v]][:2]
        by_field[f] = good
        if log:
            log('  %-16s %d signature%s' % (f, len(good), '' if len(good) == 1 else 's'))
        out += [(f, s) for s in good]
    return out


def strings_file(pairs, header):
    lines = ['// ' + h for h in header] + ['']
    for f, s in pairs:
        lines.append(s.to_line())
    return '\n'.join(lines) + '\n'


def pascal_table(pairs, name):
    rows = []
    for f, s in pairs:
        rows.append("    (Joker: $%02X; Unused: (0,0,0); AddOffset1: %d; Mode: %d; AddOffset2: %d; Expr: %s;\n"
                    "     Pattern: '%s')," % (s.joker, s.offset, MODE_PAS[s.mode], s.adjust, f, s.pattern.hex().upper()))
    rows.append("    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 0; AddOffset2: 0; Expr: LISTEND; Pattern: nil)")
    return '  %s : array[0..%d] of TScannerEntry = (\n%s\n  );\n' % (name, len(pairs), '\n'.join(rows))
