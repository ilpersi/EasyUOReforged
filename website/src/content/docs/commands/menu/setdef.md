---
title: "menu SetDef"
description: "Changes one of the defaults new menu controls are created with, such as the window or panel they go into."
kind: subcommand
category: menu
syntax: "menu SetDef {key} {value...}"
menuLogic: ['1.6']
related: ["menu GetDef", "menu PushDef", "menu PopDef", "menu SetProp"]
aliases: ["default", "defaults"]
credits: ['scriptuo']
---

`menu SetDef` changes one of the defaults the controls created after it take. The keys are listed on
[`menu GetDef`](/commands/menu/getdef/). Controls that already exist keep what they have; change those with
[`menu SetProp`](/commands/menu/setprop/).

## Description

- `menu SetDef parent {name}` makes new controls go into that window or panel. `form0` is the main window.
- `fontname` takes the rest of the line. The others take one value.
- Numbers must be written as numbers: a colour name such as `red`, or `right` for the alignment, counts as
  0. The [`menu Font`](/commands/menu/font/name/) sub-commands accept names and set the same defaults.

## Example

```euo
menu Reforge Mode 1.6
menu Panel tools 10 10 200 60
menu Button a 5 5 60 25 One
menu SetDef parent form0
menu Button b 10 80 60 25 Two
```

`a` goes into the panel; `b`, after `menu SetDef parent form0`, into the main window.
