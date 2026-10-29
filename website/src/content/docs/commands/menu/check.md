---
title: "menu Check"
description: "Places a check box in the menu window."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Check {name} {x} {y} {width} {height} {checked} {text}"
related: ["menu Get", "menu Set"]
aliases: ["checkbox"]
source: wiki
---

`menu Check` places a check box with a caption.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. |
| `x`, `y` | Position of the top-left corner. |
| `width`, `height` | Size of the box and caption together. A caption that does not fit is cut off. |
| `checked` | `#true` (or any number other than 0) to start checked, `#false` (0) to start unchecked. |
| `text` | The caption, to the right of the box; with [`menu Font Align`](/commands/menu/font/align/) `right`, to the left. |

It uses the current [font settings](/commands/menu/#fonts). [`menu Get`](/commands/menu/get/) returns `#true` (`-1`) when it is checked and `#false` (`0`) when it
is not; [`menu Set`](/commands/menu/set/) with `#true` or `#false` changes it.

## Example

```euo
menu Clear
menu Window Size 180 80
menu Check loot 10 10 120 20 #false Loot corpses
menu Button ok 10 45 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Get loot
if #MenuRes = #true
  display ok Looting.
else
  display ok Not looting.
halt
```

## 1.5 and 1.6

- **1.6:** the check box goes into the current [default parent](/commands/menu/setdef/), and its name must be
  free: a second one with a taken name appears but cannot be read or changed. Its properties can be read and
  changed with [`menu GetProp`](/commands/menu/getprop/) and [`menu SetProp`](/commands/menu/setprop/).
  [`menu Radio`](/commands/menu/radio/) makes radio buttons.
