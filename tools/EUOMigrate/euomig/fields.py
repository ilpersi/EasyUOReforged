"""Field descriptors: HOW each C_*/E_* field of a reference build can be recognised again.

kinds
  func    the value is a function start                       {func}
  site    the value is an instruction inside a function       {func, pos, win, center, call}
  import  the value is an import-table slot                    {import}
  data    the value is a global in a data section              {addr}
  derived the value follows from another field                 {rule, of}
            rule 'call_target': the rel32 target of the call at field <of>
  absent  the field is 0 for this build
B_*/F_* fields are recorded as plain values (layouts / flags) for reference only.
"""
from .disasm import shape

WIN = 12        # instructions kept on each side of a site

# B_* offsets that are distances between two GLOBALS (how uovariables.pas uses them): the second
# global is located like any other ("@B_X", a pseudo field), and B_X = sign * (it - base).
# field: (base field, sign, the getter's default when the table value is 0)
RELATIVE = {
    'B_SKILLDIST': ('C_SKILLSPOS', 1, None),
    'B_NEXTCX': ('C_NEXTCPOS', 1, 4),
    'B_TITHE': ('C_NEXTCPOS', 1, None),
    'B_CLITOP': ('C_CLILEFT', 1, 4),
    'B_TARGPROC': ('C_TARGETCURS', 1, None),
    'B_LANG': ('C_LHANDID', -1, None),
    'B_LTARGID': ('C_LHANDID', 1, 0x18),
    'B_LTARGTILE': ('C_LHANDID', 1, None),
    'B_LTARGX': ('C_LHANDID', 1, None),
    'B_LSPELL': ('C_LHANDID', 1, 0x10),
    'B_LSKILL': ('C_LHANDID', 1, 0x14),
    'B_RHAND': ('C_LHANDID', 1, 4),
}


# Fields that are only a BASE: the runtime reads the members at fixed distances from it and never
# the global at the base itself, so the field is located through its member at that distance (the
# member minus the distance), whatever global a build happens to keep at the base. Descriptors keep
# the field's own value; resolve and siggen apply the distance.
# C_LHANDID: uovariables.pas reads the last used object at C_LHANDID+$0C on every build. The modern
# build keeps a macro wait counter at the base on 6AC94360 and that counter's limit there on 6AD6CEB3.
ANCHOR = {'C_LHANDID': 0x0C}


def relative_value(table, f):
    """the effective offset (the getter's default when the table holds 0)"""
    base, sign, default = RELATIVE[f]
    v = table.get(f, 0)
    if v == 0 and default is not None:
        v = default
    return v


def build(code, db, table, fields):
    pe = code.pe
    imports = pe.imports()
    out = {}
    for f in fields:
        v = table.get(f, 0)
        if f[:2] in ('B_', 'F_'):
            out[f] = {'kind': 'value', 'value': v}
            continue
        if not v:
            out[f] = {'kind': 'absent'}
            continue
        if v in imports:
            out[f] = {'kind': 'import', 'import': imports[v], 'value': v}
            continue
        if pe.is_code(v):
            fs = code.func_of(v)
            i = db.index_of(fs) if fs is not None else -1
            if fs == v:
                out[f] = {'kind': 'func', 'func': i, 'value': v}
                continue
            k = code.index(v)
            if i < 0 or k < 0:
                out[f] = {'kind': 'unknown', 'value': v}
                continue
            k0, k1 = code.func_range(fs)
            lo, hi = max(k0, k - WIN), min(k1, k + WIN + 1)
            win = [shape(code.mn[j], code.op[j]) for j in range(lo, hi)]
            d = {'kind': 'site', 'func': i, 'pos': k - k0, 'flen': k1 - k0, 'win': win, 'center': k - lo, 'value': v}
            if code.mn[k] == 'call' and code.op[k].startswith('0x'):
                tgt = int(code.op[k], 16)
                ti = db.index_of(tgt)
                d['call'] = ti
                d['call_ord'] = sum(1 for j in range(k0, k) if code.mn[j] == 'call')
            out[f] = d
            continue
        if pe.in_image(v):
            out[f] = {'kind': 'data', 'addr': v, 'value': v}
        else:
            out[f] = {'kind': 'value', 'value': v}
    # pseudo fields for the global-relative offsets
    for f, (base, sign, default) in RELATIVE.items():
        b = table.get(base, 0)
        off = relative_value(table, f)
        if not b or not off:
            continue
        a = (b + sign * off) & 0xFFFFFFFF
        if a == b or not pe.in_image(a) or pe.is_code(a):
            continue
        out['@' + f] = {'kind': 'data', 'addr': a, 'value': a, 'rel': [f, base, sign]}
    # derived: a code field equal to the call target of a site field
    for f, d in out.items():
        if d['kind'] != 'func':
            continue
        for g, e in out.items():
            if e['kind'] == 'site' and e.get('call') is not None and e['call'] == d['func']:
                d['derived'] = {'rule': 'call_target', 'of': g}
    return out
