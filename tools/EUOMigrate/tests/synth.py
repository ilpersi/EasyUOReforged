"""A synthetic 32-bit PE for the tests: no game files in the repository.

build(variant) writes a small exe with three sections at fixed RVAs (.text 0x1000, .rdata 0x2000,
.data 0x3000) and returns (path, addresses). Variant 'B' is the same program "rebuilt": an extra
function in front of the code, an extra string and extra globals in front of the data -- every
address moves, the code stays the same, which is what the matcher and the signatures must survive.
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
    return code, bytes(rd), addrs


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
