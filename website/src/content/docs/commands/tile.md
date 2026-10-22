---
title: "Tile"
description: "Retrieves information about tiles."
kind: command
category: misc
syntax: "tile {Init} [noOverrides]\ntile {Cnt} {x} {y} [facet]\ntile {Get} {x} {y} {index} [facet]"
changed: true
needsClient: true
sets: ["#tiletype", "#tilez", "#tilecnt", "#tilename", "#tileflags"]
source: wiki
---

The tile command retrieves information about map tiles.

| Option | Description |
|----|----|
| Init | Initializes the tile information for retrieval in EasyUO. Using the "noOverrides" option forces EasyUO to not read the statics override file (VerData.mul), which could be useful for freeshards that do not use the overrides. If you don't know what VerData.mul is, you probably don't need to use the noOverrides option. |
| Cnt | Retrieves the number of tiles for a specific position. The value in [#tileCnt](/variables/tilecnt/) is updated. The default value for facet is the current facet. Otherwise follows the values for [#cursKind](/variables/curskind/). |
| Get | Retrives the tile type and z value. The values in [#tileType](/variables/tiletype/) and [#tileZ](/variables/tilez/) are updated. The index goes from 1 to [#tileCnt](/variables/tilecnt/). The default value for facet is the current facet. Otherwise follows the values for [#cursKind](/variables/curskind/) |

:::note
See the [#tileFlags](/variables/tileflags/) page for a list of all of the possible #tileFlag values.
:::

## Reforged notes

Newer client installs ship the maps packed in `.uop` files (`map0LegacyMUL.uop`, …) instead of the
classic `map0.mul`. EasyUO Reforged reads those directly, so `tile` works on these installs without
extracting the files to the old MUL format first. When both exist, the classic `.mul` file is used.
