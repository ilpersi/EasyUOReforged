---
title: "menu Image Pix"
description: "Paints a single pixel within a specified image."
kind: subcommand
category: menu
syntax: "menu Image Pix {name} {x} {y} {color}"
source: wiki
---

The [menu Image Pix](/commands/menu/image/pix/) command paints a single pixel at x/y within the specified image.

For the color parameter, you can use names like "red", "yellow" or "windowtext" or use a hexadecimal number like $AABBCC (BBGGRR encoded). $FEEEED is used for transparency.

:::note
- This command is only available from EUO 1.5.
- For faster pixel output, use [Menu Image PixLine](/commands/menu/image/pixline/) instead.
:::
