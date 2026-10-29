---
title: "#FindRep"
description: "Notoriety of the character FindItem selected: 1 innocent to 7 invulnerable."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["FindItem", "#EnemyID"]
aliases: ["notoriety", "reputation", "name colour"]
source: wiki
---

`#FindRep` is the notoriety (name colour) of the character. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/).

| Value | Notoriety |
|---|---|
| 1 | Innocent (blue) |
| 2 | Friend, ally (green) |
| 3 | Attackable without penalty, such as animals (grey) |
| 4 | Criminal (grey) |
| 5 | Enemy (orange) |
| 6 | Murderer (red) |
| 7 | Invulnerable (yellow) |

## Example

```euo
finditem HS_IS G_10
if #FindRep = 6
  display ok A murderer is near!
halt
```
