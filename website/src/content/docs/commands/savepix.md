---
title: "SavePix"
description: "Saves the color of a pixel in a specified location."
kind: command
category: client
syntax: "savePix {X-coordinate} {Y-coordinate} [number]"
needsClient: true
related: ["cmppix"]
source: wiki
---

The savePix command saves the color value of the pixel given by the coordinate parameters into the memory slot given by the number parameter. saving the values into number parameter's is usefull when utilizing the [cmpPix](/commands/cmppix/) command. The last color read is also always saved to the [#pixCol](/variables/pixcol/) system variable.

:::note
the UO client **must** be top most in order for savepix and #pixcol to work
:::

## Example

```euo
; This will save the color on the screen where your cursor is into
; the number 1 pixel slot to be used with the cmpPix command.
savePix #cursorX #cursorY 1
```
