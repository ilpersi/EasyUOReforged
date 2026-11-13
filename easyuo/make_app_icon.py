#!/usr/bin/env python3
"""Writes the application icon: easyuo/appicon.ico, easyuo/appicon.res and easyuo/appicondata.pas, and the
documentation site's website/public/favicon.ico and website/src/assets/icon.png.

The icon is this project's own, in the style of the ArtCraft suite's: the emblem of the original EasyUO icon
with a gear for its ring (automation) and a run button in its hole, engraved in black and cream on a green
tile. The .res gives the executables their icon (and the taskbar's), appicondata.pas gives the windows
theirs, the favicon is its small sizes, icon.png the site's home page: all come from here, so they can't
differ.

    python easyuo/make_app_icon.py [--lazarus DIR] [--png FILE]

DIR defaults to $LAZARUS_DIR, else D:\\Program Files\\Lazarus or C:\\Lazarus: fpcres comes from there.
--png also saves the 1024 px drawing. Needs Pillow; takes a few seconds, as the engraving is worked out
pixel by pixel.
"""

import argparse
import glob
import io
import math
import os
import struct
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools', 'EUOMenuDesigner'))
from make_icons import lazarus_dir, pascal_string   # noqa: E402

ICO = os.path.join(HERE, 'appicon.ico')
PAS = os.path.join(HERE, 'appicondata.pas')
FAVICON = os.path.join(HERE, '..', 'website', 'public', 'favicon.ico')
FAVICON_SIZES = (16, 32, 48)
SITE_PNG = os.path.join(HERE, '..', 'website', 'src', 'assets', 'icon.png')   # the home page's hero image
SITE_PNG_SIZE = 512

N = 1024                                # the drawing's canvas; every size above 24 is scaled down from it
SS = 4                                  # shapes are drawn this many times larger, then averaged down
TILE = (0x21, 0xA3, 0x5C)
INK = (0x14, 0x14, 0x14)
PAPER = (0xFF, 0xF4, 0xD6)
CX, CY, R, INNER = 512, 610, 230, 0.58  # the emblem: centre of the gear, ring radius, hole as a part of it
SIZES = (16, 20, 24, 32, 40, 48, 64, 256)


def shade(c, f):
    return tuple(round(v * (1 + f)) if f < 0 else round(v + (255 - v) * f) for v in c)


# ---- shapes ----------------------------------------------------------------------------------
def cubic(p0, p1, p2, p3, n=48):
    out = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        out.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return out


def at(x, y):
    """A point of the emblem, in ring radii from the gear's centre."""
    return (CX + x * R, CY + y * R)


def horns():
    """The original's horns: out from the ring, up, and cut flat at the tips with a beak inwards."""
    out = []
    for s in (-1, 1):
        a, b = at(s * 0.80, -0.60), at(s * 0.64, -1.82)
        pts = [a] + cubic(a, at(s * 1.04, -0.92), at(s * 1.10, -1.55), at(s * 0.97, -2.0))
        pts += [at(s * 0.40, -2.02), b] + cubic(b, at(s * 0.80, -1.40), at(s * 0.62, -1.08), at(s * 0.07, -1.0))
        pts.append(at(0, -0.75))
        out.append(pts)
    return out


def gear(r=232, h=40, teeth=14):
    """The ring as a gear: teeth half as wide as their pitch, flanks slanted a little."""
    pts = []
    for i in range(teeth * 4 + 1):
        k = i % 4
        a = (math.pi / 28 + (i // 4 + (0, 0.25, 0.75, 1)[k]) / teeth * 2 * math.pi
             + (0.12 / teeth if k == 1 else -0.12 / teeth if k == 2 else 0))
        rr = r + h if k in (1, 2) else r
        pts.append((CX + math.cos(a) * rr, CY + math.sin(a) * rr))
    return pts


def circle(r, n=360):
    return [(CX + math.cos(i / n * 2 * math.pi) * r, CY + math.sin(i / n * 2 * math.pi) * r) for i in range(n)]


DIAMOND = [at(0, -1.16), at(0.10, -0.98), at(0, -0.80), at(-0.10, -0.98)]
RUN = [(472, CY - 66), (590, CY), (472, CY + 66)]


def braid():
    """Two strands crossing round the band, like the original's knotwork."""
    return [[(CX + math.cos(a) * R * (0.79 + s * 0.07 * math.sin(16 * a)),
              CY + math.sin(a) * R * (0.79 + s * 0.07 * math.sin(16 * a)))
             for a in (i / 900 * 2 * math.pi for i in range(901))] for s in (1, -1)]


# ---- masks: drawn SS times larger, averaged down, so every edge is smooth ----------------------
def big():
    return Image.new('L', (N * SS, N * SS), 0)


def scaled(pts):
    return [(x * SS, y * SS) for x, y in pts]


def fill(*polys, holes=()):
    im = big()
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon(scaled(p), fill=255)
    for p in holes:
        d.polygon(scaled(p), fill=0)
    return im.reduce(SS)


def stroke(polys, width, closed=True):
    """A line of `width` centred on each outline, round at every corner."""
    im = big()
    d = ImageDraw.Draw(im)
    w = width * SS
    for p in polys:
        q = scaled(p) + (scaled(p[:1]) if closed else [])
        d.line(q, fill=255, width=round(w), joint='curve')
        for x, y in q:
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
    return im.reduce(SS)


def tile_masks():
    im = big()
    ImageDraw.Draw(im).rounded_rectangle([14 * SS, 14 * SS, 1010 * SS - 1, 1010 * SS - 1], 220 * SS, fill=255)
    tile = im.reduce(SS)
    im = big()
    ImageDraw.Draw(im).rounded_rectangle([19 * SS, 19 * SS, 1005 * SS - 1, 1005 * SS - 1], 215 * SS, fill=255)
    return tile, ImageChops.subtract(tile, im.reduce(SS))


def rays(tile):
    lines = []
    for i in range(40):
        a = i / 40 * 2 * math.pi
        r1 = 450 if i % 2 else 560
        lines.append(((CX + math.cos(a) * 330, CY - 60 + math.sin(a) * 330),
                      (CX + math.cos(a) * r1, CY - 60 + math.sin(a) * r1), 4 if i % 2 else 8))
    im = big()
    d = ImageDraw.Draw(im)
    for p0, p1, w in lines:
        d.line(scaled([p0, p1]), fill=255, width=w * SS)
        for x, y in scaled([p0, p1]):
            d.ellipse([x - w * SS / 2, y - w * SS / 2, x + w * SS / 2, y + w * SS / 2], fill=255)
    return ImageChops.multiply(im.reduce(SS), tile)


def paint(im, colour, mask):
    layer = Image.new('RGBA', (N, N), colour + (255,))
    layer.putalpha(mask)
    im.alpha_composite(layer)


def blurred(mask, radius):
    return mask.filter(ImageFilter.GaussianBlur(radius)).tobytes()


# ---- engraving -------------------------------------------------------------------------------
# Lines run along the iso-lines of flow(x, y), `period` px apart, as thick as tone(x, y) is dark (0 to 1).
# Past `cross`, a second set of lines (flow2) cross-hatches; past `cross2`, a third.
def wob(v, x, y, a):
    """A hand-cut wobble."""
    return v + a * math.sin(x * 0.047 + y * 0.029) + a * 0.6 * math.sin(y * 0.083 - x * 0.021)


def lin(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return lambda x, y: x * c + y * s


def ramp(v, v0, v1, a0, a1):
    t = min(1.0, max(0.0, (v - v0) / (v1 - v0)))
    return a0 + (a1 - a0) * t


def engrave(im, mask, tone, flow, period, flow2=None, cross=1.0, flow3=None, cross2=1.0):
    m = mask.tobytes()
    x0, y0, x1, y1 = mask.getbbox()
    out = bytearray(N * N * 4)
    p2 = period * 0.9
    for y in range(y0, y1):
        for x in range(x0, x1):
            a = m[y * N + x]
            if not a:
                continue
            t = min(1.0, max(0.0, tone(x, y)))
            cov = 0.0
            if t >= 0.04:
                f = flow(x, y) / period
                cov = t * period * 0.5 - abs(f - math.floor(f + 0.5)) * period + 0.5
                for fl, c in ((flow2, cross), (flow3, cross2)):
                    if fl and t > c:
                        f = fl(x, y) / p2
                        cov = max(cov, (t - c) / (1 - c) * p2 * 0.42 - abs(f - math.floor(f + 0.5)) * p2 + 0.5)
                cov = min(1.0, max(0.0, cov))
            i = (y * N + x) * 4
            out[i:i + 4] = bytes((round(PAPER[0] + (INK[0] - PAPER[0]) * cov),
                                  round(PAPER[1] + (INK[1] - PAPER[1]) * cov),
                                  round(PAPER[2] + (INK[2] - PAPER[2]) * cov), a))
    im.alpha_composite(Image.frombytes('RGBA', (N, N), bytes(out)))


def drawing():
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    tile, rim = tile_masks()
    paint(im, TILE, tile)
    paint(im, shade(TILE, 0.24), rays(tile))

    # the horns, behind the gear: bright metal lit from the top left, lines along their length
    hs = horns()
    paint(im, INK, stroke(hs, 18))
    edge = blurred(stroke(hs, 22), 12)
    engrave(im, fill(*hs),
            lambda x, y: (ramp(math.hypot(x - (CX - 0.5 * R), y - (CY - 1.6 * R)), 0.2 * R, 2.6 * R, 0, 0.5)
                          + ramp(x, CX - 1.2 * R, CX + 1.2 * R, 0, 0.22) + 0.35 * edge[y * N + x] / 255),
            lambda x, y: wob(math.atan2(y - CY, x - CX) * R * 1.4, x, y, 1.5), 10, flow2=lin(40), cross=0.55)

    # the gear: steel, lines round its centre, a bevel into the hole, the horns' shadow on its top
    g, hole = gear(), circle(R * INNER)
    paint(im, INK, stroke([g], 18))
    soft = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(soft)
    r = R * INNER + 8 + 13
    d.arc([CX - r, CY - r, CX + r, CY + r], 162, 315, fill=255, width=26)
    bevel = blurred(soft, 10)
    soft = Image.new('L', (N, N), 0)
    ImageDraw.Draw(soft).ellipse([CX - 261, CY - 261, CX + 261, CY + 261], outline=255, width=18)
    flank = ImageChops.multiply(soft.filter(ImageFilter.GaussianBlur(6)), fill(g)).tobytes()
    soft = Image.new('L', (N, N), 0)
    ImageDraw.Draw(soft).ellipse([CX - 0.75 * R, CY - 1.11 * R, CX + 0.75 * R, CY - 0.79 * R], fill=255)
    shadow = blurred(soft, 18)
    xh1, xh2 = lin(-38), lin(38)
    engrave(im, fill(g, holes=[hole]),
            lambda x, y: (ramp(math.hypot(x - (CX - 0.55 * R), y - (CY - 0.6 * R)), 0.1 * R, 2.1 * R, 0.06, 0.68)
                          + (0.45 * bevel[y * N + x] + 0.25 * flank[y * N + x] + 0.35 * shadow[y * N + x]) / 255),
            lambda x, y: wob(math.hypot(x - CX, y - CY), x, y, 1.2), 10,
            flow2=lambda x, y: wob(xh1(x, y), x, y, 1.2), cross=0.58,
            flow3=lambda x, y: wob(xh2(x, y), x, y, 1.2), cross2=0.82)
    paint(im, INK, stroke(braid(), 6, closed=False))
    paint(im, INK, stroke([circle(R * 0.66), circle(R * 0.92)], 5))
    paint(im, INK, stroke([hole], 14))

    paint(im, INK, stroke([DIAMOND], 16))
    engrave(im, fill(DIAMOND), lambda x, y: ramp(x, CX - 30, CX + 30, 0.1, 0.7), lambda x, y: y, 8)

    # the run button: bright, shaded towards its lower edge
    paint(im, INK, stroke([RUN], 26))
    engrave(im, fill(RUN), lambda x, y: ramp(y, CY - 66, CY + 66, 0, 0.75), lambda x, y: wob(y, x, y, 0.8), 9)

    paint(im, shade(TILE, -0.28), rim)
    return im


# Scaled down this far, the engraving is a grey smudge, so these sizes are placed by hand: K ink, P the
# lit metal, M the shaded metal, on the tile. The hole shows the tile; the run button is P.
PIXELS = {
    16: ['................',
         '...KKK....KKK...',
         '...KPPK..KPMK...',
         '..KPPK....KPMK..',
         '..KPPK....KPMK..',
         '..KPPKKKKKKPMK..',
         '...KKPPPPPPKK...',
         '...KPPPKKPPMK...',
         '..KPPPKP.KMMMK..',
         '.KKPPPKPPKMMMKK.',
         '..KPPPKP.KMMMK..',
         '...KPPPKKMMMK...',
         '....KPPMMMMK....',
         '.....KKKKKK.....',
         '.....K.KK.K.....',
         '................'],
    20: ['....................',
         '....................',
         '.....KKK....KKK.....',
         '.....KPPK..KPMK.....',
         '....KPPK....KPMK....',
         '....KPPK....KPMK....',
         '....KPPK....KPMK....',
         '....KPPKKKKKKPMK....',
         '.....KKPPPPPPKK.....',
         '....KPPPPKKPPPMK....',
         '....KPPPKP.KPMMK....',
         '...KKPPPKPPKMMMKK...',
         '...KKPPPKPPKMMMKK...',
         '....KPPPKP.KMMMK....',
         '....KPPPPKKMMMMK....',
         '.....KPPMMMMMMK.....',
         '......KKKKKKKK......',
         '.......K.KK.K.......',
         '....................',
         '....................'],
    24: ['........................',
         '........................',
         '......KKKK....KKKK......',
         '......KPPPK..KPPMK......',
         '......KPPK....KPMK......',
         '.....KPPK......KPMK.....',
         '.....KPPK......KPMK.....',
         '.....KPPK......KPMK.....',
         '.....KPPPK....KPPMK.....',
         '......KPPKKKKKKPMK......',
         '......KKPPPPPPPPKK......',
         '.......KPPKKKKPPK.......',
         '......KKPKKP.KKMKK......',
         '......KPPK.PP.KMMK......',
         '......KPPK.PP.KMMK......',
         '......KKPKKP.KKMKK......',
         '.......KPPKKKKMMK.......',
         '......KKKPMMMMMKKK......',
         '.........KKMMKK.........',
         '.........K.KK.K.........',
         '...........KK...........',
         '........................',
         '........................',
         '........................'],
}
PALETTE = {'K': INK, 'P': (0xF4, 0xEA, 0xCC), 'M': (0xA8, 0xA1, 0x8E)}


def tile_only():
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    tile, rim = tile_masks()
    paint(im, TILE, tile)
    paint(im, shade(TILE, -0.28), rim)
    return im


def render(s, master):
    if s not in PIXELS:
        im = master.resize((s, s), Image.LANCZOS)
        if s < 256:     # the engraving greys out when scaled this far: sharpen it, not the tile's edge
            r, g, b, a = im.split()
            rgb = Image.merge('RGB', (r, g, b)).filter(ImageFilter.UnsharpMask(1, 45 if s <= 40 else 30, 0))
            im = Image.merge('RGBA', (*rgb.split(), a))
        return im
    im = tile_only().resize((s, s), Image.LANCZOS)
    for y, row in enumerate(PIXELS[s]):
        for x, c in enumerate(row):
            if c != '.':
                im.putpixel((x, y), PALETTE[c] + (255,))
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


def ico(master, sizes=SIZES):
    """Bitmaps up to 64 px, a PNG at 256: LCL's TIcon only reads a PNG in the 256 slot."""
    images = []
    for s in sizes:
        im = render(s, master)
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
    ap.add_argument('--png', help='also save the 1024 px drawing here')
    args = ap.parse_args()
    laz = lazarus_dir(args.lazarus)

    master = drawing()
    if args.png:
        master.save(args.png)
    data = ico(master)
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

    fav = ico(master, FAVICON_SIZES)
    with open(FAVICON, 'wb') as f:
        f.write(fav)
    print('wrote', os.path.normpath(FAVICON), len(fav), 'bytes,', len(FAVICON_SIZES), 'sizes')

    master.resize((SITE_PNG_SIZE, SITE_PNG_SIZE), Image.LANCZOS).save(SITE_PNG, 'PNG', optimize=True)
    print('wrote', os.path.normpath(SITE_PNG), os.path.getsize(SITE_PNG), 'bytes')


if __name__ == '__main__':
    main()
