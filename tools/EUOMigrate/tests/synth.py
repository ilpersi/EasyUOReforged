"""A synthetic 32-bit PE for the tests: no game files in the repository.

build(variant) writes a small exe with three sections at fixed RVAs (.text 0x1000, .rdata 0x2000,
.data 0x3000) and returns (path, addresses). Variant 'B' is the same program "rebuilt": an extra
function in front of the code, an extra string and extra globals in front of the data -- every
address moves, the code stays the same, which is what the matcher and the signatures must survive.
.rdata also holds a vtable without RTTI ('VT': four code pointers), as the 7.0.119.0 game classes have.

Other programs for build(program=...):
  program_hands   the "last action" cluster of the betas: a global read at C_LHANDID + $C and the hands
                  table the arm/disarm macro indexes ([hand*4 + table]); build B moves the table
                  relative to C_LHANDID, as 7.0.119.0 did
  program_macro   a macro executor behind an SEH prologue and a __chkstk call: the 7.0.119.0 form
                  (fastcall, table in ecx, index in edx) and the older one (both from globals)
"""
import os
import struct
import tempfile

BASE = 0x400000
TEXT, RDATA, DATA = 0x1000, 0x2000, 0x3000


class Asm:
    def __init__(self, va):
        self.va = va
        self.b = bytearray()
        self.labels = {}
        self.fix = []                         # (offset, label) for rel32

    @property
    def here(self):
        return self.va + len(self.b)

    def label(self, name):
        self.labels[name] = self.here

    def raw(self, *bs):
        self.b += bytes(bs)

    def d(self, v):
        self.b += struct.pack('<I', v & 0xFFFFFFFF)

    def call(self, name):
        self.raw(0xE8)
        self.fix.append((len(self.b), name))
        self.d(0)

    def pad(self, n=4):
        self.raw(*([0xCC] * n))

    def done(self):
        for off, name in self.fix:
            tgt = self.labels[name]
            struct.pack_into('<i', self.b, off, tgt - (self.va + off + 4))
        return bytes(self.b)


def _program(variant):
    extra = variant == 'B'
    # .rdata: strings
    rd = bytearray()
    if extra:
        rd += b'AnotherBuildOnlyText\0'
    s1 = BASE + RDATA + len(rd)
    rd += b'SyntheticUniqueString\0'
    s2 = BASE + RDATA + len(rd)
    rd += b'SecondAnchorText\0'
    # .data: globals
    g0 = BASE + DATA + (16 if extra else 0)
    G = {'G1': g0, 'G2': g0 + 4, 'G3': g0 + 8, 'G4': g0 + 12}
    a = Asm(BASE + TEXT)
    if extra:                                  # something only build B has
        a.label('f0')
        a.raw(0x55, 0x8B, 0xEC, 0xB8); a.d(0x0BADF00D)
        a.raw(0x5D, 0xC3)
        a.pad()
    a.label('f1')                              # anchor: the unique string; reads G1, writes G2
    a.raw(0x55, 0x8B, 0xEC)                    # push ebp; mov ebp, esp
    a.raw(0xB9); a.d(0x13572468)               # mov ecx, 13572468h (a fixed constant)
    a.raw(0xA1); a.d(G['G1'])                  # mov eax, [G1]
    a.raw(0x68); a.d(s1)                       # push offset s1
    a.label('site')
    a.call('f2')                               # call f2    <- the "site" field
    a.raw(0xA3); a.d(G['G2'])                  # mov [G2], eax
    a.raw(0xBA); a.d(0x2468ACE0)               # mov edx, 2468ACE0h
    a.raw(0x5D, 0xC3)                          # pop ebp; ret
    a.pad()
    a.label('f2')                              # stdcall(1): reads G3
    a.raw(0x8B, 0x44, 0x24, 0x04)              # mov eax, [esp+4]
    a.raw(0x8B, 0x0D); a.d(G['G3'])            # mov ecx, [G3]
    a.raw(0x01, 0xC8)                          # add eax, ecx
    a.raw(0x05); a.d(0x11223344)               # add eax, 11223344h
    a.raw(0xC2, 0x04, 0x00)                    # ret 4
    a.pad()
    a.label('f3')                              # thiscall-like: ecx is an input; G1 -> G4
    a.raw(0x56)                                # push esi
    a.raw(0x8B, 0xF1)                          # mov esi, ecx
    a.raw(0xA1); a.d(G['G1'])                  # mov eax, [G1]
    a.raw(0x35); a.d(0x5A5A1234)               # xor eax, 5A5A1234h
    a.raw(0xA3); a.d(G['G4'])                  # mov [G4], eax
    a.raw(0x5E, 0xC3)                          # pop esi; ret
    a.pad()
    a.label('f4')                              # second anchor
    a.raw(0x55, 0x8B, 0xEC)
    a.raw(0x68); a.d(s2)                       # push offset s2
    a.call('f2')
    a.raw(0xB8); a.d(0x76543210)
    a.raw(0x5D, 0xC3)
    a.pad(16)
    code = a.done()
    addrs = dict(G)
    addrs.update({k: v for k, v in a.labels.items()})
    addrs['S1'], addrs['S2'] = s1, s2
    while len(rd) % 4:                         # a vtable without RTTI: code pointers in read-only data
        rd += b'\0'
    addrs['VT'] = BASE + RDATA + len(rd)
    for f in ('f1', 'f2', 'f3', 'f4'):
        rd += struct.pack('<I', addrs[f])
    return code, bytes(rd), addrs


def program_hands(variant):
    """C_LHANDID at LH; the last object at LH+$C; the hands table at LH+$10 (A) / LH+$14 (B), so the left
    hand (B_LHAND) is at +$14 / +$18 and the right one 4 after it"""
    rd = bytearray(b'LastObjectAnchorText\0')
    s1 = BASE + RDATA
    s2 = BASE + RDATA + len(rd)
    rd += b'ArmDisarmAnchorText\0'
    D = BASE + DATA
    lh = D if variant == 'A' else D + 4
    table = lh + (0x10 if variant == 'A' else 0x14)
    a = Asm(BASE + TEXT)
    a.label('f1')                              # uses the last object: [LH+$C]
    a.raw(0x55, 0x8B, 0xEC)
    a.raw(0x68); a.d(s1)                       # push offset s1
    a.raw(0xA1); a.d(lh + 0xC)                 # mov eax, [LH+$C]
    a.raw(0xA3); a.d(lh + 0xC)                 # mov [LH+$C], eax
    a.raw(0xB9); a.d(0x13572468)               # mov ecx, 13572468h
    a.raw(0x83, 0xC4, 0x04)                    # add esp, 4
    a.raw(0x5D, 0xC3)
    a.pad()
    a.label('f2')                              # arm/disarm: [hand*4 + table], hand on the stack
    a.raw(0x55, 0x8B, 0xEC)
    a.raw(0x68); a.d(s2)                       # push offset s2
    a.raw(0x8B, 0x45, 0x08)                    # mov eax, [ebp+8]
    a.raw(0x8B, 0x0C, 0x85); a.d(table)        # mov ecx, [eax*4 + table]
    a.raw(0x89, 0x14, 0x85); a.d(table)        # mov [eax*4 + table], edx
    a.raw(0xBA); a.d(0x2468ACE0)               # mov edx, 2468ACE0h
    a.raw(0x83, 0xC4, 0x04)
    a.raw(0x5D, 0xC2, 0x04, 0x00)              # ret 4
    a.pad()
    a.label('f3')                              # calls both
    a.raw(0x6A, 0x01)
    a.call('f2')
    a.call('f1')
    a.raw(0xC3)
    a.pad(16)
    code = a.done()
    addrs = dict(a.labels)
    addrs.update(LH=lh, TABLE=table, LHAND=table + 4 - lh)
    return code, bytes(rd), addrs


def program_macro(variant):
    """f1: the macro executor behind `push ebp; mov ebp,esp; push -1; push handler; mov eax,fs:[0]; push eax;
    mov eax,size; call __chkstk` -- 7 instructions before the call. Variant 'A' takes table and index in
    ecx / edx (7.0.119.0), 'B' loads them from two globals (the older betas)."""
    D = BASE + DATA
    a = Asm(BASE + TEXT)
    a.label('f1')
    a.raw(0x55, 0x8B, 0xEC)                    # push ebp; mov ebp, esp
    a.raw(0x6A, 0xFF)                          # push -1
    a.raw(0x68); a.d(0x00489100)               # push handler
    a.raw(0x64, 0xA1); a.d(0)                  # mov eax, fs:[0]
    a.raw(0x50)                                # push eax
    a.raw(0xB8); a.d(0x2090)                   # mov eax, 2090h
    a.call('chk')                              # call __chkstk
    a.raw(0xA1); a.d(D)                        # mov eax, [cookie]
    a.raw(0x33, 0xC5)                          # xor eax, ebp
    a.raw(0x89, 0x45, 0xF0)                    # mov [ebp-10h], eax
    a.raw(0x56, 0x57, 0x50)                    # push esi; push edi; push eax
    a.raw(0x8D, 0x45, 0xF4)                    # lea eax, [ebp-0Ch]
    a.raw(0x64, 0xA3); a.d(0)                  # mov fs:[0], eax
    if variant == 'A':
        a.raw(0x8D, 0x04, 0x92)                # lea eax, [edx+edx*4]
    else:
        a.raw(0xA1); a.d(D + 4)                # mov eax, [index]
        a.raw(0x8B, 0x0D); a.d(D + 8)          # mov ecx, [table]
        a.raw(0x8D, 0x04, 0x80)                # lea eax, [eax+eax*4]
    a.raw(0xBF); a.d(1)                        # mov edi, 1
    a.raw(0x8D, 0x34, 0x81)                    # lea esi, [ecx+eax*4]
    a.raw(0x5F, 0x5E)                          # pop edi; pop esi
    a.raw(0x8B, 0xE5, 0x5D, 0xC3)              # mov esp, ebp; pop ebp; ret
    a.pad()
    a.label('chk')                             # __chkstk: preserves ecx
    a.raw(0x51, 0x59, 0xC3)                    # push ecx; pop ecx; ret
    a.pad(16)
    return a.done(), b'MacroProgram\0', dict(a.labels)


def _align(n, a):
    return (n + a - 1) // a * a


def build(variant='A', stamp=None, relocatable=False, directory=None, program=None):
    """program: another variant -> (code, rdata, addrs) than the one above (globals within .data's 32 bytes)"""
    code, rdata, addrs = (program or _program)(variant)
    data = bytes(32)
    secs = [(b'.text', TEXT, code, 0x60000020), (b'.rdata', RDATA, rdata, 0x40000040),
            (b'.data', DATA, data, 0xC0000040)]
    hdr = bytearray(0x400)
    hdr[0:2] = b'MZ'
    struct.pack_into('<I', hdr, 0x3C, 0x40)
    hdr[0x40:0x44] = b'PE\0\0'
    struct.pack_into('<HHIIIHH', hdr, 0x44, 0x14C, len(secs), stamp or (0x5A000000 if variant == 'A' else 0x5B000000),
                     0, 0, 0xE0, 0x0102)
    opt = 0x58
    struct.pack_into('<H', hdr, opt, 0x10B)
    struct.pack_into('<I', hdr, opt + 16, addrs['f1'] - BASE)     # entry point
    struct.pack_into('<I', hdr, opt + 28, BASE)
    struct.pack_into('<II', hdr, opt + 32, 0x1000, 0x200)
    struct.pack_into('<I', hdr, opt + 56, 0x4000)                 # SizeOfImage
    struct.pack_into('<I', hdr, opt + 60, 0x400)                  # SizeOfHeaders
    struct.pack_into('<HH', hdr, opt + 68, 2, 0x40 if relocatable else 0)
    struct.pack_into('<I', hdr, opt + 92, 16)
    so = opt + 0xE0
    body = bytearray()
    raw_off = 0x400
    for i, (name, rva, blob, fl) in enumerate(secs):
        rs = _align(len(blob), 0x200)
        o = so + 40 * i
        hdr[o:o + 8] = name.ljust(8, b'\0')
        struct.pack_into('<IIII', hdr, o + 8, len(blob), rva, rs, raw_off + len(body))
        struct.pack_into('<I', hdr, o + 36, fl)
        body += blob.ljust(rs, b'\0')
    d = directory or tempfile.mkdtemp(prefix='euomig-test-')
    path = os.path.join(d, 'synthetic_%s.exe' % variant)
    with open(path, 'wb') as f:
        f.write(bytes(hdr) + bytes(body))
    return path, addrs
