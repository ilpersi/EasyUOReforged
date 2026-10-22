---
title: "#TileFlags"
description: "Returns the flags of the last read tile."
kind: variable
category: tile
access: ro
type: string
source: wiki
---

The #tileFlags system variable determines the flags for the last tile read using the [tile](/commands/tile/) command.

Possible values include those listed in the table below.

| Background | Weapon     | Transparent | Translucent      |
|------------|------------|-------------|------------------|
| Wall       | Damaging   | Impassable  | Wet              |
| Unknown    | Surface    | Bridge      | GenericStackable |
| Window     | NoShoot    | PrefixA     | PrefixAn         |
| Internal   | Foliage    | PartialHue  | Unknown1         |
| Map        | Container  | Wearable    | LightSource      |
| Animated   | NoDiagonal | Unknown2    | Armor            |
| Roof       | Door       | StairBack   | StairRight       |

Tile Flag Values

## Example

```euo
tile init

Tile get #charPosX #charPosY 1
display ok The tile at X: , #charPosX , #spc , / Y: , #charPosY , #spc , has the following Flags:$ , #tileFlags
halt
```
