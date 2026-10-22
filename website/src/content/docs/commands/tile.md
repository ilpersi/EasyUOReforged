---
title: "Tile"
description: "Reads the map: how many tiles are at a spot, and the type, height, name and flags of each."
kind: command
category: misc
syntax: "tile init [nooverrides]\ntile cnt {x} {y} [facet]\ntile get {x} {y} {n} [facet]"
changed: true
needsClient: true
sets: ["#TileCnt", "#TileType", "#TileZ", "#TileName", "#TileFlags"]
related: ["#TileFlags", "#CursKind"]
aliases: ["map", "terrain", "statics"]
source: wiki
---

`tile` reads the client's map files: what lies at a world position, layer by layer (ground, then statics).

| Form | What it does |
|---|---|
| `tile init [nooverrides]` | Loads the map files. Needed once before `cnt` and `get`. |
| `tile cnt {x} {y} [facet]` | Puts the number of tiles at `x`, `y` in [`#TileCnt`](/variables/tilecnt/). |
| `tile get {x} {y} {n} [facet]` | Reads tile `n` (from 1 to `#TileCnt`) at `x`, `y` into [`#TileType`](/variables/tiletype/), [`#TileZ`](/variables/tilez/), [`#TileName`](/variables/tilename/) and [`#TileFlags`](/variables/tileflags/). |

## Details

- **`tile init`** reads the files from the attached client's own folder. `nooverrides` skips the client's
  statics override file (`verdata.mul`), for shards that do not use it. Without `tile init`, `cnt` gives 0
  and `get` reads nothing.
- **`facet`** is the facet number, as in [`#CursKind`](/variables/curskind/). Default: the facet you are on.
- See [`#TileFlags`](/variables/tileflags/) for what the flags mean.

## Example

```euo
tile init
tile cnt #CharPosX #CharPosY
for %n 1 #TileCnt
{
  tile get #CharPosX #CharPosY %n
  event sysmessage #TileName at height #TileZ
}
```

## Reforged notes

Newer client installs ship the maps packed in `.uop` files (`map0LegacyMUL.uop`, …) instead of the classic
`map0.mul`. EasyUO Reforged reads those directly, so `tile` works on these installs without extracting the
files to the old MUL format first. When both exist, the classic `.mul` file is used.
