---
title: "menu Image Rectangle"
description: "Draws a rectangle in an image, outlined or filled."
kind: subcommand
category: menu
syntax: "menu Image Rectangle {name} {x1} {y1} {x2} {y2} {colour} {fill} [width]"
related: ["menu Image Ellipse", "menu Image Create"]
source: wiki
---

`menu Image Rectangle` draws a rectangle with corners `x1`, `y1` and `x2`, `y2` in an image. Positions are inside the image, `0, 0` being its top-left corner.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name of an image created with [`menu Image Create`](/commands/menu/image/create/). |
| `x1`, `y1`, `x2`, `y2` | Two opposite corners. |
| `colour` | A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number. |
| `fill` | `#true` (any number other than 0) fills it with the same colour; `#false` (0) draws only the outline. |
| `width` | Optional outline width in pixels. Default: 1. |

`$FEEEED` is the transparent colour of images: painting with it makes those pixels see-through. A filled rectangle is the usual way to give an image a background.

## Example

```euo
menu Image Rectangle pic 0 0 64 64 white #true
menu Image Rectangle pic 4 4 60 60 black #false 2
```
