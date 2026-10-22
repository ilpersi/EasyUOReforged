---
title: "#TileType"
description: "Graphic number of the tile read by tile get."
kind: variable
category: tile
access: ro
type: number
needsClient: true
related: ["Tile", "#TileName", "#LTargetTile"]
aliases: ["tile graphic"]
source: wiki
---

`#TileType` is the graphic number of the tile. It is filled by [`tile get`](/commands/tile/) for the tile asked for. It is the same number [`#LTargetTile`](/variables/ltargettile/)
uses, so it identifies trees, rocks and water for resource gathering.
