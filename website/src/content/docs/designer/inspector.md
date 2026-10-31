---
title: The inspector
description: "The MENU Designer's property inspector: every property of a component, and the script line it becomes."
sidebar:
  order: 3
---

The inspector lists the properties of the first selected component. Type a new value and press **Enter**,
or leave the cell, to apply it. A value the script cannot take is refused, and the status bar says why. A
row drawn in red has a warning in *Messages*: see [Texts that cannot be written](#texts-that-cannot-be-written).

The rows a component has are the properties EasyUO 1.6 gives its kind (the table behind
[`menu GetProp`](/commands/menu/getprop/)), plus the values only its creating line can set. They are in
alphabetical order.

## Values

- **Yes / no** for on and off.
- **Colours:** a name, such as `Red` or `BtnFace` (the system's button colour), or a number, `$BBGGRR` or
  decimal as in [`menu Font Color`](/commands/menu/font/color/). The **…** button opens a colour picker.
- **Font style:** any of `bold`, `italic`, `underline`, `strikeout`, or `plain`. The **…** button opens a font
  dialog that sets the font, its size, style and colour together.
- **Text with several lines** (a text or a memo) shows each line break as `¶`; the **…** button edits it as
  lines.

## What each property becomes

The script sets most values through the defaults a control is created with, and the rest after it is
created:

| Property | In the script |
|---|---|
| Name | the control's name on every line |
| Left, Top, Width, Height | the creating line; a fixed size of a text or an edit: [`menu SetProp`](/commands/menu/setprop/) `width` / `height` |
| Text | the creating line; a form's title: [`menu Form`](/commands/menu/form/) or [`menu Window Title`](/commands/menu/window/title/) |
| Font, Font size, Font style, Font colour, Colour, Alignment / Text side | before the creating line: [`menu Font Name`](/commands/menu/font/name/), [`menu Font Color`](/commands/menu/font/color/) and [`menu Font BgColor`](/commands/menu/font/bgcolor/) (colours by name where there is one), and [`menu SetDef`](/commands/menu/setdef/) for the size, style and alignment |
| Checked | the creating line of a check box or a radio button |
| Tooltip, Enabled, Visible | `menu SetProp` after the creating line |
| Parent | which form or panel the control is created in ([`menu SetDef parent`](/commands/menu/setdef/)) |
| Items, Selected | [`menu Combo`](/commands/menu/combo/) or [`menu List`](/commands/menu/list/) `add` and `select` |
| Shape, Line, Fill and their colours | the [`menu Shape`](/commands/menu/shape/) line |
| Drawing, Stretched | [`menu Image`](/commands/menu/image/create/) drawing lines and [`menu Image Pos`](/commands/menu/image/pos/) |
| Transparency (form0) | [`menu Window Transparent`](/commands/menu/window/transparent/) |

## Sizes a control gives itself

A text fits itself to its words, and an edit's and a combo box's height comes from their font. Their rows
show the size the script will produce, and a **Width fixed** / **Height fixed** row. Set a size, or drag a
handle on the canvas, and it becomes fixed: the script sets it with `menu SetProp` after creating the
control. Set **fixed** back to `no` to let the control fit itself again.

## Forms

A form has a **Title**, its position on the screen (**Left**, **Top**), the size of its inside (**Width**,
**Height**), **Colour**, **Shown** (whether the script shows it), **Enabled** and **Tooltip**. `form0` also
has **Transparency**: `none`, or 0 (most see-through) to 100.

## Items and drawings

- **Items** (combo box, list): the **…** button edits them one per line. **Selected** is the number of the
  selected item, 1 for the first, 0 for none.
- **Drawing** (image): the **…** button edits the drawing as lines, in the order they are drawn, each as
  [`menu Image`](/commands/menu/image/line/) writes it after the image's name:

  ```text
  rectangle 0 0 40 20 Red 1 1
  line 0 0 39 19 Blue 2
  pix 5 5 Black
  file 0 0 C:\pictures\logo.bmp
  ```

  `ellipse` and `rectangle` take two corners, not a width and a height, then the colour, `1` to fill, and
  the pen width.

## Texts that cannot be written

A line of script is split into words before it runs, and some texts do not survive that: two spaces in a
row, a word that starts with `%`, `#`, `!` or `*` (a variable), a word that starts with `;` (a comment),
a lone `.` or `,` (they join the words around them). In a text or a memo, a `$` is a line break.

Such a text gets a warning in *Messages*, its row turns red, and the file gets the text without the parts
that would change, so the script shows what the canvas shows. A text label that needs a real `$` gets it
from `menu SetProp ... text`, which does not turn `$` into a line break.
