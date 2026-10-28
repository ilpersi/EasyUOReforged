---
title: "menu Show"
description: "Shows the menu window, optionally at a position on the screen."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Show [x y]"
related: ["menu Hide", "menu HideEUO"]
source: wiki
---

`menu Show` shows the menu window. With `x` and `y`, it first moves the window so that its top-left corner is
at that position on the screen.

[`menu Hide`](/commands/menu/hide/) hides it again.

## Example

```euo
menu Show 200 150
```

## 1.5 and 1.6

- **1.6:** also puts the window on top of the others. It does nothing after
  [`menu Delete form0`](/commands/menu/delete/). Show another window with
  [`menu SetProp`](/commands/menu/setprop/) `{name} visible #true`.
