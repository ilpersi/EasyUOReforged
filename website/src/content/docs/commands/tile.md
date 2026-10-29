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
  map and statics patch files (`mapdif*.mul`, `mapdifl*.mul`, `stadif*.mul`, `stadifl*.mul` and
  `stadifi*.mul`) and reads only the base map files, for shards that do not use the patches. Without
  `tile init`, `cnt` gives 0 and `get` reads nothing.
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
halt
```

## Reforged notes

- Newer client installs ship the maps packed in `.uop` files (`map0LegacyMUL.uop`, …) instead of the
  classic `map0.mul`. EasyUO Reforged reads those directly, so `tile` works on these installs without
  extracting the files to the old MUL format first. When both exist, the classic `.mul` file is used.
- **Trammel** (facet 1) is read from its own map files (`map1`, `staidx1.mul` and `statics1.mul`).
  EasyUO 1.5 read Felucca's files for Trammel, which matched clients before Mondain's Legacy but not
  current ones, where places such as New Haven differ. Installs without Trammel files still use
  Felucca's.
- **Felucca and Trammel are 7168 tiles wide** on current clients. EasyUO 1.5 stopped at x 6143, so `cnt`
  and `get` gave nothing further east. The width now comes from the map files, so older 6144-wide
  installs work as before.
- **Ter Mur** (facet 5) is read from the right place. EasyUO 1.5 computed the position in the map files
  wrongly there and returned tiles from elsewhere on the facet.
- **`tile init` works when patch files are missing.** Current installs no longer ship the map patch
  files, and EasyUO 1.5's `tile init` stopped the script with an error when Felucca's or Trammel's were
  not there, so only `tile init nooverrides` worked. Now a facet's patches are used only when all of
  their files are present (`mapdifl` and `mapdif` for the map, `stadifl`, `stadifi` and `stadif` for
  the statics), and are skipped otherwise.
- Scripts that read Trammel, Ter Mur or the far east of Felucca can see different tiles than in
  EasyUO 1.5: those are the client's real tiles.
