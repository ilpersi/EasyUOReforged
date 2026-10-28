---
title: "menu Image File"
description: "Draws a picture file into an image."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Image File {name} {x} {y} {file}"
related: ["menu Image Create", "#CurPath"]
aliases: ["load picture", "png", "bmp"]
source: wiki
---

`menu Image File` loads a picture file and draws it into an image, with its top-left corner at `x`, `y`.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Name of an image created with [`menu Image Create`](/commands/menu/image/create/). |
| `x`, `y` | Where to draw it. Positions are inside the image, `0, 0` being its top-left corner. |
| `file` | The picture. BMP, PNG, JPEG and GIF work; transparency in the file is kept. |

When the file does not exist, nothing happens. A relative path starts from the folder EasyUO Reforged runs
in, which is not always [`#CurPath`](/variables/curpath/): give a full path, or build one with `#CurPath`.

## Reforged notes

Older formats the original accepted, such as WMF, EMF and ICO, may not load.

## Example

```euo
menu Image Create logo 10 10 100 50
menu Image File logo 0 0 #CurPath , images\logo.png
```
