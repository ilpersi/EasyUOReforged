---
title: "menu Image PixLine"
description: "Paints a row of pixels of an image from a compact text code."
kind: subcommand
category: menu
syntax: "menu Image PixLine {name} {x} {y} {data}"
related: ["menu Image Pix", "menu Image File"]
aliases: ["sprite"]
source: wiki
---

`menu Image PixLine` paints a row of pixels, starting at `x`, `y` and going right. Positions are inside the image, `0, 0` being its top-left corner. It is the fast
way to draw small pictures pixel by pixel.

## The data

Each pixel is **three characters**: red, green and blue, in that order. Each character is one of:

| Character | Value |
|---|---|
| `A` … `Z` | 0, 8, 16, … 200 |
| `1` … `6` | 208, 216, … 248 |
| `9` | Leave this colour of the pixel as it is. |
| `8` | Transparent. Use `888` for a fully transparent pixel. |

So `AAA` is black, `666` white, `6AA` red, `PPP` grey and `AAP` navy: `AAAPPP666AAP` paints four pixels.
`9A9` keeps a pixel's red and blue but removes its green. On a new image every pixel is transparent, so
`999` leaves it transparent.

The whole row has to fit in the image, or nothing is painted. Any other character stops the command at that pixel.

Keep pictures painted this way small. For anything bigger, load a file with
[`menu Image File`](/commands/menu/image/file/).

## Example

```euo
; a 4-pixel black, grey, white, navy row
menu Image PixLine pic 0 0 AAAPPP666AAP
```
