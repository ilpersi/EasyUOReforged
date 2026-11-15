"""Gump object fields read from the client's code: B_GUMPART, B_GUMPMIN, B_GUMPSERIAL, B_GUMPTYPE
(uo\\uoclidata.pas, the ScanGumps rows; docs\\gump-analysis.md sections 3, 4, 10 and 11).

Each one is an offset inside a gump object, found from a code shape that is the same on every build
checked (7.0.29.97, 7.0.61.13, 7.0.117.x, 7.0.118.46 and the relocatable beta):

  serial, type ID  the generic gump's reply function, which builds the $B1 packet a button click
                   sends. It starts by copying `this` (ecx) into a register R and testing the serial
                   at [R+X]; after the $B1 opcode is stored (`push 0B1h` + call on the fixed-base
                   builds, `mov byte [esp+..], 0B1h` on the beta) it loads the type ID at [R+X+4].
                   This is the strongest evidence there is: the client sends those two values to the
                   server straight from the gump.
  art ID           the constructors that store a constant gump graphic: `mov dword [R+X], 4ECh`
                   (BuffIcons gump), cross-checked with `2A6Ch` (status gump) where it is a constant.
  minimized flag   the bring-to-front code: `cmp [R+X], ..` followed by loads of the size from
                   [R+B_CONTSIZEX] or from the minimized size 8 bytes further on.

`derive` takes any object with parallel `addr` / `mn` / `op` sequences and `func_of(va)` (disasm.Code,
or the small one the tests build) and returns {field: (value, evidence)} for conv-style merging.
"""
import collections
import re

MEM = re.compile(r'(byte|word|dword) ptr \[(e[a-z]{2}) \+ (0x[0-9a-f]+)\]')
B1_STORE = re.compile(r'^byte ptr \[esp(?: \+ 0x[0-9a-f]+)?\], 0xb1$')
LOAD = re.compile(r'^(e[a-z]{2}), dword ptr \[(e[a-z]{2}) \+ (0x[0-9a-f]+)\]$')
ART_CONSTANTS = (0x4EC, 0x2A6C)       # BuffIcons gump, status gump


def _index(code, va):
    if hasattr(code, 'index'):
        return code.index(va)
    try:
        return list(code.addr).index(va)
    except ValueError:
        return -1


def _b1_markers(code):
    n = len(code.addr)
    for k in range(n - 3):
        mn, op = code.mn[k], code.op[k]
        if mn == 'push' and op == '0xb1' and 'call' in (code.mn[k + 1], code.mn[k + 2]):
            yield k
        elif mn == 'mov' and B1_STORE.match(op):
            yield k


def reply_fields(code, max_scan=200):
    """-> (serial, type_id, evidence) or None"""
    found = collections.Counter()
    where = {}
    for k in _b1_markers(code):
        f = code.func_of(code.addr[k])
        if f is None:
            continue
        kf = _index(code, f)
        if kf < 0 or k - kf > max_scan:
            continue
        reg = None
        serial = None
        for j in range(kf, k):
            mn, op = code.mn[j], code.op[j]
            if reg is None:
                m = re.match(r'^(e[a-z]{2}), ecx$', op)
                if mn == 'mov' and m and m.group(1) not in ('ecx', 'esp'):
                    reg = m.group(1)
                continue
            m = MEM.search(op)
            if m and m.group(1) == 'dword' and m.group(2) == reg:
                serial = int(m.group(3), 16)
                break
        if reg is None or serial is None:
            continue
        type_id = None
        for j in range(k + 1, min(k + 24, len(code.addr))):
            m = LOAD.match(code.op[j]) if code.mn[j] == 'mov' else None
            if m and m.group(2) == reg and int(m.group(3), 16) != serial:
                type_id = int(m.group(3), 16)
                break
        if type_id is None or type_id != serial + 4:
            continue
        found[(serial, type_id)] += 1
        where.setdefault((serial, type_id), (f, code.addr[k]))
    if not found:
        return None
    (serial, type_id), cnt = found.most_common(1)[0]
    if len(found) > 1:
        return None                                   # two different answers: no guess
    f, at = where[(serial, type_id)]
    return serial, type_id, 'the $B1 gump reply at %08X (function %08X) reads the serial at +$%X and the type ID at +$%X' % (
        at, f, serial, type_id)


def art_offset(code):
    """-> (offset, evidence) or None"""
    per = {c: collections.Counter() for c in ART_CONSTANTS}
    for k in range(len(code.addr)):
        if code.mn[k] != 'mov':
            continue
        op = code.op[k]
        for c in ART_CONSTANTS:
            if op.endswith(', 0x%x' % c):
                m = MEM.search(op)
                if m and m.group(1) == 'dword' and op.startswith('dword ptr ['):
                    per[c][int(m.group(3), 16)] += 1
    buff = per[0x4EC]
    if not buff:
        return None
    off, cnt = buff.most_common(1)[0]
    status = per[0x2A6C]
    if status and status.most_common(1)[0][0] != off:
        return None                                   # the two constructors disagree
    how = 'the BuffIcons gump constructor stores its graphic $4EC at +$%X (%d stores)' % (off, cnt)
    if status:
        how += ', the status gump its $2A6C at the same offset'
    return off, how


def minimized_offset(code, contsize):
    """-> (offset, width, evidence) or None. contsize = B_CONTSIZEX."""
    if not contsize:
        return None
    c = collections.Counter()
    n = len(code.addr)
    for k in range(n):
        if code.mn[k] not in ('cmp', 'test'):
            continue
        m = MEM.search(code.op[k])
        if not m or not code.op[k].startswith(m.group(0)):
            continue
        size, reg, x = m.group(1), m.group(2), int(m.group(3), 16)
        if not 0x60 <= x <= 0x200:
            continue
        loads = set()
        for j in range(k + 1, min(k + 12, n)):
            lm = LOAD.match(code.op[j]) if code.mn[j] == 'mov' else None
            if lm and lm.group(2) == reg:
                loads.add(int(lm.group(3), 16))
        if {contsize, contsize + 4, contsize + 8, contsize + 12} <= loads:
            c[(x, size)] += 1
    if not c:
        return None
    ranked = c.most_common()
    if len(ranked) > 1 and ranked[1][1] == ranked[0][1]:
        return None
    (x, size), cnt = ranked[0]
    width = {'byte': 1, 'word': 2, 'dword': 4}[size]
    return x, width, ('the bring-to-front code tests the %s at +$%X and then takes the size from +$%X or +$%X '
                      '(%d places)' % (size, x, contsize, contsize + 8, cnt))


def derive(code, values):
    """values: the base state (needs B_CONTSIZEX). -> {field: (value, evidence)}"""
    out = {}
    r = reply_fields(code)
    if r:
        out['B_GUMPSERIAL'] = (r[0], r[2])
        out['B_GUMPTYPE'] = (r[1], r[2])
    a = art_offset(code)
    if a:
        out['B_GUMPART'] = a
    m = minimized_offset(code, values.get('B_CONTSIZEX', 0))
    if m:
        out['B_GUMPMIN'] = (m[0], m[2] + ('' if m[1] == 4 else ' -- NOTE: not a dword, ScanGumps reads 4 bytes'))
    return out
