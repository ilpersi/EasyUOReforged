---
title: "menu Image FloodFill"
description: "Applies the FloodFill effect in the area around a specified pixel within a specified image."
kind: subcommand
category: menu
syntax: "menu Image FloodFill {name} {x} {y} {color}"
source: wiki
---

The [menu Image FloodFill](/commands/menu/image/floodfill/) command applies the FloodFill effect in the area around the pixel x/y within the specified image. The effect will only spread as far as the pixel colors do not change.

For the color parameter, you can use names like "red", "yellow" or "windowtext" or use a hexadecimal number like $AABBCC (BBGGRR encoded). $FEEEED is used for transparency.
