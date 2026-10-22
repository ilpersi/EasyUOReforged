---
title: "#TileZ"
description: "Returns the z-coordinate of the last read tile."
kind: variable
category: tile
access: ro
type: number
source: wiki
---

The #tileZ system variable determines the z-coordinate for the last tile read using the [tile](/commands/tile/) command.

## Example

```euo
tile init

Tile cnt #charPosX #charPosY #cursKind
display ok The Z value of the tile at X: , #charPosX , #spc , / Y: , #charPosY , #spc , is: , #tileZ
halt
```
