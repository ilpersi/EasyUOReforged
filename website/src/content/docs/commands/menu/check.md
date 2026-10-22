---
title: "menu Check"
description: "Places a check box in the menu window."
kind: subcommand
category: menu
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
menu Check loot 10 10 120 20 #false Loot corpses
; later
menu Get loot
if #MenuRes = #true
  gosub loot
```
