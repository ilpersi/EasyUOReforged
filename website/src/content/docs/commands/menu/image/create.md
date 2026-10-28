---
title: "menu Image Create"
description: "Places an empty, transparent image in the menu window to draw in."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Image Create {name} {x} {y} {width} {height}"
related: ["menu Image File", "menu Image Rectangle", "menu Image Pos"]
aliases: ["picture", "canvas"]
source: wiki
---

`menu Image Create` places an image in the menu window: a rectangle you can draw in or load a picture into
with the other `menu Image` commands. It starts completely transparent.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control's name, used later by [`menu Get`](/commands/menu/get/), [`menu Set`](/commands/menu/set/) and [`menu Delete`](/commands/menu/delete/). Case does not matter. |
| `x`, `y` | Position of the top-left corner in the window. |
| `width`, `height` | Size in pixels. |

`$FEEEED` is the transparent colour of images: painting with it makes those pixels see-through.

## Example

```euo
menu Image Create pic 10 10 64 64
menu Image Rectangle pic 0 0 64 64 navy 1
menu Image Ellipse pic 8 8 56 56 yellow 1
```

## 1.5 and 1.6

- **1.6:** a negative width or height is refused. The image goes into the current
  [default parent](/commands/menu/setdef/).
