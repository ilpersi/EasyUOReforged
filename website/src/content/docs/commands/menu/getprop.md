---
title: "menu GetProp"
description: "Reads a property of a menu control or window, such as its position, text or colour, into #MenuRes."
kind: subcommand
category: menu
syntax: "menu GetProp {name} {property}"
menuLogic: ['1.6']
sets: ["#MenuRes"]
related: ["menu SetProp", "menu GetDef", "menu Get"]
aliases: ["property", "read property"]
credits: ['scriptuo']
---

`menu GetProp` puts one property of a control, or of a window made by [`menu Form`](/commands/menu/form/)
(the main window is `form0`), into [`#MenuRes`](/variables/menures/).
[`menu SetProp`](/commands/menu/setprop/) changes them.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control or window. |
| `property` | One of the properties below; not case-sensitive. |

Text comes back as it is, numbers in decimal, and yes/no as `-1` / `0`. When the control or the property
does not exist, `#MenuRes` is left as it was.

## Properties

| Property | What it is | Kind | Controls |
|---|---|---|---|
| `alignment` | Text alignment: 0 left, 1 right, 2 centre | number | text, check, radio |
| `checked` | Checked or not | yes/no | check, radio |
| `color` | Background colour | number | all but image |
| `enabled` | Can be used | yes/no | all |
| `fontcolor` | Text colour | number | all but form, panel, image |
| `fontname` | Font | text | all but form, panel, image |
| `fontsize` | Font size in points | number | all but form, panel, image |
| `fontstyle` | Sum of 1 bold, 2 italic, 4 underline, 8 strike-out | number | all but form, panel, image |
| `height`, `width` | Size; for a form, of its inside | number | all |
| `left`, `top` | Position, inside the parent (on the screen for a form) | number | all |
| `parent` | Name of the window or panel it is in | text | all but form |
| `text` | The label, caption or title; an edit's contents | text | form, text, button, edit, check, radio |
| `tooltip` | The hint shown when the mouse rests on it | text | all |
| `visible` | Shown or hidden | yes/no | all |

Colours are numbers in Windows' order, `$BBGGRR`. System colours come back as negative numbers:
the standard button colour, `btnface`, is `-16777201`.

## Example

```euo
menu Reforge Mode 1.6
menu Edit name 10 10 120 Bob
menu GetProp name width
set %w #MenuRes
menu GetProp name text
display ok The field is %w pixels wide and says #MenuRes
```

## Notes

These are quirks of EasyUO 1.6, kept as they are:

- A check box's `alignment` reads 0 when its text is on the right and 1 when it is on the left; a radio
  button's the other way round.
- `parent` of a control whose window or panel has no name (one created with a name already taken) gives
  the last text any `menu GetProp` or [`menu GetDef`](/commands/menu/getdef/) returned, not an empty value.
