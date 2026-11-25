"""Knowledge base: one gzip'd JSON file per known build, holding everything needed to migrate FROM
that build without its exe: hashed function fingerprints, field descriptors and the field table.

File: kb/<version>-<stamp>.json.gz
  schema      KB_SCHEMA
  build       version, stamp, base, relocatable, image_size, sha256 (of the exe it was made from)
  source      where the table came from ('uoclidata.pas', 'migrated', 'migrated+verified', ...)
  table       field -> value (all fields, B_/F_ included)
  fields      field -> descriptor (see fields.py)
  funcdb      FuncDB.to_json()
  sigs        [[field, EUOUpdtr line]]: signatures validated on this build; a target of the same
              compiler usually still matches them (independent evidence next to the matcher's)
"""
import glob
import gzip
import json
import os

from . import TOOL_VERSION
from . import fields as FD
from .features import FuncDB
from .sigs import LINE, Sig

KB_SCHEMA = 1

# Values a knowledge-base build holds for a field that EasyUO no longer means by that field. The build's
# candidates and signatures for it are left out of the pooling (consensus.py); its exe is not at hand to
# fingerprint it again with the right value.
SUPERSEDED = {
    '7.0.117.1-6AC94360': {
        # $C8B858, from uoclidata.pas, is the targeting system's health bar (the bar that exists while a
        # mobile is selected; the first two C_ENEMYHITS lines of ScannerTable_Modern find it). EasyUO means
        # the attack bar the 0xAA handler opens for a new enemy, as client.exe's C_ENEMYHITS is: the last
        # C_ENEMYHITS line, verified on 7.0.117.31, 7.0.118.132 and 7.0.119.0. Its votes and signature put
        # those builds' targeting bar first (00CB2F90 / 00D22108 / 00F027DC instead of 00CB2FA0 / 00D22118 /
        # 00F027C0).
        'C_ENEMYHITS': "its C_ENEMYHITS is the targeting system's bar, not the 0xAA attack bar EasyUO means",
    },
}
HERE = os.path.dirname(os.path.abspath(__file__))
KB_DIR = os.path.normpath(os.path.join(HERE, '..', 'kb'))


class KBEntry:
    def __init__(self, d, path=None):
        if d.get('schema') != KB_SCHEMA:
            raise ValueError('%s: knowledge-base schema %r, this tool reads %d' % (path, d.get('schema'), KB_SCHEMA))
        self.path = path
        self.build = d['build']
        self.source = d.get('source', '')
        self.table = d['table']
        self.fields = d['fields']
        # the global-relative pseudo fields as fields.RELATIVE defines them today: drop the ones it no
        # longer has, add the ones the file predates (from its table; the image bounds stand in for the
        # section check the fingerprint made)
        b = self.build
        lo, hi = b.get('base', 0), b.get('base', 0) + b.get('image_size', 0)
        for k in [k for k in self.fields if k.startswith('@') and k[1:] not in FD.RELATIVE]:
            del self.fields[k]
        for k, desc in FD.pseudo_fields(self.table, lambda a: lo <= a < hi).items():
            self.fields.setdefault(k, desc)
        self.superseded = SUPERSEDED.get(self.id, {})
        self.funcdb = FuncDB.from_json(d['funcdb'])
        self.notes = d.get('notes', {})
        self.sigs = []
        for f, line in d.get('sigs', ()):
            m = LINE.match(line)
            if m:
                hx, jk, off, mode, adj, name = m.groups()
                self.sigs.append((f, Sig(bytes.fromhex(hx), int(jk, 16), int(off), mode, int(adj), name.upper(), line)))

    @property
    def id(self):
        return '%s-%08X' % (self.build['version'], self.build['stamp'])

    def label(self):
        return '%s (%s, stamp %08X%s)' % (self.build['version'], 'relocatable' if self.build['relocatable'] else 'fixed base',
                                          self.build['stamp'], ', ' + self.source if self.source else '')


def make(code, db, table, descs, source, notes=None, sigs=()):
    import capstone
    return {
        'schema': KB_SCHEMA,
        'tool': TOOL_VERSION,
        'capstone': capstone.__version__,
        'build': db.meta,
        'source': source,
        'table': table,
        'fields': descs,
        'funcdb': db.to_json(),
        'sigs': [[f, s.to_line()] for f, s in sigs],
        'notes': notes or {},
    }


def filename(d):
    return '%s-%08X.json.gz' % (d['build']['version'], d['build']['stamp'])


def save(d, kb_dir=KB_DIR):
    os.makedirs(kb_dir, exist_ok=True)
    path = os.path.join(kb_dir, filename(d))
    data = json.dumps(d, separators=(',', ':'), sort_keys=True).encode()
    with gzip.GzipFile(path, 'wb', mtime=0) as f:      # mtime=0: byte-identical rebuilds, clean diffs
        f.write(data)
    return path


def load(path):
    with gzip.open(path, 'rb') as f:
        return KBEntry(json.loads(f.read()), path)


def load_all(kb_dir=KB_DIR):
    return [load(p) for p in sorted(glob.glob(os.path.join(kb_dir, '*.json.gz')))]
