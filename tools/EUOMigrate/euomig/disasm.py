"""Linear-sweep disassembly of the code sections, function boundaries and operand helpers.

The sweep is cached per exe (keyed by its SHA-256) because it is the slow part (~1M instructions).
"""
import bisect
import os
import pickle
import re
from array import array

import capstone
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

from . import TOOL_VERSION

HEX = re.compile(r'0x[0-9a-f]+')
BRACKET = re.compile(r'\[([^\]]*)\]')
REG = re.compile(r'\b(e[abcd]x|e[sd]i|e[sb]p|[abcd][lhx]|[sd]il?|[sb]pl?)\b')
SIZE = {'byte': 1, 'word': 2, 'dword': 4, 'qword': 8, 'xmmword': 16, 'tbyte': 10}

# instructions whose FIRST operand is written when it is a memory operand
WRITES = {'mov', 'movzx', 'movsx', 'add', 'sub', 'and', 'or', 'xor', 'inc', 'dec', 'neg', 'not',
          'shl', 'shr', 'sar', 'sal', 'rol', 'ror', 'adc', 'sbb', 'pop', 'xchg', 'lock',
          'fstp', 'fst', 'fistp', 'fist', 'movss', 'movsd', 'movq', 'movd', 'movaps', 'movups',
          'movdqa', 'movdqu', 'movlpd', 'movhpd', 'cmpxchg', 'xadd', 'stosd', 'setne', 'sete',
          'setg', 'setl', 'setge', 'setle', 'seta', 'setb', 'setae', 'setbe'}


def cache_dir():
    base = os.environ.get('EUOMIGRATE_CACHE') or os.path.join(
        os.environ.get('LOCALAPPDATA') or os.path.expanduser('~'), 'EUOMigrate', 'cache')
    os.makedirs(base, exist_ok=True)
    return base


class Code:
    """All instructions of the executable sections, in address order.

    addr[k], size[k], mn[k], op[k]  -- capstone's lite tuple, split into parallel arrays
    funcs                           -- sorted function start addresses
    """

    def __init__(self, pe, use_cache=True, extra_starts=()):
        self.pe = pe
        path = os.path.join(cache_dir(), '%s.v%s.pkl' % (pe.sha256()[:24], TOOL_VERSION))
        if use_cache and os.path.exists(path):
            with open(path, 'rb') as f:
                self.addr, self.size, self.mn, self.op = pickle.load(f)
        else:
            self._sweep()
            if use_cache:
                with open(path, 'wb') as f:
                    pickle.dump((self.addr, self.size, self.mn, self.op), f, protocol=4)
        self._find_functions(extra_starts)

    # ---- sweep ---------------------------------------------------------------------------
    def _sweep(self):
        md = Cs(CS_ARCH_X86, CS_MODE_32)
        md.skipdata = True
        addr = array('I')
        size = bytearray()
        mn, op = [], []
        intern = {}
        for s in self.pe.code_sections():
            data = self.pe.section_bytes(s)
            start = self.pe.base + s.va
            for (a, sz, m, o) in md.disasm_lite(data, start):
                addr.append(a)
                size.append(sz)
                mn.append(intern.setdefault(m, m))
                op.append(o)
        self.addr, self.size, self.mn, self.op = addr, size, mn, op

    # ---- indexing ------------------------------------------------------------------------
    def __len__(self):
        return len(self.addr)

    def index(self, va):
        """index of the instruction starting at va, or -1"""
        k = bisect.bisect_left(self.addr, va)
        return k if k < len(self.addr) and self.addr[k] == va else -1

    def index_at_or_before(self, va):
        return bisect.bisect_right(self.addr, va) - 1

    def ins(self, k):
        return self.addr[k], self.size[k], self.mn[k], self.op[k]

    def raw(self, k):
        return self.pe.read(self.addr[k], self.size[k])

    # ---- functions -----------------------------------------------------------------------
    def _find_functions(self, extra_starts):
        pe = self.pe
        starts = set(a for a in extra_starts if pe.is_code(a))
        starts.add(pe.entry)
        addr, mn, op = self.addr, self.mn, self.op
        n = len(addr)
        prev = ''
        for k in range(n):
            m = mn[k]
            if m == 'call':
                o = op[k]
                if o.startswith('0x'):
                    t = int(o, 16)
                    if pe.is_code(t):
                        starts.add(t)
            elif m != 'int3' and prev == 'int3':
                starts.add(addr[k])
            elif m == 'push' and op[k] == 'ebp' and k + 1 < n and mn[k + 1] == 'mov' and op[k + 1] == 'ebp, esp':
                if prev in ('ret', 'jmp', 'int3', 'nop', ''):
                    starts.add(addr[k])
            prev = m
        # code pointers stored in data sections (vtables, callback tables) start functions --
        # except switch jump tables, whose entries are case labels inside a function
        jt_entries = set()
        for k in range(n):
            if mn[k] == 'jmp' and '*4 + 0x' in op[k] and '[' in op[k]:
                m = HEX.findall(op[k])
                if not m:
                    continue
                t = int(m[-1], 16)
                while True:
                    v = pe.u32(t)
                    if not pe.is_code(v):
                        break
                    jt_entries.add(t)
                    t += 4
        # A dword in data that "points into code" is only trusted as a function start with more
        # evidence: on a relocatable build the slot must be in the relocation table; on a fixed
        # build the target must follow padding / a ret / an unconditional jmp (UTF-16 text such as
        # 'N','X' = 0x0058004E otherwise splits functions in the middle).
        relocs = pe.relocs() if pe.relocatable else None
        for s in pe.data_sections():
            data = pe.section_bytes(s)
            base = pe.base + s.va
            for i in range(0, len(data) - 3, 4):
                slot = base + i
                if slot in jt_entries:
                    continue
                v = int.from_bytes(data[i:i + 4], 'little')
                if not (pe.base <= v < pe.hi) or not pe.is_code(v):
                    continue
                if relocs is not None:
                    if slot not in relocs:
                        continue
                else:
                    k = self.index(v)
                    if k <= 0 or mn[k - 1] not in ('int3', 'nop', 'ret', 'jmp'):
                        continue
                starts.add(v)
        # keep only starts that are instruction boundaries
        self.funcs = sorted(a for a in starts if self.index(a) >= 0)
        self._fidx = {a: i for i, a in enumerate(self.funcs)}

    def func_of(self, va):
        i = bisect.bisect_right(self.funcs, va) - 1
        return self.funcs[i] if i >= 0 else None

    def func_range(self, f):
        """(k0, k1) instruction index range [k0, k1) of the function starting at f"""
        k0 = self.index(f)
        i = self._fidx[f]
        end = self.funcs[i + 1] if i + 1 < len(self.funcs) else self.pe.hi
        k1 = bisect.bisect_left(self.addr, end)
        return k0, k1


# ---- operand helpers -----------------------------------------------------------------------
def mem_operands(op):
    """list of (size, inner_text, absolute_value_or_None, has_base_reg) for every [..] operand"""
    out = []
    for m in BRACKET.finditer(op):
        inner = m.group(1)
        pre = op[:m.start()].rstrip().split(' ')
        sz = SIZE.get(pre[-2] if len(pre) >= 2 and pre[-1] == 'ptr' else '', 0)
        regs = REG.findall(inner)
        base_regs = [r for r in regs if ('*' + '') not in inner or not re.search(r'\b%s\*' % r, inner)]
        nums = HEX.findall(inner)
        absval = int(nums[-1], 16) if nums else None
        has_base = any(not re.search(r'\b%s\s*\*' % r, inner) for r in regs)
        if not nums and not inner.strip().startswith('0'):
            absval = None
        out.append((sz, inner, absval, has_base))
    return out


def immediates(op):
    """hex numbers that are NOT inside a memory operand"""
    return [int(h, 16) for h in HEX.findall(BRACKET.sub(' ', op))]


def first_operand_is_mem(op):
    return op.split(',')[0].find('[') >= 0


def shape(mn, op):
    """instruction shape for alignment: numbers become N, registers kept"""
    return mn + ' ' + HEX.sub('N', op)
