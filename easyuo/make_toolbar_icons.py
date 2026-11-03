#!/usr/bin/env python3
"""Writes easyuo/mainiconsdata.pas: the main window's toolbar and menu icons, as base64 PNGs.

The style is the MENU Designer's (tools/EUOMenuDesigner/make_icons.py, whose helpers are used here):
Lazarus' general_purpose outline set by Roland Hahn, CC0 1.0, as Lazarus' images/copyright.txt and
general_purpose/lazarus_general_purpose_images.txt say. The run controls are recoloured to the set's
own green, orange and red, so a script's state can be read at a glance. The set has nothing for
Reopen, Save All, Stop All, Swap Client or Website: those are drawn here in the set's colour and line
width, and are this project's own.

    python easyuo/make_toolbar_icons.py [--lazarus DIR]

DIR defaults to $LAZARUS_DIR, else D:\\Program Files\\Lazarus or C:\\Lazarus. Needs Pillow.
"""

import argparse
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools', 'EUOMenuDesigner'))
from make_icons import C, Source, lazarus_dir, pascal_string, png, with_badge   # noqa: E402

OUT = os.path.join(HERE, 'mainiconsdata.pas')

GREEN = (0x01, 0xA9, 0x01)    # the set's own signal colours (Add_09, Time_08, Cancel_05)
ORANGE = (0xFF, 0x7F, 0x00)
RED = (0xFA, 0x03, 0x02)
SS = 8                        # the rings are drawn this much bigger, then box-filtered down


# ---------------------------------------------------------------------------------------------
# Drawn icons, 16x16.

def recolour(im, rgb):
    out = Image.new('RGBA', im.size, rgb + (255,))
    out.putalpha(im.getchannel('A'))
    return out


def smooth(paint):
    """paint(draw, s) on a big mask, 255 draws and 0 clears; antialiased down like the set's rings."""
    mask = Image.new('L', (16 * SS, 16 * SS), 0)
    paint(ImageDraw.Draw(mask), SS)
    out = Image.new('RGBA', (16, 16), C)
    out.putalpha(mask.resize((16, 16), Image.BOX))
    return out


def ring(d, s, cx, cy, r, w=1.2):
    d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=255)
    d.ellipse([(cx - r + w) * s, (cy - r + w) * s, (cx + r - w) * s, (cy + r - w) * s], fill=0)


def website():
    """A globe."""
    def paint(d, s):
        ring(d, s, 8, 8, 7.4)
        d.ellipse([4.6 * s, 0.6 * s, 11.4 * s, 15.4 * s], outline=255, width=int(1.1 * s))
        d.rectangle([1 * s, 7.45 * s, 15 * s, 8.55 * s], fill=255)
    return smooth(paint)


def stop_all():
    """Stop_01's ring and square, with a second ring behind it."""
    def paint(d, s):
        ring(d, s, 10.2, 5.8, 5.4)
        d.ellipse([-0.4 * s, 3.4 * s, 12.6 * s, 16.4 * s], fill=0)
        ring(d, s, 6.1, 9.9, 5.6)
        d.rectangle([4.1 * s, 7.9 * s, 8.1 * s, 11.9 * s], fill=255)
    return smooth(paint)


def clock_badge():
    def paint(d, s):
        ring(d, s, 11.5, 11.5, 4.4, 1.1)
        d.rectangle([11 * s, 9 * s, 12 * s, 12 * s], fill=255)
        d.rectangle([11 * s, 11 * s, 13.5 * s, 12 * s], fill=255)
    return smooth(paint)


def save_all():
    """A floppy like Save_03's, with the corner of a second one behind it."""
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(3, 0), (15, 0), (15, 12)], fill=C)
    d.line([(0, 3), (10, 3), (12, 5), (12, 15), (0, 15), (0, 3)], fill=C)
    d.rectangle([3, 3, 8, 6], outline=C)
    d.rectangle([3, 10, 9, 15], outline=C)
    return im


def swap_client(window):
    """Two opposite arrows in a client window."""
    im = window.copy()
    pixels = [(x, y) for x in range(3, 13) for y in (6, 11)]
    pixels += [(11, 5), (11, 7), (10, 4), (10, 8), (4, 10), (4, 12), (5, 9), (5, 13)]
    for p in pixels:
        im.putpixel(p, C)
    return im


# ---------------------------------------------------------------------------------------------
# The icons, in the ImageIndex order mainicons.pas's TagToImageIndex uses:
# (identifier, where it comes from, PNG bytes).
def toolbar_icons(s):
    gp = lambda n: (s.raw(s.gp(n)), 'general_purpose ' + n + '_16')
    drawn = lambda im, what: (png(im), 'drawn: ' + what)
    tinted = lambda n, rgb, colour: (png(recolour(s.image(s.gp(n)), rgb)),
                                     'general_purpose ' + n + '_16, ' + colour)
    window = s.image(s.gp('Window_02'))
    icons = [
        ('New',        gp('Add_01')),
        ('Open',       gp('Folder_01')),
        ('Save',       gp('Save_03')),
        ('Cut',        gp('Cut_02')),
        ('Copy',       gp('Copy_02')),
        ('Paste',      gp('Paste_02')),
        ('Find',       gp('Search_03')),
        ('Replace',    gp('Replace_03')),
        ('Start',      tinted('Play_01', GREEN, 'green')),
        ('Pause',      tinted('Pause_01', ORANGE, 'orange')),
        ('Stop',       tinted('Stop_01', RED, 'red')),
        ('StopAll',    (png(recolour(stop_all(), RED)), 'drawn: two stop rings, red')),
        ('Help',       gp('Help_03')),
        ('Website',    drawn(website(), 'a globe')),
        ('Reopen',     (png(with_badge(s.image(s.gp('Folder_01')), clock_badge())),
                        'general_purpose Folder_01_16 with a drawn clock')),
        ('SaveAll',    drawn(save_all(), 'a floppy with a second one behind it')),
        ('Close',      gp('Remove_02')),
        ('NewClient',  (png(with_badge(window, s.image(s.gp('ovl_Plus_06')))),
                        'general_purpose Window_02_16 with ovl_Plus_06_16')),
        ('SwapClient', (png(swap_client(window)), 'general_purpose Window_02_16 with drawn arrows')),
        ('Format',     gp('Align_05')),
    ]
    return [(n, data, what) for n, (data, what) in icons]


# ---------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--lazarus')
    icons = toolbar_icons(Source(lazarus_dir(ap.parse_args().lazarus)))

    L = []
    L.append('unit mainiconsdata;')
    L.append('')
    L.append('{')
    L.append('  Port addition: the main window\'s toolbar and menu icons, written by make_toolbar_icons.py (in')
    L.append('  this folder): do not edit by hand, run it again. They are in the MENU Designer\'s style, from')
    L.append('  Lazarus\' 16x16 outline set (general_purpose) by Roland Hahn, CC0 1.0 (no restrictions), as')
    L.append('  Lazarus\' images/copyright.txt and images/general_purpose/lazarus_general_purpose_images.txt')
    L.append('  say. The script draws what the set does not have. In ImageIndex order, see mainicons.pas.')
    L.append('')
    for i, (n, _, what) in enumerate(icons):
        L.append('    %2d %-10s %s' % (i, n, what))
    L.append('}')
    L.append('')
    L.append('{$mode delphi}{$H+}')
    L.append('')
    L.append('interface')
    L.append('')
    L.append('const')
    L.append('  ToolbarIcons : array[0..%d] of String = (' % (len(icons) - 1))
    for i, (n, data, _) in enumerate(icons):
        L.append('    // %d %s' % (i, n))
        L.append('    ' + pascal_string(data, '    ') + (',' if i < len(icons) - 1 else ');'))
    L.append('')
    L.append('implementation')
    L.append('')
    L.append('end.')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L) + '\n')
    print('wrote', OUT, len(icons), 'icons')


if __name__ == '__main__':
    main()
