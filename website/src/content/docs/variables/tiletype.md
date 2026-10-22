---
title: "#TileType"
description: "Returns the type of the last read tile."
kind: variable
category: tile
access: ro
type: number
source: wiki
---

The #tileType system variable shows the numeric value of the last tile read using the [tile](/commands/tile/) command.

Each tile graphic in the map files has a unique identifier, which is represented in EasyUO with the #tileType value.

## Example

```euo
Tile init

Tile cnt #charPosX #charPosY #cursKind
tile Get #charPosX #charPosY #tileCnt #cursKind
display ok The tileType value of the tile at X: , #charPosX , #spc , / Y: , #charPosY , #spc , is: , #spc , #tileType $
+Remember: There are #tileCnt layers and the informations given are for the topmost layer
halt
```
