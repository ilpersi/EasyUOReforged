---
title: Components
description: "Each kind of control the MENU Designer has, the line that creates it, and what EasyUO 1.6 does differently with it."
sidebar:
  order: 4
---

One section per kind of control in the palette. Each is created by one line, then given what that line
cannot carry (see [The inspector](/designer/inspector/#what-each-property-becomes)).

## Form

A window. [`menu Form`](/commands/menu/form/) creates it hidden, and EasyUO 1.6 makes its inside 10 pixels
larger than asked each way, so the designer then sets the exact size with `menu SetProp`. `form0`, the main
window, exists from the start: its sub sets it with [`menu Window`](/commands/menu/window/title/) lines and
shows it with [`menu Show`](/commands/menu/show/). See [Several forms](/designer/forms/).

## Panel

An area that groups controls: [`menu Panel`](/commands/menu/panel/). It takes the default colour when it is
created, has no border, and is often the colour of its form, so the canvas draws a thin frame around
it. Radio buttons in different panels belong to different groups.

## Text

A label: [`menu Text`](/commands/menu/text/). It fits itself to its words, and `$` in its text is a line
break. A right-aligned text keeps its right edge when it fits itself, so its creating line would put its
right edge at `x`: the designer places it with `menu SetProp ... left` instead. A text can have a fixed
size.

## Button

[`menu Button`](/commands/menu/button/). A click puts its name in [`#MenuButton`](/variables/menubutton/).
`$` in its text stays a `$`.

## Edit

A one-line text field: [`menu Edit`](/commands/menu/edit/). Its creating line has no height: the height
comes from the font, unless you fix it.

## Memo

A text field of several lines: [`menu Memo`](/commands/menu/memo/). It is a Reforged addition: real EasyUO
1.6 ignores the line, so a script with a memo shows it only in EasyUO Reforged. The palette marks it
*Reforged only*.

## Check

A check box: [`menu Check`](/commands/menu/check/). **Text side** puts the text left or right of the box.
EasyUO 1.6 swaps the default alignment for check boxes (right puts the text on the left), and the designer
writes what gives the side you chose.

## Radio

A radio button: [`menu Radio`](/commands/menu/radio/). Radio buttons in the same form or panel are one
group: checking one unchecks the others, in the designer as in the script.

## Combo

A drop-down list: [`menu Combo Create`](/commands/menu/combo/), then one `add` per item and a `select`.
Its height comes from the font unless you fix it.

## List

A list box: [`menu List Create`](/commands/menu/list/), then `add` and `select`.

## Image

A picture: [`menu Image Create`](/commands/menu/image/create/) and the drawing lines (`line`, `ellipse`,
`rectangle`, `pix`, `floodfill`, `file`). **Stretched** shows the picture at another size with
[`menu Image Pos`](/commands/menu/image/pos/). A `file` drawing needs the file name as one word without
spaces; the canvas shows the picture when it finds the file.

## Shape

A rectangle, a circle or an ellipse: [`menu Shape`](/commands/menu/shape/), which EasyUO 1.6 draws as an
image. The circle (1), the square (5) and *nothing* (6) are kept square: 1.6 would shrink the longer side.
The line is solid or absent and the fill solid or absent; 1.6 has no dashed lines, hatched fills or rounded
corners.
