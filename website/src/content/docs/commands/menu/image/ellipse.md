---
title: "menu Image Ellipse"
description: "Draws an ellipse or circle in an image, outlined or filled."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Image Ellipse {name} {x1} {y1} {x2} {y2} {colour} {fill} [width]"
related: ["menu Image Rectangle", "menu Image Create"]
aliases: ["circle"]
source: wiki
---

`menu Image Ellipse` draws the ellipse that fits in the rectangle with corners `x1`, `y1` and `x2`, `y2`; a
square gives a circle. Positions are inside the image, `0, 0` being its top-left corner.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name of an image created with [`menu Image Create`](/commands/menu/image/create/). |
| `x1`, `y1`, `x2`, `y2` | Two opposite corners of the box around the ellipse. |
| `colour` | A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number. |
| `fill` | `#true` (any number other than 0) fills it with the same colour; `#false` (0) draws only the outline. |
| `width` | Optional outline width in pixels. Default: 1. |

`$FEEEED` is the transparent colour of images: painting with it makes those pixels see-through.

## Example

```euo
menu Clear
menu Window Size 84 84
menu Image Create pic 10 10 64 64
menu Image Ellipse pic 8 8 56 56 yellow #true
menu Image Ellipse pic 20 20 44 44 red #false 3
menu Show
halt
```

## 1.5 and 1.6

- **1.6:** a negative second corner (`x2`, `y2`) is refused.
