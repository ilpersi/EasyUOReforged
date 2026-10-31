#!/usr/bin/env python3
"""Writes tools/EUOMenuDesigner/mdicons.pas: the MENU Designer's icons, as base64 PNGs.

The icons come from a Lazarus install's images folder, from the sets its copyright.txt and
general_purpose/lazarus_general_purpose_images.txt give as made by Roland Hahn under CC0 1.0
(no restrictions): general_purpose (the 16x16 outline set, for the menu and the toolbar),
designer (z-order) and components (the 24x24 component palette icons, for the palette). The sets
have nothing for Select all or for the Arrange commands' alignment and sizes: those are drawn
here, in the outline set's colour and line width, and are this project's own.

    python tools/EUOMenuDesigner/make_icons.py [--lazarus DIR]

DIR defaults to $LAZARUS_DIR, else D:\\Program Files\\Lazarus or C:\\Lazarus. Needs Pillow.
"""

import argparse
import base64
import io
import os
import sys

from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'mdicons.pas')

C = (0x00, 0xAA, 0xD4, 255)   # the outline set's colour


def lazarus_dir(arg):
    for d in (arg, os.environ.get('LAZARUS_DIR'), r'D:\Program Files\Lazarus', r'C:\Lazarus'):
        if d and os.path.isfile(os.path.join(d, 'images', 'copyright.txt')):
            return d
    sys.exit('Lazarus not found: pass --lazarus DIR')


# ---------------------------------------------------------------------------------------------
# Drawn icons, 16x16, 1-pixel lines.

def blank():
    return Image.new('RGBA', (16, 16), (0, 0, 0, 0))


def box(d, x0, y0, x1, y1):
    d.rectangle([x0, y0, x1, y1], outline=C)


def dashed_v(im, x, y0, y1):
    for y in range(y0, y1 + 1, 2):
        im.putpixel((x, y), C)


def dashed_h(im, y, x0, x1):
    for x in range(x0, x1 + 1, 2):
        im.putpixel((x, y), C)


def transpose(im):
    return im.transpose(Image.Transpose.TRANSPOSE)


def align_left():
    im = blank(); d = ImageDraw.Draw(im)
    d.line([(1, 1), (1, 14)], fill=C)
    box(d, 3, 2, 13, 6)
    box(d, 3, 9, 9, 13)
    return im


def centre_across():
    im = blank(); d = ImageDraw.Draw(im)
    box(d, 2, 2, 12, 6)
    box(d, 4, 9, 10, 13)
    dashed_v(im, 7, 0, 15)
    return im


def parent_across():
    im = blank(); d = ImageDraw.Draw(im)
    box(d, 0, 0, 14, 14)
    box(d, 4, 3, 10, 7)
    dashed_v(im, 7, 9, 13)
    return im


def spread_across():
    im = blank(); d = ImageDraw.Draw(im)
    box(d, 1, 5, 3, 10)
    box(d, 6, 3, 8, 12)
    box(d, 11, 6, 13, 9)
    return im


def same_width():
    im = blank(); d = ImageDraw.Draw(im)
    box(d, 2, 1, 13, 5)
    box(d, 2, 9, 13, 13)
    d.line([(3, 7), (12, 7)], fill=C)
    for x, y in ((4, 6), (4, 8), (11, 6), (11, 8)):
        im.putpixel((x, y), C)
    return im


def same_size():
    im = blank(); d = ImageDraw.Draw(im)
    box(d, 1, 1, 14, 14)
    d.line([(4, 11), (11, 4)], fill=C)
    for x, y in ((9, 4), (10, 4), (11, 5), (11, 6), (4, 9), (4, 10), (5, 11), (6, 11)):
        im.putpixel((x, y), C)
    return im


def select_all():
    im = blank(); d = ImageDraw.Draw(im)
    dashed_h(im, 0, 0, 15)
    dashed_h(im, 15, 1, 15)
    dashed_v(im, 0, 0, 15)
    dashed_v(im, 15, 1, 15)
    box(d, 3, 3, 7, 7)
    box(d, 8, 8, 12, 12)
    return im


# ---------------------------------------------------------------------------------------------
# Icons taken from the sets, and icons made from them.

class Source:
    def __init__(self, laz):
        self.img = os.path.join(laz, 'images')

    def gp(self, name):
        return os.path.join(self.img, 'general_purpose', name + '_16.png')

    def raw(self, path):
        with open(path, 'rb') as f:
            return f.read()

    def image(self, path):
        return Image.open(path).convert('RGBA')


def with_badge(base, badge):
    """The badge over the base, the base cleared around the badge so the two stay apart."""
    out = base.copy()
    for y in range(16):
        for x in range(16):
            near = any(badge.getpixel((u, v))[3] > 128
                       for u in range(max(0, x - 1), min(15, x + 1) + 1)
                       for v in range(max(0, y - 1), min(15, y + 1) + 1))
            if near:
                out.putpixel((x, y), (0, 0, 0, 0))
    out.alpha_composite(badge)
    return out


def png(im):
    buf = io.BytesIO()
    im.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


# The menu and toolbar icons, in TMdIcon order: (identifier, where it comes from, PNG bytes).
def menu_icons(s):
    gp = lambda n: (s.raw(s.gp(n)), 'general_purpose ' + n + '_16')
    drawn = lambda im, what: (png(im), 'drawn: ' + what)
    window = s.image(s.gp('Window_02'))
    icons = [
        ('NewDesign',  gp('Add_01')),
        ('Open',       gp('Folder_01')),
        ('Save',       gp('Save_03')),
        ('SaveAs',     gp('SaveAs_02')),
        ('Paste',      gp('Paste_02')),
        ('Exit',       gp('Exit_02')),
        ('Undo',       gp('Undo_02')),
        ('Redo',       (png(ImageOps.mirror(s.image(s.gp('Undo_02'))))
                        , 'general_purpose Undo_02_16, mirrored')),
        ('Delete',     gp('Delete_03')),
        ('SelectAll',  drawn(select_all(), 'a dashed frame round two boxes')),
        ('NewForm',    (png(with_badge(window, s.image(s.gp('ovl_Plus_06')))),
                        'general_purpose Window_02_16 with ovl_Plus_06_16')),
        ('DeleteForm', (png(with_badge(window, s.image(s.gp('ovl_Close_03')))),
                        'general_purpose Window_02_16 with ovl_Close_03_16')),
        ('MoveLeft',   gp('Arrow_02')),
        ('MoveRight',  gp('Arrow_01')),
        ('AlignLeft',  drawn(align_left(), 'left edges')),
        ('AlignRight', drawn(ImageOps.mirror(align_left()), 'right edges')),
        ('AlignTop',   drawn(transpose(align_left()), 'top edges')),
        ('AlignBottom', drawn(ImageOps.flip(transpose(align_left())), 'bottom edges')),
        ('CentreH',    drawn(centre_across(), 'centres across')),
        ('CentreV',    drawn(transpose(centre_across()), 'centres down')),
        ('ParentH',    drawn(parent_across(), 'centre in parent across')),
        ('ParentV',    drawn(transpose(parent_across()), 'centre in parent down')),
        ('SpreadH',    drawn(spread_across(), 'spread across')),
        ('SpreadV',    drawn(transpose(spread_across()), 'spread down')),
        ('SameWidth',  drawn(same_width(), 'same width')),
        ('SameHeight', drawn(transpose(same_width()), 'same height')),
        ('SameSize',   drawn(same_size(), 'same size')),
        ('Front',      (s.raw(os.path.join(s.img, 'designer', 'order_move_front.png')),
                        'designer order_move_front')),
        ('Back',       (s.raw(os.path.join(s.img, 'designer', 'order_move_back.png')),
                        'designer order_move_back')),
        ('GridSize',   gp('Grid_13')),
        ('Preview',    gp('Eye_01')),
        ('Help',       gp('Help_03')),
        ('About',      gp('Info_01')),
    ]
    return [(n, data, what) for n, (data, what) in icons]


# The palette's glyphs, in TMdType order ('' for form, which is not on the palette).
PALETTE = [('form', None), ('panel', 'tpanel'), ('text', 'tlabel'), ('button', 'tbutton'),
           ('edit', 'tedit'), ('memo', 'tmemo'), ('check', 'tcheckbox'),
           ('radio', 'tradiobutton'), ('combo', 'tcombobox'), ('list', 'tlistbox'),
           ('image', 'timage'), ('shape', 'tshape')]


# ---------------------------------------------------------------------------------------------
def pascal_string(data, indent):
    b = base64.b64encode(data).decode('ascii')
    parts = [b[i:i + 76] for i in range(0, len(b), 76)] or ['']
    return (' +\n' + indent).join("'" + p + "'" for p in parts)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--lazarus')
    s = Source(lazarus_dir(ap.parse_args().lazarus))
    icons = menu_icons(s)

    L = []
    L.append('unit mdicons;')
    L.append('')
    L.append('{')
    L.append('  Port addition: the MENU Designer\'s icons, written by make_icons.py (in this folder) from a')
    L.append('  Lazarus install\'s images: do not edit by hand, run it again. Those icons are by Roland Hahn,')
    L.append('  CC0 1.0 (no restrictions), as Lazarus\' images/copyright.txt and')
    L.append('  images/general_purpose/lazarus_general_purpose_images.txt say: the 16x16 outline set')
    L.append('  (general_purpose) for the menu and the toolbar, the component palette icons (components, 24x24)')
    L.append('  for the palette. The sets have none for Select all or for the Arrange commands: make_icons.py')
    L.append('  draws those in the outline set\'s colour. Base64 in the source, as easyuo\\mainicons.pas does,')
    L.append('  so the executable needs no other file.')
    L.append('')
    for n, _, what in icons:
        L.append('    %-11s %s' % (n, what))
    L.append('}')
    L.append('')
    L.append('{$mode delphi}{$H+}')
    L.append('')
    L.append('interface')
    L.append('')
    L.append('uses')
    L.append('  Graphics, Controls, mdtypes;')
    L.append('')
    L.append('type')
    names = ['ic' + n for n, _, _ in icons]
    line = '  TMdIcon = ('
    out = []
    for i, n in enumerate(names):
        piece = n + (', ' if i < len(names) - 1 else ');')
        if len(line) + len(piece) > 100:
            out.append(line.rstrip())
            line = '             '
        line += piece
    out.append(line)
    L.extend(out)
    L.append('')
    L.append('// The menu and toolbar icons, 16x16, in TMdIcon order, into an empty image list.')
    L.append('procedure LoadMdIcons(AList : TImageList);')
    L.append('// A palette button\'s glyph, 24x24: the Lazarus component icon of the type\'s control (nil for')
    L.append('// a form, which is not on the palette). The caller frees it.')
    L.append('function  PaletteGlyph(T : TMdType) : TBitmap;')
    L.append('')
    L.append('implementation')
    L.append('')
    L.append('uses')
    L.append('  mainicons;')
    L.append('')
    L.append('const')
    L.append('  Icons : array[TMdIcon] of String = (')
    for i, (n, data, _) in enumerate(icons):
        L.append('    // ic' + n)
        L.append('    ' + pascal_string(data, '    ') + (',' if i < len(icons) - 1 else ');'))
    L.append('')
    L.append('  Glyphs : array[TMdType] of String = (')
    for i, (t, comp) in enumerate(PALETTE):
        data = s.raw(os.path.join(s.img, 'components', comp + '.png')) if comp else b''
        L.append('    // ' + t + (' (' + comp + ')' if comp else ': not on the palette'))
        L.append('    ' + (pascal_string(data, '    ') if data else "''") +
                 (',' if i < len(PALETTE) - 1 else ');'))
    L.append('')
    L.append('////////////////////////////////////////////////////////////////////////////////')
    L.append('procedure LoadMdIcons(AList : TImageList);')
    L.append('var')
    L.append('  I   : TMdIcon;')
    L.append('  Bmp : TBitmap;')
    L.append('begin')
    L.append('  AList.Width:=16;')
    L.append('  AList.Height:=16;')
    L.append('  for I:=Low(TMdIcon) to High(TMdIcon) do')
    L.append('  begin')
    L.append('    Bmp:=LoadPNGBitmap(Icons[I]);')
    L.append('    try')
    L.append('      AList.Add(Bmp,nil);')
    L.append('    finally')
    L.append('      Bmp.Free;')
    L.append('    end;')
    L.append('  end;')
    L.append('end;')
    L.append('')
    L.append('function PaletteGlyph(T : TMdType) : TBitmap;')
    L.append('begin')
    L.append("  if Glyphs[T]='' then Result:=nil else Result:=LoadPNGBitmap(Glyphs[T]);")
    L.append('end;')
    L.append('')
    L.append('end.')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L) + '\n')
    print('wrote', OUT, len(icons), 'icons')


if __name__ == '__main__':
    main()
