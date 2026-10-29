---
title: "#CharPosX"
description: "Your character’s X position in the world (west–east)."
kind: variable
category: character
access: ro
type: number
needsClient: true
related: ["#CharPosY", "#CharPosZ", "event PathFind", "Move"]
aliases: ["position", "coordinates", "location"]
dll: CharPosX
source: wiki
---

`#CharPosX` is your character's X coordinate in the world, the west–east position, in the
same coordinates as map tools such as UO Auto Map use. [`#CharPosZ`](/variables/charposz/) is the height.

## Example

```euo
if #CharPosX = 4515
  display ok X marks the spot!
halt
```
