---
title: "menu Image Line"
description: "Draws a line in an image."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Image Line {name} {x1} {y1} {x2} {y2} {colour} [width]"
related: ["menu Image Rectangle", "menu Image Create"]
source: wiki
---

`menu Image Line` draws a straight line from `x1`, `y1` to `x2`, `y2` in an image. Positions are inside the image, `0, 0` being its top-left corner.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name of an image created with [`menu Image Create`](/commands/menu/image/create/). |
| `x1`, `y1`, `x2`, `y2` | The two ends. |
| `colour` | A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number. |
| `width` | Optional line width in pixels. Default: 1. |

## Example

```euo
menu Image Line pic 0 0 63 63 red 2
```

## 1.5 and 1.6

- **1.6:** a negative second corner (`x2`, `y2`) is refused.
- An invalid line width draws a 1-pixel line in 1.6 and nothing in 1.5.
