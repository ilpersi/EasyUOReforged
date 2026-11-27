"""Item-property cache layout read from the client's code: B_PROPSTATE, B_PROPLIST
(uo\\uoclidata.pas, the scanprops rows; docs\\property-cache-analysis.md).

The tooltip cache C_PROPCACHE is a std::map<serial, entry*>. An entry keeps a state byte (4 = the server
announced a tooltip the client hasn't fetched) and a std::list of {cliloc, args} lines. Both offsets are
read from code shapes that are the same on every build checked (7.0.4.3 to 7.0.118.46 and the betas
7.0.117.31, 7.0.118.132, 7.0.119.0):

  state  in a function that names the cache, `cmp byte ptr [R + X], 4` followed by a `sete` or a
         conditional jump (the property check on the fixed-base builds, the "request everything
         announced" walk on the betas). X: $10 fixed-base, $C on the betas.
  list   fixed-base: in a function that names the cache (the tooltip name builder), the entry's list
         head and then its first node: `mov R, dword ptr [E + L]; mov R, dword ptr [R]`. L: 4.
         betas: the property check E_ITEMCHECKADDR returns the list's size, the dword after its head:
         `mov R, dword ptr [R + entry]; mov R, dword ptr [R + S]` just before the return. L = S - 4: 0.

`derive` takes any object with parallel `addr` / `mn` / `op` sequences and `func_of(va)` (disasm.Code, or
the small one the tests build) and the values known so far (C_PROPCACHE, E_ITEMCHECKADDR, B_CLILOCKEY),
and returns {field: (value, evidence)} for conv-style merging.
"""
import collections
import re

# capstone writes displacements below 10 in decimal ([esi + 4]) and the others in hex ([eax + 0xc])
CMP4 = re.compile(r'^byte ptr \[(e[a-z]{2}) \+ (0x[0-9a-f]+|[0-9])\], 4$')
LOAD = re.compile(r'^(e[a-z]{2}), dword ptr \[(e[a-z]{2})(?: \+ (0x[0-9a-f]+|[0-9]))?\]$')


def _index(code, va):
    if hasattr(code, 'index'):
        return code.index(va)
    try:
        return list(code.addr).index(va)
    except ValueError:
        return -1


def _body(code, f):
    """instruction indexes of the function starting at f (f need not be a known function start: the
    walk then ends at the next one)"""
    k = _index(code, f)
    if k < 0:
        return []
    owner = code.func_of(f)
    out = []
    n = len(code.addr)
    while k < n and len(out) < 4000:
        if out and code.func_of(code.addr[k]) != owner:
            break
        out.append(k)
        k += 1
    return out


def _funcs_naming(code, value):
    """starts of the functions with `value` as an operand (an immediate or an absolute address)"""
    rx = re.compile(r'(?<![0-9a-fx])0x%x(?![0-9a-f])' % value)
    out = []
    for k, op in enumerate(code.op):
        if '0x' in op and rx.search(op):
            f = code.func_of(code.addr[k])
            if f is not None and f not in out:
                out.append(f)
    return out


def _load(op):
    m = LOAD.match(op)
    if not m:
        return None
    return m.group(1), m.group(2), int(m.group(3), 0) if m.group(3) else 0


def _pick(counter):
    if not counter:
        return None
    ranked = counter.most_common()
    if len(ranked) > 1 and ranked[1][1] == ranked[0][1]:
        return None
    return ranked[0]


def state_offset(code, cache):
    """-> (offset, evidence) or None"""
    if not cache:
        return None
    c = collections.Counter()
    for f in _funcs_naming(code, cache):
        ks = _body(code, f)
        for i, k in enumerate(ks):
            if code.mn[k] != 'cmp':
                continue
            m = CMP4.match(code.op[k])
            if not m:
                continue
            x = int(m.group(2), 0)
            if not 4 <= x <= 0x40:
                continue
            nxt = [code.mn[j] for j in ks[i + 1:i + 4]]
            if any(t.startswith('set') or t in ('je', 'jne') for t in nxt):
                c[x] += 1
    r = _pick(c)
    if not r:
        return None
    x, cnt = r
    return x, 'a function naming the cache tests `byte [entry+$%X], 4` (%d place(s))' % (x, cnt)


def list_offset(code, cache, check, keyoff):
    """-> (offset, evidence) or None"""
    # the betas: the check returns the list's size (head + 4)
    if check and keyoff:
        ks = _body(code, check)
        for i in range(len(ks) - 1):
            a, b = _load(code.op[ks[i]]), _load(code.op[ks[i + 1]])
            if code.mn[ks[i]] != 'mov' or code.mn[ks[i + 1]] != 'mov' or not a or not b:
                continue
            if a[0] == a[1] == b[0] == b[1] and a[2] == keyoff + 4 and 4 <= b[2] <= 0x20:
                tail = [code.mn[j] for j in ks[i + 2:i + 6]]
                if 'ret' in tail:
                    return b[2] - 4, ('E_ITEMCHECKADDR returns the dword at entry+$%X, the line list\'s size: '
                                      'its head is the dword before' % b[2])
    # the fixed-base builds: the list head, then its first node
    if not cache:
        return None
    c = collections.Counter()
    for f in _funcs_naming(code, cache):
        ks = _body(code, f)
        for i in range(len(ks) - 1):
            if code.mn[ks[i]] != 'mov' or code.mn[ks[i + 1]] != 'mov':
                continue
            a, b = _load(code.op[ks[i]]), _load(code.op[ks[i + 1]])
            if not a or not b or a[1] in ('esp', 'ebp') or a[0] == a[1]:
                continue
            if b[0] == a[0] and b[1] == a[0] and b[2] == 0 and 0 <= a[2] <= 0x20:
                c[a[2]] += 1
    r = _pick(c)
    if not r:
        return None
    x, cnt = r
    return x, 'a function naming the cache loads the line list head at entry+$%X, then its first node (%d place(s))' % (x, cnt)


def derive(code, values):
    """values: the state so far (C_PROPCACHE, E_ITEMCHECKADDR, B_CLILOCKEY). -> {field: (value, evidence)}"""
    out = {}
    cache = values.get('C_PROPCACHE', 0)
    s = state_offset(code, cache)
    if s:
        out['B_PROPSTATE'] = s
    lst = list_offset(code, cache, values.get('E_ITEMCHECKADDR', 0), values.get('B_CLILOCKEY', 0))
    if lst:
        out['B_PROPLIST'] = lst
    return out
