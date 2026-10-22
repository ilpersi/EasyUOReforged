---
title: "#FindRep"
description: "Returns the reputation of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findRep system variable contains the reputation of the object returned by [findItem](/commands/finditem/).

| Value | Description           |
|-------|-----------------------|
| 1     | Innocent (Blue)       |
| 2     | Friend (Green)        |
| 3     | Grey (Grey - Animal)  |
| 4     | Criminal (Grey)       |
| 5     | Enemy (Orange)        |
| 6     | Murderer (Red)        |
| 7     | Invulnerable (Yellow) |

## Example

```euo
finditem HS_IS G_10

if #findrep = 1
   display ok The item found is (blue) Innocent

halt
```
