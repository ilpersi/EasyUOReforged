---
title: "menu Image Pos"
description: "Moves an image, and optionally resizes it, stretching what is drawn in it."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Image Pos {name} {x} {y} [width height]"
related: ["menu Image Create"]
source: wiki
---

`menu Image Pos` moves an image to `x`, `y` in the menu window. With `width` and `height`, it also resizes
it, and what is drawn in it is stretched to fit.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name of an image created with [`menu Image Create`](/commands/menu/image/create/). |
| `x`, `y` | New position of the top-left corner in the window. |
| `width`, `height` | Optional new size. |

## Example

```euo
menu Clear
menu Window Size 250 150
menu Image Create pic 10 10 64 64
menu Image Ellipse pic 8 8 56 56 yellow #true
menu Show
wait 40
menu Image Pos pic 100 10 128 128     ; moved and stretched to twice the size
halt
```

## 1.5 and 1.6

- **1.5:** moves an image, and turns on stretching even when only `x` and `y` are given.
- **1.6:** moves any control, not only images, and stretches an image only when `width` and `height` are
  given; a negative size is refused.
