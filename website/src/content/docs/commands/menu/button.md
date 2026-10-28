---
title: "menu Button"
description: "Places a button in the menu window; a click puts its name in #MenuButton."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Button {name} {x} {y} {width} {height} {text}"
related: ["#MenuButton", "menu Set"]
source: wiki
---

`menu Button` places a button in the menu window. Clicking it puts the button's name in
[`#MenuButton`](/variables/menubutton/).

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. This is what `#MenuButton` holds after a click, in capital letters. |
| `x`, `y` | Position of the top-left corner. |
| `width`, `height` | Size in pixels. |
| `text` | The caption on the button. |

It uses the current [font settings](/commands/menu/#fonts).

## Waiting for a click

`#MenuButton` keeps the last click until something else is clicked, so clear it before you wait. Comparisons
ignore case, so `ok` matches `OK`:

```euo
menu Button ok 10 70 60 25 OK
menu Button cancel 80 70 60 25 Cancel
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
if #MenuButton = cancel || #MenuButton = closed
  halt
```

Change the caption later with [`menu Set`](/commands/menu/set/).

## 1.5 and 1.6

- **1.5:** a click puts the button's name in [`#MenuButton`](/variables/menubutton/) in capitals (`OK`).
- **1.6:** the name is in lower case (`ok`); `=` ignores case, so `if #MenuButton = ok` works in both. The
  button goes into the current [default parent](/commands/menu/setdef/), and a second button created with a
  name already taken appears but does nothing when clicked. See
  [MENU: EasyUO 1.5 and 1.6](/commands/menu/versions/#names).
