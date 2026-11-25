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
# global is located like any other ("@B_X", a pseudo field), and B_X = sign * (it - bias - base).
# field: (base field, sign, the getter's default when the table value is 0[, bias])
#   default  a number, None (no default), or (field, add): that field's effective value + add
#            (TCstDB.BLTARGKIND: 0 means B_LTARGTILE + 4)
#   bias     where the code really accesses it, relative to base + sign * offset: the arm/disarm macro
#            reads the hands as [hand*4 + table] with hand 1 or 2, so the global the code names is the
#            slot BEFORE the left hand (bias -4), not the left hand itself
RELATIVE = {
    'B_SKILLDIST': ('C_SKILLSPOS', 1, None),
    'B_NEXTCX': ('C_NEXTCPOS', 1, 4),
    'B_TITHE': ('C_NEXTCPOS', 1, None),
    'B_CLITOP': ('C_CLILEFT', 1, 4),
    'B_CLIYRES': ('C_CLIXRES', 1, 4),
    'B_MACROIDX': ('E_MACROTAB', 1, 4),
    'B_TARGPROC': ('C_TARGETCURS', 1, None),
    'B_LANG': ('C_LHANDID', -1, None),
    'B_LTARGID': ('C_LHANDID', 1, 0x18),
    'B_LTARGTILE': ('C_LHANDID', 1, None),
    'B_LTARGX': ('C_LHANDID', 1, None),
    'B_LSPELL': ('C_LHANDID', 1, 0x10),
    'B_LSKILL': ('C_LHANDID', 1, 0x14),
    'B_LTARGKIND': ('C_LHANDID', 1, ('B_LTARGTILE', 4)),
    'B_LHAND': ('C_LHANDID', 1, 0, -4),
    'B_LLIFTEDTYPE': ('C_LLIFTEDID', -1, None),     # uovariables.pas reads C_LLIFTEDID - B_LLIFTEDTYPE
    'B_LLIFTEDKIND': ('C_LLIFTEDID', 1, None),
}

# B_* offsets that follow from another one: field -> (source, add). The hands are indexed by hand*4, so
# the right hand is always the slot after the left one (TCstDB.BRHAND: 0 means B_LHAND + 4).
FOLLOWS = {
    'B_RHAND': ('B_LHAND', 4),
}
DEFAULTS = {'B_RHAND': ('B_LHAND', 4)}     # getter defaults of the FOLLOWS fields


# Fields that are only a BASE: the runtime reads the members at fixed distances from it and never
# the global at the base itself, so the field is located through its member at that distance (the
# member minus the distance), whatever global a build happens to keep at the base. Descriptors keep
# the field's own value; resolve and siggen apply the distance.
# C_LHANDID: uovariables.pas reads the last used object at C_LHANDID+$0C on every build. The modern
# build keeps a macro wait counter at the base on 6AC94360 and that counter's limit there on 6AD6CEB3.
ANCHOR = {'C_LHANDID': 0x0C}


def spec(f):
    """(base, sign, default, bias) of a RELATIVE field"""
    r = RELATIVE[f]
    return r[0], r[1], r[2], (r[3] if len(r) > 3 else 0)


def getter_default(table, f):
    """what the TCstDB getter uses when the table holds 0 for f (None: no default)"""
    d = RELATIVE[f][2] if f in RELATIVE else DEFAULTS.get(f)
    if isinstance(d, tuple):
        other, add = d
        return (relative_value(table, other) + add) & 0xFFFFFFFF
    return d


def relative_value(table, f):
    """the effective offset (the getter's default when the table holds 0)"""
    v = table.get(f, 0)
    if v == 0:
        d = getter_default(table, f) if (f in RELATIVE or f in DEFAULTS) else None
        if d is not None:
            v = d
    return v


def pseudo_fields(table, in_image, is_code=lambda a: False):
    """'@B_X' -> descriptor of the global each RELATIVE offset points at in this build"""
    out = {}
    for f in RELATIVE:
        base, sign, default, bias = spec(f)
        b = table.get(base, 0)
        if not b:
            continue
        a = (b + sign * relative_value(table, f) + bias) & 0xFFFFFFFF
        if a == b or not in_image(a) or is_code(a):
            continue
        out['@' + f] = {'kind': 'data', 'addr': a, 'value': a, 'rel': [f, base, sign, bias]}
    return out


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
    out.update(pseudo_fields(table, pe.in_image, pe.is_code))
    # derived: a code field equal to the call target of a site field
    for f, d in out.items():
        if d['kind'] != 'func':
            continue
        for g, e in out.items():
            if e['kind'] == 'site' and e.get('call') is not None and e['call'] == d['func']:
                d['derived'] = {'rule': 'call_target', 'of': g}
    return out
