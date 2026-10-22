---
title: "#CharDir"
description: "Returns the direction the character is facing."
kind: variable
category: character
access: ro
type: number
needsClient: true
source: wiki
---

The #charDir system variable determines the direction the character is facing.

| Value | Facing     |
|-------|------------|
| 0     | North      |
| 1     | North East |
| 2     | East       |
| 3     | South East |
| 4     | South      |
| 5     | South West |
| 6     | West       |
| 7     | North West |

Table of #charDir values

## Example

```euo
top:
if #CHARDIR = 0
    msg : Looking North $
wait 2s
goto top
```
