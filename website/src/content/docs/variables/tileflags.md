---
title: "#TileFlags"
description: "Properties of the tile read by tile get, as names joined by _."
kind: variable
category: tile
access: ro
type: string
needsClient: true
related: ["Tile", "#TileName"]
aliases: ["tile flags", "impassable", "wet"]
source: wiki
---

`#TileFlags` lists the properties of the tile as names joined by `_`, for example `Impassable_Surface`. It is filled by [`tile get`](/commands/tile/) for the tile asked for.
Test a property with `in`.

The possible names are: `Background`, `Weapon`, `Transparent`, `Translucent`, `Wall`, `Damaging`, `Impassable`, `Wet`, `Unknown`, `Surface`, `Bridge`, `GenericStackable`, `Window`, `NoShoot`, `PrefixA`, `PrefixAn`, `Internal`, `Foliage`, `PartialHue`, `Unknown1`, `Map`, `Container`, `Wearable`, `LightSource`, `Animated`, `NoDiagonal`, `Unknown2`, `Armor`, `Roof`, `Door`, `StairBack`, `StairRight`.

## Example

```euo
set %x #CharPosX
set %y #CharPosY - 1           ; the tile north of you
tile init
tile get %x %y 1
if Impassable in #TileFlags
  display ok Cannot walk there.
halt
```
