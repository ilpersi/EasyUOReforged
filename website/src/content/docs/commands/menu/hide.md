---
title: "menu Hide"
description: "Hides the menu window, as if it had been closed."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Hide"
related: ["menu Show", "#MenuButton"]
source: wiki
---

`menu Hide` hides the menu window, the same way its × button does: [`#MenuButton`](/variables/menubutton/)
becomes `CLOSED`, and a main window hidden with [`menu HideEUO`](/commands/menu/hideeuo/) comes back. The
controls stay; [`menu Show`](/commands/menu/show/) shows the window again.

## Example

```euo
menu Clear
menu Text t 10 10 Hiding in two seconds.
menu Show
wait 40
menu Hide
halt
```

## 1.5 and 1.6

- **1.5:** closes the window as its × does: [`#MenuButton`](/variables/menubutton/) becomes `CLOSED`, and
  EasyUO comes back if [`menu HideEUO`](/commands/menu/hideeuo/) minimised it.
- **1.6:** only hides the main window; `#MenuButton` keeps its value. Hide another window with
  [`menu SetProp`](/commands/menu/setprop/) `{name} visible #false`.
