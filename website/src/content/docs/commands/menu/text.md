---
title: "menu Text"
description: "Places a label in the menu window; $ starts a new line."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Text {name} {x} {y} {text}"
related: ["menu Set", "menu Font Name"]
aliases: ["label"]
source: wiki
---

`menu Text` places a label at `x`, `y`. The label is as big as its text. `$` in the text starts a new line.

It uses the current [font settings](/commands/menu/#fonts). [`menu Font Align`](/commands/menu/font/align/) aligns the lines of a multi-line label, and
[`menu Font Transparent`](/commands/menu/font/transparent/) drops its background.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. |
| `x`, `y` | Position of the label's top-left corner. |
| `text` | The text. |

Change the text later with [`menu Set`](/commands/menu/set/); `$` does not start a new line there. A label's
text cannot be read back with `menu Get`.

## Example

```euo
menu Text status 10 10 Waiting...
; later
menu Set status Done
```

## 1.5 and 1.6

- **1.6:** labels always have a background, in the colour set by
  [`menu Font BgColor`](/commands/menu/font/bgcolor/): [`menu Font Transparent`](/commands/menu/font/transparent/)
  is ignored. The label goes into the current [default parent](/commands/menu/setdef/), and its name must
  be free: a second label with a taken name stays on screen but cannot be changed or deleted.
