---
title: "#CharPosX"
description: "Returns the characters world X-coordinate."
kind: variable
category: character
access: ro
type: number
needsClient: true
source: wiki
---

Determines the characters world X-coordinate. The #charPosX system variable determines the characters world X-coordinate. It is the same coordinate system as used in UO Auto Map.

## Example

```euo
if #charPosX = 4515
{
  event SysMessage X marks the spot!
  pause
}
```
