---
title: "menu GetDef"
description: "Reads one of the defaults new menu controls are created with into #MenuRes."
kind: subcommand
category: menu
syntax: "menu GetDef {key}"
menuLogic: ['1.6']
sets: ["#MenuRes"]
related: ["menu SetDef", "menu PushDef", "menu PopDef", "menu GetProp"]
aliases: ["default", "defaults"]
credits: ['scriptuo']
---

New controls take their font, colours, alignment and parent from a set of defaults. `menu GetDef` puts one
of them into [`#MenuRes`](/variables/menures/); [`menu SetDef`](/commands/menu/setdef/) changes them.

## Keys

| Key | What it is | Set too by |
|---|---|---|
| `alignment` | 0 left, 1 right, 2 centre | [`menu Font Align`](/commands/menu/font/align/) |
| `color` | Background colour | [`menu Font BgColor`](/commands/menu/font/bgcolor/) |
| `fontcolor` | Text colour | [`menu Font Color`](/commands/menu/font/color/) |
| `fontname` | Font | [`menu Font Name`](/commands/menu/font/name/) |
| `fontsize` | Font size in points | [`menu Font Size`](/commands/menu/font/size/) |
| `fontstyle` | Sum of 1 bold, 2 italic, 4 underline, 8 strike-out | [`menu Font Style`](/commands/menu/font/style/) |
| `parent` | Name of the window or panel new controls go into | [`menu Form`](/commands/menu/form/), [`menu Panel`](/commands/menu/panel/) |

When a script starts, and after [`menu Clear`](/commands/menu/clear/), they are Arial 10, plain, black text
on the standard button colour (`-16777201`), aligned left, in `form0`, the main window.

## Example

```euo
menu GetDef fontname
set %font #MenuRes
menu GetDef fontsize
display ok New controls use %font #MenuRes
halt
```

## Notes

- `parent` after the default window or panel was deleted gives the last text any
  [`menu GetProp`](/commands/menu/getprop/) or `menu GetDef` returned: the default parent is then none, and
  new controls do not appear until `menu SetDef parent` names one.
