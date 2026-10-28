---
title: "menu Image Pix"
description: "Paints one pixel of an image."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Image Pix {name} {x} {y} {colour}"
related: ["menu Image PixLine", "menu Image Create"]
source: wiki
---

`menu Image Pix` paints the pixel at `x`, `y` of an image. Positions are inside the image, `0, 0` being its top-left corner.

A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number. `$FEEEED` is the transparent colour of images: painting with it makes those pixels see-through.

For more than a few pixels, [`menu Image PixLine`](/commands/menu/image/pixline/) is much faster.

## Example

```euo
menu Image Pix pic 10 10 red
```
