---
title: "#TileCnt"
description: "Returns the number of tile layers of the last read position."
kind: variable
category: tile
access: ro
type: number
source: wiki
---

The #tileCnt system variable determines the number of layers for the last tile read using the [tile](/commands/tile/) command.

To understand the tile system think of each tile as a stack of layers, each layer shows something visible in UO whether it be a tree, mountain, grass, or water. So to search these layers you must first count the number of layers in a tile.

## Example

```euo
Tile init

Tile cnt #charPosX #charPosY #cursKind
set %layer_ammount 0
set %text
for %cnt #tileCnt 1
    {
    tile Get #charPosX #charPosY %cnt #cursKind
    set %layer_ammount %layer_ammount + 1
    set %text %text , $Layer , #spc , %cnt , : , #spc , #tiletype
    }
set %text [You , #spc , are , #spc , standing , #spc , here] , %text , $[The , #spc , very , #spc , bootom , #spc , of , #spc , the , #spc , world]
display ok The layers at your positions look like the following:$ %text
halt
```
