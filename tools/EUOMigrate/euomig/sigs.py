"""EUOUpdtr-style signatures: parse / scan (statically, on the exe file) / generate.

Line format (tools\\EUOUpdater\\EUO Updtr Strings *.txt):
    HEXPATTERN ; joker ; offset ; X|C|CB ; adjust ; {NAME}
  X  = the matched address (+offset) itself,  C = the dword stored there,
  CB = follow the rel32 there (address + dword + 4).  Then + adjust.
"""
import re
import struct

from .disasm import Code, HEX

LINE = re.compile(r'^\s*([0-9A-Fa-f]+)\s*;\s*([0-9A-Fa-f]{1,2})\s*;\s*([+-]?\d+)\s*;\s*(X|C|CB)\s*;\s*([+-]?\d+)\s*;\s*\{(\w+)\}')


class Sig:
    __slots__ = ('pattern', 'joker', 'offset', 'mode', 'adjust', 'name', 'line')

    def __init__(self, pattern, joker, offset, mode, adjust, name, line=''):
        self.pattern, self.joker, self.offset = pattern, joker, offset
        self.mode, self.adjust, self.name, self.line = mode, adjust, name, line

    def regex(self):
        return re.compile(b''.join(b'.' if b == self.joker else re.escape(bytes([b])) for b in self.pattern), re.S)

    def to_line(self):
        hx = self.pattern.hex().upper()
        off = ('+%02d' % self.offset) if self.offset >= 0 else ('-%02d' % -self.offset)
        adj = ('+%02d' % self.adjust) if self.adjust >= 0 else ('-%02d' % -self.adjust)
        return '%s ; %02X; %s; %-2s; %s; {%s}' % (hx.ljust(max(40, len(hx))), self.joker, off, self.mode, adj, self.name)


def parse_file(path):
    out = []
    with open(path, encoding='latin1') as f:
        for raw in f:
            if raw.lstrip().startswith('//'):
                continue
            m = LINE.match(raw)
            if not m:
                continue
            hx, jk, off, mode, adj, name = m.groups()
            out.append(Sig(bytes.fromhex(hx), int(jk, 16), int(off), mode, int(adj), name.upper(), raw.rstrip()))
    return out


def scan(pe, sig, maxhits=4):
    """static scan of the exe's code sections: list of resolved link-time values, one per match"""
    r = sig.regex()
    res = []
    for s in pe.code_sections():
        data = pe.section_bytes(s)
        base = pe.base + s.va
        for m in r.finditer(data):
            a = base + m.start() + sig.offset
            if sig.mode == 'X':
                v = a
            elif sig.mode == 'C':
                v = pe.u32(a)
            else:
                v = (a + pe.u32(a) + 4) & 0xFFFFFFFF
            res.append((v + sig.adjust) & 0xFFFFFFFF)
            if len(res) >= maxhits:
                return res
    return res


def first_match(pe, pattern, joker):
    """link-time address of the pattern's first occurrence in the code sections, or None"""
    r = re.compile(b''.join(b'.' if b == joker else re.escape(bytes([b])) for b in pattern), re.S)
    for s in pe.code_sections():
        m = r.search(pe.section_bytes(s))
        if m:
            return pe.base + s.va + m.start()
    return None


def runtime_scan(pe, entries):
    """TCstDB.ScanMemory over the exe file: each entry (field, pattern, joker, mode, add1, add2) in table
    order, at its pattern's FIRST occurrence (SearchMemRange); every entry that matches overwrites its
    field, so where several entries of a field match, the last one decides. Modes: 1 the address,
    2 follow the rel32 there, 3 the dword there, then + add2; 4 the dword at +add1 minus the one at +add2
    (a distance). -> {field: link-time value}"""
    out = {}
    for f, pattern, joker, mode, add1, add2 in entries:
        pos = first_match(pe, pattern, joker)
        if pos is None:
            continue
        a = (pos + add1) & 0xFFFFFFFF
        if mode == 4:
            out[f] = (pe.u32(a) - pe.u32((pos + add2) & 0xFFFFFFFF)) & 0xFFFFFFFF
            continue
        if mode == 2:
            a = (a + pe.u32(a) + 4) & 0xFFFFFFFF
        elif mode == 3:
            a = pe.u32(a)
        out[f] = (a + add2) & 0xFFFFFFFF
    return out


def scan_file(pe, sigs):
    """EUOUpdtr semantics: per name, the first line that matches exactly once wins"""
    out = {}
    for s in sigs:
        if s.name in out:
            continue
        hits = scan(pe, s)
        if len(hits) == 1:
            out[s.name] = hits[0]
    return out
