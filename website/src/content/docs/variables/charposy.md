---
title: "#CharPosY"
description: "Your character’s Y position in the world (north–south)."
kind: variable
category: character
access: ro
type: number
needsClient: true
related: ["#CharPosX", "#CharPosZ", "event PathFind", "Move"]
aliases: ["position", "coordinates", "location"]
dll: CharPosY
source: wiki
---

`#CharPosY` is your character's Y coordinate in the world, the north–south position, in the
same coordinates as map tools such as UO Auto Map use. [`#CharPosZ`](/variables/charposz/) is the height.

## Example

```euo
if #CharPosY = 4515
  display ok X marks the spot!
halt
```
