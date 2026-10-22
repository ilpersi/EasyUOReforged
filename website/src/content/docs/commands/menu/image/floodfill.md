---
title: "menu Image FloodFill"
description: "Fills an area of one colour in an image with another, like a paint bucket."
kind: subcommand
category: menu
syntax: "menu Image FloodFill {name} {x} {y} {colour}"
related: ["menu Image Ellipse", "menu Image Rectangle"]
aliases: ["paint bucket", "fill"]
source: wiki
---

`menu Image FloodFill` works like the paint bucket of a drawing program: starting at `x`, `y`, it fills the
connected area that has the same colour as that pixel with the new colour. Positions are inside the image, `0, 0` being its top-left corner.

A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number. `$FEEEED` is the transparent colour of images: painting with it makes those pixels see-through.

## Example

```euo
menu Image Ellipse pic 8 8 56 56 black #false
menu Image FloodFill pic 32 32 green      ; fill the inside of the circle
```
