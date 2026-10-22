---
title: "#TileCnt"
description: "Number of tiles at a map position, from tile cnt."
kind: variable
category: tile
access: ro
type: number
needsClient: true
related: ["Tile", "#TileType"]
aliases: ["tile count"]
source: wiki
---

`#TileCnt` is the number of tiles at the position asked with [`tile cnt`](/commands/tile/): the ground and every
static on it. `tile get` reads them one by one, from `1` to `#TileCnt`. It is `0` before `tile init`.
