---
title: "#CursorX"
description: "Mouse cursor X position relative to the game area."
kind: variable
category: misc
access: ro
type: number
needsClient: true
related: ["#CursorY", "Click", "SavePix"]
aliases: ["mouse position"]
source: wiki
---

`#CursorX` is the horizontal position of the mouse cursor, in pixels from the left edge of the game area; to its
left the value is negative. [`#CursorY`](/variables/cursory/) is the vertical position.

## Example

```euo
savepix #CursorX #CursorY 1
```
