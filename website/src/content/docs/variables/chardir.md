---
title: "#CharDir"
description: "Direction your character is facing, 0 (north) to 7."
kind: variable
category: character
access: ro
type: number
needsClient: true
related: ["#CharPosX", "Move"]
aliases: ["direction", "facing"]
dll: CharDir
source: wiki
---

`#CharDir` is the direction your character is facing:

| Value | Facing | Value | Facing |
|---|---|---|---|
| 0 | North | 4 | South |
| 1 | North-east | 5 | South-west |
| 2 | East | 6 | West |
| 3 | South-east | 7 | North-west |

## Example

```euo
if #CharDir = 0
  event SysMessage Looking north.
```
