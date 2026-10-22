---
title: "menu Image PixLine"
description: "Prints a horizontal line of pixels within a specified image."
kind: subcommand
category: menu
syntax: "menu Image PixLine {name} {x} {y} {data}"
source: wiki
---

The [menu Image PixLine](/commands/menu/image/pixline/) command prints a horizontal line of pixels starting at position x/y within the specified image. "data" is encoded as follows:

Each pixel has an RGB value that is defined by three consecutive characters in the data string. Valid characters are A-Z, 1-6 and 9. These characters specify the intensity of each color (RGB) whereas A=0, B=8, C=16 ... Z=200, 1=208 ... 6=248 and 9=transparent.

Examples: AAA = black, 666 = white (equals $F8F8F8), 6AA = red (equals $0000F8) AAAPPP666999AAP = black,gray,white,transparent,navy (=5 pixels).

You can create interesting effects by using partial transparency like in 9A9 which only removes the green intensity from the overpainted pixel. Transparency only works for the specified image, i.e. other images below or above do not have any influence.

:::note
- This command is only available from EUO 1.5.
- Do not overuse this feature. Small images (also called Sprites) are okay, but we don't want 200KB scripts just because you like to have a nice background. Use external JPG or GIF images instead. Very advanced scripters may also consider creating their own image compression format and converting it into a data string at the initial script run. Resulting strings can be stored in persistent variables for future access.
:::
