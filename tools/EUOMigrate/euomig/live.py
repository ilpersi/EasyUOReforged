"""Read-only access to a running (32-bit, WOW64) UO client from 64-bit Python, via ctypes.

Nothing here writes to the process or sends it input; probe.py does that, and only when asked.
  Process.attach(target)  find the running process of the target exe (same file), its load
                          address and the delta to the exe's link-time base
  read / u8 / u16 / u32 / cstr
  thread_stacks()         [(tid, lo, hi)] from each thread's 32-bit TEB
  return_addresses(code)  link-time addresses found on the threads' stacks that follow a call
                          instruction -- old ones included: a function that ever ran in the
                          deep part of a stack leaves them; one that never ran cannot
"""
import collections
import ctypes
import ctypes.wintypes as wt
import os
import struct

k32 = ctypes.WinDLL('kernel32', use_last_error=True)
psapi = ctypes.WinDLL('psapi', use_last_error=True)
ntdll = ctypes.WinDLL('ntdll')

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
THREAD_QUERY_INFORMATION = 0x0040
TH32CS_SNAPPROCESS = 0x2
TH32CS_SNAPTHREAD = 0x4
LIST_MODULES_32BIT = 0x01

k32.OpenProcess.restype = wt.HANDLE
k32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
k32.OpenThread.restype = wt.HANDLE
k32.OpenThread.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
k32.ReadProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
k32.CloseHandle.argtypes = [wt.HANDLE]
k32.CreateToolhelp32Snapshot.restype = wt.HANDLE
k32.VirtualQueryEx.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
psapi.EnumProcessModulesEx.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), wt.DWORD]
psapi.GetModuleFileNameExW.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.LPWSTR, wt.DWORD]
ntdll.NtQueryInformationThread.argtypes = [wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.ULONG, ctypes.POINTER(wt.ULONG)]


class PROCESSENTRY32W(ctypes.Structure):
    _fields_ = [('dwSize', wt.DWORD), ('cntUsage', wt.DWORD), ('th32ProcessID', wt.DWORD),
                ('th32DefaultHeapID', ctypes.c_void_p), ('th32ModuleID', wt.DWORD), ('cntThreads', wt.DWORD),
                ('th32ParentProcessID', wt.DWORD), ('pcPriClassBase', ctypes.c_long), ('dwFlags', wt.DWORD),
                ('szExeFile', wt.WCHAR * 260)]


class THREADENTRY32(ctypes.Structure):
    _fields_ = [('dwSize', wt.DWORD), ('cntUsage', wt.DWORD), ('th32ThreadID', wt.DWORD),
                ('th32OwnerProcessID', wt.DWORD), ('tpBasePri', ctypes.c_long), ('tpDeltaPri', ctypes.c_long),
                ('dwFlags', wt.DWORD)]


class THREAD_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [('ExitStatus', ctypes.c_long), ('TebBaseAddress', ctypes.c_void_p),
                ('UniqueProcess', ctypes.c_void_p), ('UniqueThread', ctypes.c_void_p),
                ('AffinityMask', ctypes.c_size_t), ('Priority', ctypes.c_long), ('BasePriority', ctypes.c_long)]


class MBI(ctypes.Structure):
    _fields_ = [('BaseAddress', ctypes.c_void_p), ('AllocationBase', ctypes.c_void_p), ('AllocationProtect', wt.DWORD),
                ('PartitionId', wt.WORD), ('RegionSize', ctypes.c_size_t), ('State', wt.DWORD),
                ('Protect', wt.DWORD), ('Type', wt.DWORD)]


def processes():
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    e = PROCESSENTRY32W()
    e.dwSize = ctypes.sizeof(e)
    out = []
    ok = k32.Process32FirstW(snap, ctypes.byref(e))
    while ok:
        out.append((e.th32ProcessID, e.szExeFile))
        ok = k32.Process32NextW(snap, ctypes.byref(e))
    k32.CloseHandle(snap)
    return out


class Process:
    def __init__(self, pid):
        self.pid = pid
        self.h = k32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
        if not self.h:
            err = ctypes.get_last_error()
            if err == 5:
                raise OSError('OpenProcess(%d): access denied -- the client runs with more rights than '
                              'this Python (as administrator?): start the client normally, or run this '
                              'command from an elevated prompt' % pid)
            raise OSError('OpenProcess(%d) failed, error %d' % (pid, err))
        self.base, self.path = self._main_module()

    def _main_module(self):
        mods = (ctypes.c_void_p * 512)()
        need = wt.DWORD()
        if not psapi.EnumProcessModulesEx(self.h, mods, ctypes.sizeof(mods), ctypes.byref(need), LIST_MODULES_32BIT):
            raise OSError('EnumProcessModulesEx failed, error %d' % ctypes.get_last_error())
        buf = ctypes.create_unicode_buffer(1024)
        psapi.GetModuleFileNameExW(self.h, mods[0], buf, 1024)
        return mods[0] or 0, buf.value

    @classmethod
    def attach(cls, target, pid=None):
        """the running process of this exe: same path, or (a renamed / patched copy, e.g. a client
        with its encryption removed -- pass its pid) the same PE stamp"""
        cands = [p for p, n in processes() if pid in (None, p) and
                 n.lower() == os.path.basename(target.path).lower()]
        if pid and not cands:
            cands = [pid]
        errors = []
        for p in cands:
            try:
                pr = cls(p)
            except OSError as e:
                errors.append(str(e))
                continue
            if os.path.normcase(os.path.abspath(pr.path)) == os.path.normcase(target.path) or \
                    pr.u32(pr.base + 0x3C) is not None and pr._stamp() == target.stamp:
                pr.delta = (pr.base - target.pe.base) & 0xFFFFFFFF
                return pr
            pr.close()
        if errors:
            raise SystemExit('\n'.join(errors))
        raise SystemExit('no running %s found (start the client and log in first; for a renamed or '
                         'patched copy pass --pid)' % os.path.basename(target.path))

    def _stamp(self):
        e = self.u32(self.base + 0x3C)
        return self.u32(self.base + e + 8)

    def close(self):
        if self.h:
            k32.CloseHandle(self.h)
            self.h = None

    # ---- memory -------------------------------------------------------------------------------
    def read(self, addr, n):
        buf = ctypes.create_string_buffer(n)
        got = ctypes.c_size_t(0)
        k32.ReadProcessMemory(self.h, ctypes.c_void_p(addr), buf, n, ctypes.byref(got))
        return buf.raw[:got.value]

    def u8(self, a):
        d = self.read(a, 1)
        return d[0] if d else None

    def u16(self, a):
        d = self.read(a, 2)
        return struct.unpack('<H', d)[0] if len(d) == 2 else None

    def u32(self, a):
        d = self.read(a, 4)
        return struct.unpack('<I', d)[0] if len(d) == 4 else None

    def cstr(self, a, n=64):
        d = self.read(a, n)
        return d.split(b'\0')[0].decode('latin1') if d else None

    def readable(self, a, n=4):
        return len(self.read(a, n)) == n

    def regions(self, lo=0x10000, hi=0x7FFE0000):
        a = lo
        mbi = MBI()
        while a < hi:
            if not k32.VirtualQueryEx(self.h, ctypes.c_void_p(a), ctypes.byref(mbi), ctypes.sizeof(mbi)):
                break
            base = mbi.BaseAddress or 0
            if mbi.State == 0x1000 and not (mbi.Protect & 0x101):
                yield base, mbi.RegionSize, mbi.Protect
            if not mbi.RegionSize:
                break
            a = base + mbi.RegionSize

    # ---- threads and stacks ---------------------------------------------------------------------
    def threads(self):
        snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
        e = THREADENTRY32()
        e.dwSize = ctypes.sizeof(e)
        out = []
        ok = k32.Thread32First(snap, ctypes.byref(e))
        while ok:
            if e.th32OwnerProcessID == self.pid:
                out.append(e.th32ThreadID)
            ok = k32.Thread32Next(snap, ctypes.byref(e))
        k32.CloseHandle(snap)
        return out

    def thread_stacks(self):
        out = []
        for tid in self.threads():
            th = k32.OpenThread(THREAD_QUERY_INFORMATION, False, tid)
            if not th:
                continue
            tbi = THREAD_BASIC_INFORMATION()
            if ntdll.NtQueryInformationThread(th, 0, ctypes.byref(tbi), ctypes.sizeof(tbi), None) == 0 and tbi.TebBaseAddress:
                teb32 = tbi.TebBaseAddress + 0x2000            # WOW64: the 32-bit TEB follows the 64-bit one
                hi, lo = self.u32(teb32 + 4), self.u32(teb32 + 8)
                if hi and lo and lo < hi:
                    out.append((tid, lo, hi))
            k32.CloseHandle(th)
        return out

    def return_addresses(self, code):
        """Counter(link-time return address) over all thread stacks"""
        pe = code.pe
        lo_img, hi_img = pe.base, pe.hi
        c = collections.Counter()
        for tid, lo, hi in self.thread_stacks():
            data = self.read(lo, hi - lo)
            if not data:
                # the low part of the reserved stack is not committed: read the committed tail
                for base, size, prot in self.regions(lo, hi):
                    data = self.read(base, min(size, hi - base))
                    self._scan_returns(data, code, lo_img, hi_img, c)
                continue
            self._scan_returns(data, code, lo_img, hi_img, c)
        return c

    def _scan_returns(self, data, code, lo_img, hi_img, c):
        n = len(data) // 4
        for v in struct.unpack('<%dI' % n, data[:n * 4]):
            a = (v - self.delta) & 0xFFFFFFFF
            if lo_img <= a < hi_img:
                k = code.index(a)
                if k > 0 and code.mn[k - 1] == 'call':
                    c[a] += 1
