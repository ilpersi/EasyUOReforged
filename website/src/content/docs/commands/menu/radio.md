---
title: "menu Radio"
description: "Creates a radio button; checking one unchecks the others in the same window or panel."
kind: subcommand
category: menu
syntax: "menu Radio {name} {x} {y} {width} {height} {checked} {text...}"
menuLogic: ['1.6']
related: ["menu Check", "menu Panel", "menu Get", "menu Set"]
aliases: ["option button"]
credits: ['scriptuo']
---

`menu Radio` creates a radio button. Of the radio buttons with the same parent (a window or a
[`menu Panel`](/commands/menu/panel/)), only one is checked at a time.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The button's name. |
| `x`, `y` | Position inside the current [default parent](/commands/menu/setdef/). |
| `width`, `height` | Size in pixels. |
| `checked` | `#true` to check it, `#false` not to. Checking it unchecks the others in the same parent. |
| `text` | The label; the rest of the line. |

## Description

- [`menu Get`](/commands/menu/get/) reads it: `-1` when checked, `0` when not.
  [`menu Set`](/commands/menu/set/) `{name} 1` checks it.
- [`menu GetProp`](/commands/menu/getprop/) / [`menu SetProp`](/commands/menu/setprop/) `{name} checked`
  do the same with `#true` / `#false`.
- The label is on the right, or on the left after [`menu Font Align right`](/commands/menu/font/align/).

## Example

```euo
menu Reforge Mode 1.6
menu Radio easy 10 10 80 20 #true Easy
menu Radio hard 10 35 80 20 #false Hard
menu Button go 10 65 60 25 Go
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Get hard
if #MenuRes = -1
  display ok Hard it is.
```
