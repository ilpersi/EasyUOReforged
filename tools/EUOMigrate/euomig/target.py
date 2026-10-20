"""A client exe loaded for analysis: PE, disassembly and fingerprints, with the fingerprints cached
next to the disassembly (both keyed by the exe's SHA-256, so a changed file is never served stale)."""
import os
import pickle

from . import TOOL_VERSION
from .disasm import Code, cache_dir
from .features import FuncDB
from .pe import PE


class Target:
    def __init__(self, path, use_cache=True, log=None):
        log = log or (lambda *a: None)
        self.path = os.path.abspath(path)
        self.pe = PE(self.path)
        log('disassembling %s' % os.path.basename(path))
        self.code = Code(self.pe, use_cache=use_cache)
        cp = os.path.join(cache_dir(), '%s.fdb.v%s.pkl' % (self.pe.sha256()[:24], TOOL_VERSION))
        if use_cache and os.path.exists(cp):
            with open(cp, 'rb') as f:
                self.db = pickle.load(f)
        else:
            log('fingerprinting %d functions' % len(self.code.funcs))
            self.db = FuncDB.from_code(self.code)
            if use_cache:
                with open(cp, 'wb') as f:
                    pickle.dump(self.db, f, protocol=4)
        self.version = self.pe.file_version()
        self.stamp = self.pe.stamp
        self.relocatable = self.pe.relocatable

    @property
    def vtables(self):
        """link-time vtable address -> RTTI class name"""
        if not hasattr(self, '_vt'):
            self._vt = self.pe.rtti_vtables(self.pe.strings())
        return self._vt

    @property
    def id(self):
        return '%s-%08X' % (self.version, self.stamp)

    def label(self):
        return '%s %s (stamp %08X, %s)' % (os.path.basename(self.path), self.version, self.stamp,
                                          'relocatable' if self.relocatable else 'fixed base')
