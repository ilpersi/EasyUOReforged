---
title: "#CharPosY"
description: "Returns the characters world Y-coordinate."
kind: variable
category: character
access: ro
type: number
needsClient: true
source: wiki
---

Determines the characters world Y-coordinate.The #charPosY system variable determines the characters world Y-coordinate. It is the same coordinate system as used in UO Auto Map.

## Example

```euo
if #charPosY = 328
{
  event SysMessage Y marks the spot!
  pause
}
```
