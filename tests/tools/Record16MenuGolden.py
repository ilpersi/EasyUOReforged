"""Record EasyUO 1.6's MENU behaviour as golden values for Reforged's 1.6 MENU logic.

    python tests/tools/Record16MenuGolden.py -Exe <EasyUO 1.6 easyuo.exe> [probe ...]

The closed EasyUO 1.6.0.337 binary is not part of this repository: pass its path explicitly, as
VerifyCstDbData.ps1 takes the original source with -OrigFile. Only the Python standard library
is used. With no probe names, every probe is recorded.

Probes are the scripts tests/fixtures/menu16/<probe>.euo. Each one reports what it observed by
setting a form caption to "R:<tag>:<data>" (form0's through "menu window title", or a hidden
report form's through "menu setprop <form> text"); a caption can be read from outside the
process whether the form is shown or not. Lines starting with ";@" are comments to EasyUO and
steps to this recorder, run in order once the script has been started:

    ;@wait TAG [SECONDS]     wait for the report TAG (default 20 s) and record it
    ;@rewait TAG             the same, but only a report from a new window counts (after ;@start)
    ;@click CAPTION          click the button with this caption
    ;@close PREFIX           close (WM_CLOSE, as its [X] does) the form whose caption starts so
    ;@forms                  record every menu form: caption, visibility, position, client size,
                             and each child window's class, text, style and rectangle
    ;@snap PREFIX NAME X Y W H
                             save the client-area rectangle of that form as <probe>.<NAME>.png
    ;@alpha PREFIX           record that form's layered-window alpha
    ;@stop / ;@start         EasyUO's Stop / Start
    ;@sleep SECONDS

Every probe runs in a fresh EasyUO process, started from a temporary copy of the exe together
with the probe (saved as <probe>.txt with CRLF line ends) and golden.bmp, the picture probes
load with "menu image file". EasyUO 1.6 asks for elevation in its manifest; MENU does not need
it, so the copy runs with __COMPAT_LAYER=RunAsInvoker. Its startup notice is dismissed, and any
message box that appears while the probe runs is dismissed and recorded.

Output: tests/fixtures/menu16/<probe>.json (the recorded steps) and recording.json (the binary's
SHA-256 -- it carries no version resource -- and the Windows build and DPI the values were taken
on). Forms that already exist before Start belong to the other editor tabs' parsers and are left
out of ;@forms. The values are only
valid for the build in recording.json; frame sizes depend on Windows, so record again after a
change of Windows version rather than editing the files.

EasyUO 1.6 keeps its settings under HKCU\\Software\\EasyUO, the key EasyUO Reforged also uses,
and every run adds the probe to its recent-files list. The recorder saves the key's values first
and puts back whatever changed. Close EasyUO Reforged before recording.

See docs/menu-1.6-analysis.md, sections 6.7 and 9.1.
"""
import argparse
import ctypes
import ctypes.wintypes as W
import datetime
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import winreg
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES = os.path.normpath(os.path.join(HERE, '..', 'fixtures', 'menu16'))
RECORDER_VERSION = 1

u32 = ctypes.WinDLL('user32', use_last_error=True)
g32 = ctypes.WinDLL('gdi32')

EnumWindowsProc = ctypes.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
u32.EnumWindows.argtypes = [EnumWindowsProc, W.LPARAM]
u32.EnumChildWindows.argtypes = [W.HWND, EnumWindowsProc, W.LPARAM]
u32.GetWindowThreadProcessId.argtypes = [W.HWND, ctypes.POINTER(W.DWORD)]
u32.SendMessageTimeoutW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM, W.UINT, W.UINT,
                                    ctypes.POINTER(ctypes.c_size_t)]
u32.SendMessageTimeoutW.restype = W.LPARAM
u32.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
u32.GetAncestor.argtypes = [W.HWND, W.UINT]
u32.GetAncestor.restype = W.HWND
u32.GetWindowLongW.argtypes = [W.HWND, ctypes.c_int]
u32.GetWindowLongW.restype = ctypes.c_long
u32.GetLayeredWindowAttributes.argtypes = [W.HWND, ctypes.POINTER(W.DWORD), ctypes.POINTER(ctypes.c_ubyte),
                                           ctypes.POINTER(W.DWORD)]
u32.GetWindowDC.restype = W.HDC
u32.GetWindowDC.argtypes = [W.HWND]
u32.ReleaseDC.argtypes = [W.HWND, W.HDC]
u32.PrintWindow.argtypes = [W.HWND, W.HDC, W.UINT]
g32.CreateCompatibleDC.restype = W.HDC
g32.CreateCompatibleDC.argtypes = [W.HDC]
g32.CreateCompatibleBitmap.restype = W.HBITMAP
g32.CreateCompatibleBitmap.argtypes = [W.HDC, ctypes.c_int, ctypes.c_int]
g32.SelectObject.restype = W.HGDIOBJ
g32.SelectObject.argtypes = [W.HDC, W.HGDIOBJ]
g32.GetDIBits.argtypes = [W.HDC, W.HBITMAP, W.UINT, W.UINT, ctypes.c_void_p, ctypes.c_void_p, W.UINT]
g32.DeleteObject.argtypes = [W.HGDIOBJ]
g32.DeleteDC.argtypes = [W.HDC]

WM_GETTEXT, WM_GETTEXTLENGTH, WM_CLOSE, WM_COMMAND, BM_CLICK = 0x0D, 0x0E, 0x10, 0x111, 0xF5
GWL_STYLE, GWL_EXSTYLE, GA_PARENT = -16, -20, 1
WS_EX_LAYERED, LWA_ALPHA = 0x80000, 0x2
CMD_START, CMD_STOP = 27, 29          # EasyUO 1.6's main-menu command ids for Start and Stop
DIALOG_CLASSES = ('TMessageForm', '#32770')


# ---------------------------------------------------------------- windows

def pid_of(h):
    p = W.DWORD()
    u32.GetWindowThreadProcessId(h, ctypes.byref(p))
    return p.value


def cls(h):
    b = ctypes.create_unicode_buffer(256)
    u32.GetClassNameW(h, b, 256)
    return b.value


def text(h):
    r = ctypes.c_size_t()
    if not u32.SendMessageTimeoutW(h, WM_GETTEXTLENGTH, 0, 0, 2, 2000, ctypes.byref(r)):
        return None
    n = r.value + 1
    b = ctypes.create_unicode_buffer(n)
    u32.SendMessageTimeoutW(h, WM_GETTEXT, n, ctypes.cast(b, ctypes.c_void_p).value, 2, 2000, ctypes.byref(r))
    return b.value


def window_rect(h):
    r = W.RECT()
    u32.GetWindowRect(h, ctypes.byref(r))
    return [r.left, r.top, r.right - r.left, r.bottom - r.top]


def client_size(h):
    r = W.RECT()
    u32.GetClientRect(h, ctypes.byref(r))
    return [r.right, r.bottom]


def client_origin(h):
    p = W.POINT(0, 0)
    u32.ClientToScreen(h, ctypes.byref(p))
    return p.x, p.y


def visible(h):
    return bool(u32.IsWindowVisible(h))


def top_windows(pid):
    out = []

    def cb(h, _):
        if pid_of(h) == pid:
            out.append(h)
        return True
    u32.EnumWindows(EnumWindowsProc(cb), 0)
    return out


def direct_children(h):
    out = []

    def cb(c, _):
        if u32.GetAncestor(c, GA_PARENT) == h:
            out.append(c)
        return True
    u32.EnumChildWindows(h, EnumWindowsProc(cb), 0)
    return out


def describe_child(c, parent):
    x, y, w, h = window_rect(c)
    ox, oy = client_origin(parent)
    d = {'class': cls(c), 'text': text(c), 'visible': visible(c),
         'rect': [x - ox, y - oy, w, h],
         'style': '%08X' % (u32.GetWindowLongW(c, GWL_STYLE) & 0xFFFFFFFF)}
    kids = [describe_child(k, c) for k in direct_children(c)]
    if kids:
        d['children'] = kids
    return d


def describe_form(f):
    x, y, w, h = window_rect(f)
    return {'caption': text(f), 'visible': visible(f), 'left': x, 'top': y, 'width': w, 'height': h,
            'client': client_size(f),
            'style': '%08X' % (u32.GetWindowLongW(f, GWL_STYLE) & 0xFFFFFFFF),
            'exstyle': '%08X' % (u32.GetWindowLongW(f, GWL_EXSTYLE) & 0xFFFFFFFF),
            'children': [describe_child(c, f) for c in direct_children(f)]}


# ---------------------------------------------------------------- pictures

def png(path, width, height, rgb_rows):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b''.join(b'\0' + row for row in rgb_rows)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))


def capture_client(h, x, y, w, hh):
    """Rows of RGB bytes for a rectangle of the form's client area, as the form paints it."""
    wx, wy, ww, wh = window_rect(h)
    cx, cy = client_origin(h)
    hdc = u32.GetWindowDC(h)
    mdc = g32.CreateCompatibleDC(hdc)
    bmp = g32.CreateCompatibleBitmap(hdc, ww, wh)
    g32.SelectObject(mdc, bmp)
    u32.PrintWindow(h, mdc, 2)                 # PW_RENDERFULLCONTENT

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [('biSize', W.DWORD), ('biWidth', W.LONG), ('biHeight', W.LONG), ('biPlanes', W.WORD),
                    ('biBitCount', W.WORD), ('biCompression', W.DWORD), ('biSizeImage', W.DWORD),
                    ('biXPelsPerMeter', W.LONG), ('biYPelsPerMeter', W.LONG), ('biClrUsed', W.DWORD),
                    ('biClrImportant', W.DWORD)]
    bi = BITMAPINFOHEADER()
    bi.biSize = ctypes.sizeof(bi)
    bi.biWidth, bi.biHeight, bi.biPlanes, bi.biBitCount = ww, -wh, 1, 32
    buf = ctypes.create_string_buffer(ww * wh * 4)
    g32.GetDIBits(mdc, bmp, 0, wh, buf, ctypes.byref(bi), 0)
    g32.DeleteObject(bmp)
    g32.DeleteDC(mdc)
    u32.ReleaseDC(h, hdc)

    ox, oy = cx - wx + x, cy - wy + y
    rows = []
    for row in range(oy, oy + hh):
        line = bytearray()
        for col in range(ox, ox + w):
            i = (row * ww + col) * 4
            line += bytes((buf.raw[i + 2], buf.raw[i + 1], buf.raw[i]))
        rows.append(bytes(line))
    return rows


def stable_capture(h, x, y, w, hh):
    """capture_client, repeated until two captures 0.3 s apart agree: a single capture once
    came back blank for a control that was drawn, apparently while the form was repainting."""
    rows = capture_client(h, x, y, w, hh)
    for _ in range(8):
        time.sleep(0.3)
        again = capture_client(h, x, y, w, hh)
        if again == rows:
            break
        rows = again
    return rows


# ---------------------------------------------------------------- EasyUO process

class EasyUO:
    def __init__(self, exe, script):
        env = dict(os.environ, __COMPAT_LAYER='RunAsInvoker')
        self.proc = subprocess.Popen([exe, script], cwd=os.path.dirname(exe), env=env)
        self.started = False
        self.dialogs = []
        self.foreign = set()   # forms of the other tabs' parsers, present before Start

    def windows(self):
        return top_windows(self.proc.pid)

    def forms(self):
        return [h for h in self.windows() if cls(h) == 'TForm' and h not in self.foreign]

    def main(self):
        for h in self.windows():
            if cls(h) == 'TMainForm':
                return h

    def dismiss_dialogs(self):
        for h in self.windows():
            if cls(h) in DIALOG_CLASSES and visible(h):
                kids = direct_children(h)
                if self.started:
                    self.dialogs.append({'caption': text(h), 'texts': [text(k) for k in kids if text(k)]})
                for k in kids:
                    if cls(k) in ('TButton', 'Button'):
                        u32.PostMessageW(k, BM_CLICK, 0, 0)
                        break
                time.sleep(0.2)

    def ready(self, timeout=20):
        t0 = time.time()
        while time.time() - t0 < timeout:
            self.dismiss_dialogs()
            m = self.main()
            if m and text(m) and not any(cls(h) in DIALOG_CLASSES and visible(h) for h in self.windows()):
                time.sleep(1.0)
                return
            time.sleep(0.2)
        raise RuntimeError('EasyUO did not come up')

    def command(self, cid):
        u32.PostMessageW(self.main(), WM_COMMAND, cid, 0)

    def find_report(self, tag, not_hwnd=None):
        for h in self.forms():
            s = text(h) or ''
            if s.startswith('R:' + tag + ':') and h != not_hwnd:
                return s[len(tag) + 3:], h
        return None, None

    def find_form(self, prefix):
        for h in self.forms():
            if (text(h) or '').startswith(prefix):
                return h

    def find_button(self, caption):
        def walk(h):
            for c in direct_children(h):
                if 'Btn' in cls(c) or cls(c) == 'TButton':
                    if text(c) == caption:
                        return c
                found = walk(c)
                if found:
                    return found
        for f in self.forms():
            b = walk(f)
            if b:
                return b

    def kill(self):
        try:
            self.proc.kill()
            self.proc.wait(5)
        except Exception:
            pass


# ---------------------------------------------------------------- probes

def report_values(report):
    """The report split into its KEY=value parts, for reading the fixture; the tests compare
    the whole report."""
    return re.split(r'_(?=[A-Z][A-Z0-9]*=)', report)


def probe_steps(script):
    steps = []
    for line in script.splitlines():
        line = line.strip()
        if line.startswith(';@'):
            steps.append(line[2:].split())
    return steps


def run_probe(exe_dir, name, log):
    src = os.path.join(FIXTURES, name + '.euo')
    with open(src, encoding='ascii') as f:
        script = f.read()
    path = os.path.join(exe_dir, name + '.txt')
    with open(path, 'w', encoding='ascii', newline='\r\n') as f:
        f.write(script)

    e = EasyUO(os.path.join(exe_dir, 'easyuo.exe'), path)
    events = []
    last = {}
    try:
        e.ready()
        e.foreign = set(e.forms())
        e.started = True
        e.command(CMD_START)
        for step in probe_steps(script):
            kind, args = step[0], step[1:]
            ev = {'step': kind}
            if args:
                ev['args'] = args
            if kind in ('wait', 'rewait'):
                tag = args[0]
                limit = float(args[1]) if len(args) > 1 else 20.0
                t0 = time.time()
                report, h = None, None
                while time.time() - t0 < limit:
                    e.dismiss_dialogs()
                    report, h = e.find_report(tag, last.get(tag) if kind == 'rewait' else None)
                    if report is not None:
                        break
                    time.sleep(0.1)
                if report is None:
                    ev['timeout'] = True
                else:
                    last[tag] = h
                    ev['report'] = report
                    ev['values'] = report_values(report)
                log('  %s %s -> %s' % (kind, tag, 'TIMEOUT' if report is None else report[:150]))
            elif kind == 'click':
                b = e.find_button(' '.join(args))
                ev['found'] = bool(b)
                if b:
                    u32.PostMessageW(b, BM_CLICK, 0, 0)
                log('  click %s%s' % (' '.join(args), '' if b else ' (NOT FOUND)'))
            elif kind == 'close':
                f = e.find_form(' '.join(args))
                ev['found'] = bool(f)
                if f:
                    u32.PostMessageW(f, WM_CLOSE, 0, 0)
                log('  close %s%s' % (' '.join(args), '' if f else ' (NOT FOUND)'))
            elif kind == 'forms':
                time.sleep(0.3)
                ev['forms'] = sorted((describe_form(f) for f in e.forms()),
                                     key=lambda d: (d['caption'] or '', d['left'], d['top']))
                log('  forms: %d' % len(ev['forms']))
            elif kind == 'snap':
                prefix, pic = args[0], args[1]
                x, y, w, hh = (int(v) for v in args[2:6])
                f = e.find_form(prefix)
                ev['found'] = bool(f)
                if f:
                    file = '%s.%s.png' % (name, pic)
                    png(os.path.join(FIXTURES, file), w, hh, stable_capture(f, x, y, w, hh))
                    ev['file'] = file
                log('  snap %s%s' % (pic, '' if f else ' (FORM NOT FOUND)'))
            elif kind == 'alpha':
                f = e.find_form(' '.join(args))
                ev['found'] = bool(f)
                if f:
                    ex = u32.GetWindowLongW(f, GWL_EXSTYLE) & 0xFFFFFFFF
                    ev['layered'] = bool(ex & WS_EX_LAYERED)
                    key, a, flags = W.DWORD(), ctypes.c_ubyte(), W.DWORD()
                    if ev['layered'] and u32.GetLayeredWindowAttributes(f, ctypes.byref(key), ctypes.byref(a),
                                                                        ctypes.byref(flags)):
                        ev['alpha'] = a.value if flags.value & LWA_ALPHA else None
                log('  alpha -> %s' % ev.get('alpha'))
            elif kind == 'stop':
                e.command(CMD_STOP)
            elif kind == 'start':
                e.command(CMD_START)
            elif kind == 'sleep':
                time.sleep(float(args[0]))
            else:
                raise ValueError('%s: unknown step ;@%s' % (name, kind))
            events.append(ev)
        time.sleep(0.3)
        e.dismiss_dialogs()
    finally:
        e.kill()
        time.sleep(0.5)

    out = {'probe': name, 'events': events}
    if e.dialogs:
        out['dialogs'] = e.dialogs
        log('  dialogs: %s' % e.dialogs)
    with open(os.path.join(FIXTURES, name + '.json'), 'w', encoding='ascii', newline='\n') as f:
        json.dump(out, f, indent=1)
        f.write('\n')


# ---------------------------------------------------------------- environment

def system_dpi():
    try:
        return u32.GetDpiForSystem()
    except AttributeError:
        return None


REG_KEY = r'Software\EasyUO'


def registry_values():
    try:
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_KEY)
    except FileNotFoundError:
        return None
    values = {}
    with k:
        i = 0
        while True:
            try:
                name, data, kind = winreg.EnumValue(k, i)
            except OSError:
                break
            values[name] = (data, kind)
            i += 1
    return values


def restore_registry(before, log):
    after = registry_values()
    if after is None:
        return
    if before is None:
        winreg.DeleteKey(winreg.HKEY_CURRENT_USER, REG_KEY)
        log('registry: removed %s, which the run created' % REG_KEY)
        return
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_KEY, 0, winreg.KEY_SET_VALUE) as k:
        for name in after:
            if name not in before:
                winreg.DeleteValue(k, name)
                log('registry: removed %s' % name)
        for name, (data, kind) in before.items():
            if after.get(name) != (data, kind):
                winreg.SetValueEx(k, name, 0, kind, data)
                log('registry: restored %s' % name)


def reforged_running():
    out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq EasyUOReforged.exe', '/NH'],
                         capture_output=True, text=True).stdout
    return 'EasyUOReforged.exe' in out


def main():
    ap = argparse.ArgumentParser(description='Record EasyUO 1.6 MENU golden values.')
    ap.add_argument('-Exe', '--exe', required=True, help='the closed EasyUO 1.6 easyuo.exe')
    ap.add_argument('probes', nargs='*', help='probe names (default: all in tests/fixtures/menu16)')
    a = ap.parse_args()

    if not os.path.isfile(a.exe):
        sys.exit('EasyUO 1.6 not found: %s' % a.exe)
    if reforged_running():
        sys.exit('Close EasyUO Reforged first: it shares HKCU\\%s with EasyUO 1.6.' % REG_KEY)
    names = a.probes or sorted(os.path.splitext(f)[0] for f in os.listdir(FIXTURES) if f.endswith('.euo'))
    for n in names:
        if not os.path.isfile(os.path.join(FIXTURES, n + '.euo')):
            sys.exit('No such probe: %s' % n)

    with open(a.exe, 'rb') as f:
        exe_bytes = f.read()
    manifest = {
        'recorder': RECORDER_VERSION,
        'exe': {'name': os.path.basename(a.exe), 'size': len(exe_bytes),
                'sha256': hashlib.sha256(exe_bytes).hexdigest()},
        'windows': '%d.%d.%d' % sys.getwindowsversion()[:3],
        'dpi': system_dpi(),
        'date': datetime.date.today().isoformat(),
    }
    print('%s %s, Windows %s, %s dpi' % (manifest['exe']['name'], manifest['exe']['sha256'][:16],
                                        manifest['windows'], manifest['dpi']))

    before = registry_values()
    work = tempfile.mkdtemp(prefix='euo16-')
    failed = []
    try:
        shutil.copy2(a.exe, os.path.join(work, 'easyuo.exe'))
        shutil.copy2(os.path.join(FIXTURES, 'golden.bmp'), os.path.join(work, 'golden.bmp'))
        for n in names:
            print('== ' + n, flush=True)
            try:
                run_probe(work, n, lambda s: print(s, flush=True))
            except Exception as ex:
                failed.append(n)
                print('  FAILED: %s' % ex, flush=True)
    finally:
        restore_registry(before, print)
        shutil.rmtree(work, ignore_errors=True)

    # recording.json lists every probe recorded with this binary, including earlier runs.
    path = os.path.join(FIXTURES, 'recording.json')
    if os.path.isfile(path):
        with open(path, encoding='ascii') as f:
            old = json.load(f)
        if old.get('exe', {}).get('sha256') == manifest['exe']['sha256']:
            names = sorted(set(old.get('probes', [])) | set(names))
    manifest['probes'] = sorted(set(names) - set(failed))
    with open(path, 'w', encoding='ascii', newline='\n') as f:
        json.dump(manifest, f, indent=1)
        f.write('\n')
    if failed:
        sys.exit('Failed: ' + ', '.join(failed))


if __name__ == '__main__':
    main()
