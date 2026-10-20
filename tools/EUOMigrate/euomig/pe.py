"""Minimal 32-bit PE reader: everything EUOMigrate needs from a UO client exe, nothing more.

Addresses are LINK-TIME addresses (ImageBase from the file header + RVA), which is the form
uoclidata.pas stores for every build, relocatable or not.
"""
import hashlib
import re
import struct

IMAGE_DYNAMIC_BASE = 0x0040
IMAGE_SCN_MEM_EXECUTE = 0x20000000


class Section:
    __slots__ = ('name', 'va', 'vsize', 'raw_off', 'raw_size', 'flags')

    def __init__(self, name, va, vsize, raw_off, raw_size, flags):
        self.name, self.va, self.vsize = name, va, vsize
        self.raw_off, self.raw_size, self.flags = raw_off, raw_size, flags

    @property
    def size(self):
        return max(self.vsize, self.raw_size)

    @property
    def executable(self):
        return bool(self.flags & IMAGE_SCN_MEM_EXECUTE)


class PE:
    def __init__(self, path):
        self.path = path
        with open(path, 'rb') as f:
            self.raw = f.read()
        b = self.raw
        if b[:2] != b'MZ':
            raise ValueError('%s: not an MZ executable' % path)
        pe = struct.unpack_from('<I', b, 0x3C)[0]
        if b[pe:pe + 4] != b'PE\0\0':
            raise ValueError('%s: no PE header' % path)
        self.machine = struct.unpack_from('<H', b, pe + 4)[0]
        nsec = struct.unpack_from('<H', b, pe + 6)[0]
        self.stamp = struct.unpack_from('<I', b, pe + 8)[0]
        optsz = struct.unpack_from('<H', b, pe + 20)[0]
        opt = pe + 24
        magic = struct.unpack_from('<H', b, opt)[0]
        if magic != 0x10B:
            raise ValueError('%s: not a 32-bit (PE32) image' % path)
        self.entry_rva = struct.unpack_from('<I', b, opt + 16)[0]
        self.base = struct.unpack_from('<I', b, opt + 28)[0]
        self.image_size = struct.unpack_from('<I', b, opt + 56)[0]
        self.dll_chars = struct.unpack_from('<H', b, opt + 70)[0]
        ndirs = struct.unpack_from('<I', b, opt + 92)[0]
        self.dirs = [struct.unpack_from('<II', b, opt + 96 + 8 * i) for i in range(min(ndirs, 16))]
        so = opt + optsz
        self.sections = []
        for i in range(nsec):
            o = so + 40 * i
            name = b[o:o + 8].rstrip(b'\0').decode('latin1')
            vs, va, rs, ro = struct.unpack_from('<IIII', b, o + 8)
            fl = struct.unpack_from('<I', b, o + 36)[0]
            self.sections.append(Section(name, va, vs, ro, rs, fl))
        self._imports = None
        self._relocs = None
        self._version = None

    # ---- basic facts ----------------------------------------------------------------
    @property
    def relocatable(self):
        return bool(self.dll_chars & IMAGE_DYNAMIC_BASE)

    @property
    def entry(self):
        return self.base + self.entry_rva

    @property
    def hi(self):
        return self.base + self.image_size

    def in_image(self, va):
        return self.base <= va < self.hi

    def sha256(self):
        return hashlib.sha256(self.raw).hexdigest()

    def section_of(self, va):
        rva = va - self.base
        for s in self.sections:
            if s.va <= rva < s.va + s.size:
                return s
        return None

    def code_sections(self):
        return [s for s in self.sections if s.executable]

    def data_sections(self):
        return [s for s in self.sections if not s.executable and s.name not in ('.rsrc', '.reloc')]

    def is_code(self, va):
        s = self.section_of(va)
        return s is not None and s.executable

    def read(self, va, n):
        """n bytes at link-time address va; uninitialised parts (BSS) read as zero."""
        out = bytearray()
        while n > 0:
            s = self.section_of(va)
            if s is None:
                out += b'\0' * n
                break
            off = va - self.base - s.va
            take = min(n, s.size - off)
            raw_take = max(0, min(take, s.raw_size - off))
            if raw_take:
                out += self.raw[s.raw_off + off:s.raw_off + off + raw_take]
            out += b'\0' * (take - raw_take)
            va += take
            n -= take
        return bytes(out)

    def u32(self, va):
        return struct.unpack('<I', self.read(va, 4))[0]

    def section_bytes(self, s):
        return self.read(self.base + s.va, s.size)

    # ---- imports: IAT slot address -> 'dll!name' ------------------------------------
    def imports(self):
        if self._imports is not None:
            return self._imports
        res = {}
        rva, size = self.dirs[1] if len(self.dirs) > 1 else (0, 0)
        if rva:
            def cstr(r):
                return self.read(self.base + r, 256).split(b'\0')[0].decode('latin1')
            o = rva
            while True:
                oft, _ts, _fc, name, ft = struct.unpack('<IIIII', self.read(self.base + o, 20))
                if name == 0 and ft == 0:
                    break
                dll = cstr(name).lower()
                t = oft or ft
                i = 0
                while True:
                    v = self.u32(self.base + t + 4 * i)
                    if v == 0:
                        break
                    nm = ('ord%d' % (v & 0xFFFF)) if v & 0x80000000 else cstr(v + 2)
                    res[self.base + ft + 4 * i] = dll + '!' + nm
                    i += 1
                o += 20
        self._imports = res
        return res

    # ---- base relocations: set of link-time addresses holding an absolute address ----
    def relocs(self):
        if self._relocs is not None:
            return self._relocs
        res = set()
        rva, size = self.dirs[5] if len(self.dirs) > 5 else (0, 0)
        if rva and size:
            data = self.read(self.base + rva, size)
            o = 0
            while o + 8 <= len(data):
                page, bsize = struct.unpack_from('<II', data, o)
                if bsize < 8:
                    break
                for k in range(8, bsize, 2):
                    e = struct.unpack_from('<H', data, o + k)[0]
                    if e >> 12 == 3:                      # IMAGE_REL_BASED_HIGHLOW
                        res.add(self.base + page + (e & 0xFFF))
                o += bsize
        self._relocs = res
        return res

    # ---- file version from VS_FIXEDFILEINFO ------------------------------------------
    def file_version(self):
        if self._version is not None:
            return self._version
        ver = ''
        for s in self.sections:
            if s.name == '.rsrc':
                data = self.section_bytes(s)
                k = data.find(struct.pack('<I', 0xFEEF04BD))
                if k >= 0:
                    ms, ls = struct.unpack_from('<II', data, k + 8)
                    ver = '%d.%d.%d.%d' % (ms >> 16, ms & 0xFFFF, ls >> 16, ls & 0xFFFF)
                break
        self._version = ver
        return ver

    # ---- strings in data sections: address -> text ------------------------------------
    def strings(self, minlen=4):
        res = {}
        for s in self.data_sections():
            data = self.section_bytes(s)
            base = self.base + s.va
            for m in re.finditer(rb'[\x20-\x7e]{%d,}\x00' % minlen, data):
                res[base + m.start()] = m.group(0)[:-1].decode('latin1')
            for m in re.finditer(rb'(?:[\x20-\x7e]\x00){%d,}\x00\x00' % minlen, data):
                if m.start() % 2 == 0:
                    res.setdefault(base + m.start(), 'U:' + m.group(0)[:-2].decode('utf-16le'))
        return res

    # ---- MSVC RTTI: vtable address -> class name ---------------------------------------
    def rtti_vtables(self, strings=None):
        """Type descriptor = name string - 8; its CompleteObjectLocator holds the descriptor at
        +12; the vtable starts right after the dword that points at the COL."""
        strings = strings if strings is not None else self.strings()
        tds = {a - 8: t for a, t in strings.items() if t.startswith('.?AV') or t.startswith('.?AU')}
        if not tds:
            return {}
        dw = {}
        for s in self.data_sections():
            data = self.section_bytes(s)
            base = self.base + s.va
            for i in range(0, len(data) - 3, 4):
                v = struct.unpack_from('<I', data, i)[0]
                if self.base <= v < self.hi:
                    dw.setdefault(v, []).append(base + i)
        out = {}
        for td, name in tds.items():
            for col_td_slot in dw.get(td, ()):
                col = col_td_slot - 12
                for slot in dw.get(col, ()):
                    vt = slot + 4
                    if self.is_code(self.u32(vt)):
                        out[vt] = name
        return out
