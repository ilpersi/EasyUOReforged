---
title: "#TileName"
description: "Returns the name of the last read tile."
kind: variable
category: tile
access: ro
type: string
source: wiki
---

The #tileName system variable determines the name for the last tile read using the [tile](/commands/tile/) command.

There are over 3000 values for tile names. Some of the more usefull names include Water, Rock, Cave_Floor, Cave_Wall, and variations that include the word Tree (for example "Ohii_Tree").

## Example

```euo
tile init

Tile get #charPosX #charPosY 1
display ok The tile at X: , #charPosX , #spc , / Y: , #charPosY , #spc , has the following Name:$ , #tileName
halt
```
