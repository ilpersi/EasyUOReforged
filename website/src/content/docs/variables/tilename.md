---
title: "#TileName"
description: "Name of the tile read by tile get, such as tree or water."
kind: variable
category: tile
access: ro
type: string
needsClient: true
related: ["Tile", "#TileType", "#TileFlags"]
aliases: ["tile name"]
source: wiki
---

`#TileName` is the name the client's data gives the tile, such as `tree` or `water`. Spaces read as `_`. It is filled by [`tile get`](/commands/tile/) for the tile asked for.

## Example

```euo
tile init
tile cnt #CharPosX #CharPosY
tile get #CharPosX #CharPosY 1
display ok You stand on #TileName
halt
```
