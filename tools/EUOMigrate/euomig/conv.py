"""Calling conventions of the client functions EasyUO calls, and the F_* flags / B_PATHPROLOGUE
that follow from them (uo\\uoclidata.pas, FEATURES section).

A function's convention is read from its code:
  inputs   ecx / edx read before anything writes them, in the straight-line code from the entry
           (up to the first call, jump or return). `push ecx` (MSVC's 4-byte stack reserve) and
           `xor reg, reg` do not count as reads.
  ret      the immediate of its `ret N` instructions (bytes the callee pops), 0 for a plain ret.
"""
import collections

from capstone import Cs, CS_ARCH_X86, CS_MODE_32

_md = Cs(CS_ARCH_X86, CS_MODE_32)
_md.detail = True

REGS = {'ecx': ('ecx', 'cx', 'cl', 'ch'), 'edx': ('edx', 'dx', 'dl', 'dh')}


def convention(code, start, max_insn=40):
    k0 = code.index(start)
    if k0 < 0:
        return None
    k0_, k1 = code.func_range(start) if start in code._fidx else (k0, k0 + 200)
    written = set()
    inputs = set()
    for k in range(k0, min(k1, k0 + max_insn)):
        mn, op = code.mn[k], code.op[k]
        d = next(_md.disasm(code.raw(k), code.addr[k]), None)
        if d is None:
            break
        rd, wr = d.regs_access()
        rd = {d.reg_name(r) for r in rd}
        wr = {d.reg_name(r) for r in wr}
        idiom_clear = mn in ('xor', 'sub') and len(op.split(',')) == 2 and op.split(',')[0].strip() == op.split(',')[1].strip()
        for r, names in REGS.items():
            if r in written:
                continue
            reads = bool(rd & set(names))
            if mn == 'push' and op == r:
                reads = False
            if idiom_clear:
                reads = False
            if reads:
                inputs.add(r)
            if wr & set(names):
                written.add(r)
        # `mov eax, size; call __chkstk` in a prologue probes the stack and preserves ecx/edx
        if mn == 'call' and k - k0 <= 4 and k > k0 and code.mn[k - 1] == 'mov' and code.op[k - 1].startswith('eax, 0x'):
            continue
        if mn in ('call', 'ret', 'jmp') or mn.startswith('j'):
            break
    rets = collections.Counter()
    for k in range(k0, k1):
        if code.mn[k] == 'ret':
            o = code.op[k]
            rets[int(o, 16) if o else 0] += 1
    ret = rets.most_common(1)[0][0] if rets else None
    return {'inputs': inputs, 'ret': ret}


def seh_prologue_len(code, start, max_insn=24):
    """bytes from the entry through the instruction that installs the SEH frame (mov fs:[0], reg)"""
    k0 = code.index(start)
    if k0 < 0:
        return None
    n = 0
    for k in range(k0, k0 + max_insn):
        n += code.size[k]
        if code.mn[k] == 'mov' and code.op[k].startswith('dword ptr fs:[0],'):
            return n
    return None


def derive(code, values):
    """values: field -> link-time address (usable ones). -> {field: (value, evidence)}"""
    out = {}

    def conv(f):
        v = values.get(f)
        return (v, convention(code, v)) if v else (None, None)

    v, c = conv('E_SENDPACKET')
    if c and c['ret'] is not None:
        thiscall = 'ecx' in c['inputs'] and c['ret'] == 4
        out['F_SENDTHISCALL'] = (int(thiscall), 'E_SENDPACKET %08X: inputs %s, ret %d' % (v, sorted(c['inputs']) or '-', c['ret']))
    v, c = conv('E_DRAGADDR')
    if c and c['ret'] is not None:
        fast = {'ecx', 'edx'} <= c['inputs'] and c['ret'] == 0
        out['F_DRAGFASTCALL'] = (int(fast), 'E_DRAGADDR %08X: inputs %s, ret %d' % (v, sorted(c['inputs']) or '-', c['ret']))
    v, c = conv('C_BLOCKINFO')
    if c and c['ret'] is not None:
        fast = {'ecx', 'edx'} <= c['inputs'] and c['ret'] == 0
        out['F_BLOCKINFOFAST'] = (int(fast), 'C_BLOCKINFO %08X: inputs %s, ret %d' % (v, sorted(c['inputs']) or '-', c['ret']))
    v, c = conv('E_ITEMREQADDR')
    v2, c2 = conv('E_ITEMCHECKADDR')
    if c and c2 and c['ret'] is not None and c2['ret'] is not None:
        fast = 'ecx' in c['inputs'] and 'ecx' in c2['inputs'] and c['ret'] == 0 and c2['ret'] == 0
        out['F_PROPFAST'] = (int(fast), 'E_ITEMREQADDR %08X inputs %s ret %d, E_ITEMCHECKADDR %08X inputs %s ret %d' % (
            v, sorted(c['inputs']) or '-', c['ret'], v2, sorted(c2['inputs']) or '-', c2['ret']))
    if values.get('E_PATHFINDMID') and values.get('E_PATHFINDADDR'):
        n = seh_prologue_len(code, values['E_PATHFINDADDR'])
        if n:
            out['B_PATHPROLOGUE'] = (n, 'E_PATHFINDADDR %08X: SEH frame installed after $%X bytes' % (values['E_PATHFINDADDR'], n))
    return out
