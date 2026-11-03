#!/usr/bin/env python3
"""Writes the application icon: easyuo/appicon.ico, easyuo/appicon.res and easyuo/appicondata.pas.

The icon is this project's own: the emblem of the original EasyUO icon, redrawn plain and glowing hot
on an anvil, on a tile in the toolbar icons' cyan. The .res gives the executables their icon (and the
taskbar's), appicondata.pas gives the windows theirs, so the two can't differ.

    python easyuo/make_app_icon.py [--lazarus DIR]

DIR defaults to $LAZARUS_DIR, else D:\\Program Files\\Lazarus or C:\\Lazarus: fpcres comes from there.
Needs Pillow.
"""

import argparse
import glob
import io
import os
import struct
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools', 'EUOMenuDesigner'))
from make_icons import lazarus_dir, pascal_string   # noqa: E402

ICO = os.path.join(HERE, 'appicon.ico')
PAS = os.path.join(HERE, 'appicondata.pas')

N = 512                                 # the drawings' canvas; every size is box-filtered down from it
CYAN = (0x00, 0xAA, 0xD4, 255)          # the toolbar icons' colour
HOT = (0xFF, 0xD0, 0x50, 255)
WHITE = (255, 255, 255, 255)
SIZES = (16, 20, 24, 32, 40, 48, 64, 256)

ANVIL = [(70, 170), (442, 170), (442, 214), (400, 262), (334, 278), (312, 330), (360, 382), (360, 424),
         (152, 424), (152, 382), (200, 330), (178, 278), (118, 262), (70, 214)]

# Scaled down this far, the horns close up against the ring, so these sizes are placed by hand:
# H the emblem, W the anvil, on the tile. No spikes: they would only blur.
PIXELS = {
    16: ['................',
         '....H......H....',
         '...HH......HH...',
         '...HH......HH...',
         '....HHH..HHH....',
         '......HHHH......',
         '.....HH..HH.....',
         '.....HH..HH.....',
         '......HHHH......',
         '................',
         '..WWWWWWWWWWWW..',
         '....WWWWWWWW....',
         '......WWWW......',
         '.....WWWWWW.....',
         '....WWWWWWWW....',
         '................'],
    20: ['....................',
         '....................',
         '.....HH......HH.....',
         '....HH........HH....',
         '....HH........HH....',
         '.....HHH....HHH.....',
         '.......HHHHHH.......',
         '......HH....HH......',
         '......HH....HH......',
         '......HH....HH......',
         '.......HHHHHH.......',
         '....................',
         '..WWWWWWWWWWWWWWWW..',
         '...WWWWWWWWWWWWWW...',
         '.....WWWWWWWWWW.....',
         '.......WWWWWW.......',
         '......WWWWWWWW......',
         '.....WWWWWWWWWW.....',
         '....................',
         '....................'],
    24: ['........................',
         '........................',
         '......HH........HH......',
         '.....HH..........HH.....',
         '....HH............HH....',
         '....HH............HH....',
         '.....HHH........HHH.....',
         '.......HHH....HHH.......',
         '........HHHHHHHH........',
         '.......HH......HH.......',
         '.......HH......HH.......',
         '.......HH......HH.......',
         '.......HH......HH.......',
         '........HHHHHHHH........',
         '........................',
         '..WWWWWWWWWWWWWWWWWWWW..',
         '...WWWWWWWWWWWWWWWWWW...',
         '.....WWWWWWWWWWWWWW.....',
         '........WWWWWWWW........',
         '........WWWWWWWW........',
         '.......WWWWWWWWWW.......',
         '......WWWWWWWWWWWW......',
         '........................',
         '........................'],
}


def canvas():
    return Image.new('RGBA', (N, N), (0, 0, 0, 0))


def bezier(p0, p1, p2, p3, n=80):
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        yield (u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
               u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1])


def tile():
    im = canvas()
    ImageDraw.Draw(im).rounded_rectangle([8, 8, N - 8, N - 8], 84, fill=CYAN)
    return im


def emblem():
    """The original icon's shape: a ring with spikes, and two horns curving out and back in at the tips."""
    im = canvas()
    d = ImageDraw.Draw(im)
    centre = N / 2
    scale = 0.50
    place = lambda x, y: (centre + (x - centre) * scale, centre + (y - centre) * scale)
    cx, cy = place(256, 336)
    r = 118 * scale
    w = 54 * scale
    d.ellipse([cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2], outline=HOT, width=int(w))
    for sign in (-1, 1):
        for x, y in bezier((256 + sign * 40, 214), (256 + sign * 150, 190),
                           (256 + sign * 228, 90), (256 + sign * 92, 34)):
            X, Y = place(x, y)
            d.ellipse([X - w / 2, Y - w / 2, X + w / 2, Y + w / 2], fill=HOT)
    s = 40 * scale
    o = r + w / 2 - 4
    for dx, dy in ((-1, 0), (1, 0), (0, 1)):
        tip = (cx + dx * (o + s), cy + dy * (o + s))
        a = (cx + dx * o + dy * s * 0.7, cy + dy * o + dx * s * 0.7)
        b = (cx + dx * o - dy * s * 0.7, cy + dy * o - dx * s * 0.7)
        d.polygon([tip, a, b], fill=HOT)
    shape = im.crop(im.getbbox())
    out = canvas()
    out.alpha_composite(shape, (int(centre - shape.width / 2), 38))
    return out


def drawing():
    im = tile()
    ImageDraw.Draw(im).polygon([(x * 0.86 + 36, y * 0.60 + 190) for x, y in ANVIL], fill=WHITE)
    im.alpha_composite(emblem())
    return im


def render(s):
    if s not in PIXELS:
        return drawing().resize((s, s), Image.BOX)
    im = tile().resize((s, s), Image.BOX)
    for y, row in enumerate(PIXELS[s]):
        for x, c in enumerate(row):
            if c != '.':
                im.putpixel((x, y), HOT if c == 'H' else WHITE)
    return im


# ---------------------------------------------------------------------------------------------
def dib(im):
    """A 32-bit icon image: a BITMAPINFOHEADER of double height, bottom-up BGRA, then the AND mask."""
    w, h = im.size
    head = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    px = im.load()
    colour = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            colour += bytes((b, g, r, a))
    stride = (w + 31) // 32 * 4
    mask = bytearray()
    for y in range(h - 1, -1, -1):
        row = bytearray(stride)
        for x in range(w):
            if px[x, y][3] == 0:
                row[x // 8] |= 0x80 >> (x % 8)
        mask += row
    return head + bytes(colour) + bytes(mask)


def ico():
    """Bitmaps up to 64 px, a PNG at 256: LCL's TIcon only reads a PNG in the 256 slot."""
    images = []
    for s in SIZES:
        im = render(s)
        if s == 256:
            buf = io.BytesIO()
            im.save(buf, 'PNG', optimize=True)
            images.append((s, buf.getvalue()))
        else:
            images.append((s, dib(im)))
    out = struct.pack('<HHH', 0, 1, len(images))
    offset = len(out) + 16 * len(images)
    for s, data in images:
        side = 0 if s == 256 else s
        out += struct.pack('<BBBBHHII', side, side, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    return out + b''.join(data for _, data in images)


def fpcres(laz):
    found = glob.glob(os.path.join(laz, 'fpc', '*', 'bin', '*', 'fpcres.exe'))
    if not found:
        sys.exit('fpcres not found under ' + laz)
    subprocess.run([found[0], 'appicon.rc', '-o', 'appicon.res', '-of', 'res'], cwd=HERE, check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--lazarus')
    laz = lazarus_dir(ap.parse_args().lazarus)

    data = ico()
    with open(ICO, 'wb') as f:
        f.write(data)
    fpcres(laz)

    L = []
    L.append('unit appicondata;')
    L.append('')
    L.append('{')
    L.append('  Port addition: the application icon, as a base64 .ico, written by make_app_icon.py (in this')
    L.append('  folder): do not edit by hand, run it again. It is appicon.ico, which the same script writes')
    L.append('  and links into the executables through appicon.res. Sizes: ' +
             ', '.join(str(s) for s in SIZES) + '.')
    L.append('}')
    L.append('')
    L.append('{$mode delphi}{$H+}')
    L.append('')
    L.append('interface')
    L.append('')
    L.append('const')
    L.append('  AppIconIco : String =')
    L.append('    ' + pascal_string(data, '    ') + ';')
    L.append('')
    L.append('implementation')
    L.append('')
    L.append('end.')
    with open(PAS, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L) + '\n')
    print('wrote', ICO, len(data), 'bytes,', len(SIZES), 'sizes')


if __name__ == '__main__':
    main()
