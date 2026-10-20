"""Reads uo\\uoclidata.pas and resolves a version exactly the way TCstDB.Update does
(cumulative milestone deltas, then the ModernBuilds layout/addresses for a relocatable build).
"""
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
UOCLIDATA = os.path.join(REPO, 'uo', 'uoclidata.pas')
GOLDEN = os.path.join(REPO, 'tests', 'fixtures', 'uoclidata_golden.json')

ENTRY = re.compile(r'\(\s*Expr:\s*(\w+)\s*;\s*Val:\s*\$([0-9A-Fa-f]+)\s*\)')


def _strip_comments(src):
    src = re.sub(r'\{[^}]*\}', ' ', src)
    return re.sub(r'//[^\n]*', '', src)


class UoCliData:
    def __init__(self, path=UOCLIDATA):
        with open(path, encoding='latin1') as f:
            raw = f.read()
        src = _strip_comments(raw)
        m = re.search(r'TConstantNames\s*=\s*\((.*?)\);', src, re.S)
        self.fields = [n.strip() for n in m.group(1).split(',') if n.strip()]
        self.fields = [f for f in self.fields if f != 'LISTEND']
        # every TSysVarList array, by name
        self.lists = {}
        for m in re.finditer(r'(\w+)\s*:\s*array\s*\[\s*0\s*\.\.\s*\d+\s*\]\s*of\s+TSysVarList\s*=\s*\((.*?)\)\s*;', src, re.S):
            body = m.group(2)
            self.lists[m.group(1)] = [(e, int(v, 16)) for e, v in ENTRY.findall(body) if e != 'LISTEND']
        ms = re.search(r'Milestones\s*:\s*array.*?=\s*\((.*?)\)\s*;', src, re.S).group(1)
        self.milestones = re.findall(r"NormVer:\s*'([^']*)'\s*;\s*List:\s*@?(\w+)", ms)
        vi = re.search(r'VersionIndex\s*:\s*array.*?=\s*\((.*?)\)\s*;', src, re.S).group(1)
        self.versions = [(c, int(i)) for c, i in re.findall(r"Cli:\s*'([^']*)'\s*;\s*Milestone:\s*(\d+)", vi)]
        mb = re.search(r'ModernBuilds\s*:\s*array.*?=\s*\((.*?)\)\s*;', src, re.S)
        self.modern = []
        if mb:
            for st, lay, adr in re.findall(r'Stamp:\s*\$([0-9A-Fa-f]+)\s*;\s*Layout:\s*@?(\w+)\s*;\s*Addrs:\s*@?(\w+)', mb.group(1)):
                self.modern.append((int(st, 16), lay, adr))
        # the fields ApplyModernBuild zeroes: "if Expr in [A..B, C..D] then"
        am = re.search(r'procedure TCstDB\.ApplyModernBuild.*?if Expr in \[(.*?)\]', src, re.S)
        self.modern_reset = set()
        if am:
            for part in am.group(1).split(','):
                a, _, b = part.strip().partition('..')
                ia = self.fields.index(a.strip())
                ib = self.fields.index((b or a).strip())
                self.modern_reset.update(self.fields[ia:ib + 1])

    # ---- version lookup (ExactMatchMilestoneIndex / FloorMilestoneIndex) ------------------
    @staticmethod
    def normalize(ver):
        parts = re.findall(r'\d+', ver)
        if len(parts) < 3:
            return None
        parts = (parts + ['0'])[:4]
        return '.'.join('%03d' % int(p) for p in parts)

    def milestone_index(self, ver):
        low = ver.lower()
        for c, i in self.versions:
            if c.lower() == low:
                return i, True
        nv = self.normalize(ver)
        if nv is None:
            return -1, False
        for i, (norm, _lst) in enumerate(self.milestones):    # newest first
            if norm <= nv:
                return i, False
        return -1, False

    def known_versions(self):
        return [c for c, _ in self.versions]

    def resolve(self, ver, stamp=None, relocatable=False):
        """field -> value, as TCstDB.Update(ver) followed by ApplyModernBuild for a relocatable
        exe with the given PE stamp. Returns None when the version is unknown and floors below
        every milestone."""
        idx, _exact = self.milestone_index(ver)
        if idx < 0:
            return None
        vals = {f: 0 for f in self.fields}
        for i in range(len(self.milestones) - 1, idx - 1, -1):
            for e, v in self.lists.get(self.milestones[i][1], ()):
                vals[e] = v
        if relocatable and self.modern:
            for f in self.modern_reset:
                vals[f] = 0
            for e, v in self.lists.get(self.modern[0][1], ()):
                vals[e] = v
            for st, _lay, adr in self.modern:
                if st == stamp:
                    for e, v in self.lists.get(adr, ()):
                        vals[e] = v
        return vals

    def modern_stamps(self):
        return [st for st, _, _ in self.modern]

    def exact_table(self, ver, stamp, relocatable):
        """the verified table of exactly this build, or None. A fixed-base build needs its version
        in VersionIndex; a relocatable one its PE stamp in ModernBuilds (the version string does not
        tell a modern build from the fixed-base one with the same number)."""
        if relocatable:
            if stamp not in self.modern_stamps():
                return None
        elif not self.milestone_index(ver)[1]:
            return None
        return self.resolve(ver, stamp=stamp, relocatable=relocatable)

    def floor_state(self, ver):
        """what TCstDB.Update gives an unknown fixed-base version today: the nearest older
        milestone's cumulative state, plus that milestone's index"""
        idx, _ = self.milestone_index(ver)
        return (self.resolve(ver) if idx >= 0 else None), idx

    def milestone_state(self, idx):
        vals = {f: 0 for f in self.fields}
        for i in range(len(self.milestones) - 1, idx - 1, -1):
            for e, v in self.lists.get(self.milestones[i][1], ()):
                vals[e] = v
        return vals


def golden():
    with open(GOLDEN) as f:
        return {e['Cli']: {k: int(v, 16) for k, v in e['Fields'].items()} for e in json.load(f)}


def kind_of(field):
    return field[:2]          # 'C_', 'E_', 'B_', 'F_'
