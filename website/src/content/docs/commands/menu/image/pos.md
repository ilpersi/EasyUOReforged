---
title: "menu Image Pos"
description: "Moves an image, and optionally resizes it, stretching what is drawn in it."
kind: subcommand
category: menu
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
menu Image Pos pic 100 10 128 128
```
