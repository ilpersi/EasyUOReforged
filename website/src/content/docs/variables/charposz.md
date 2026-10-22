---
title: "#CharPosZ"
description: "Returns the characters world Z-coordinate."
kind: variable
category: character
access: ro
type: number
needsClient: true
source: wiki
---

Determines the characters world Z-coordinate (Height). The #charPosZ system variable determines the characters world Z-coordinate. It is the same coordinate system as used in UO Auto Map.

## Example

```euo
if #charPosZ = 35
{
  event SysMessage Climb that mountain!
  pause
}
```
