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
from .features import FuncDB
from .sigs import LINE, Sig

KB_SCHEMA = 1
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
