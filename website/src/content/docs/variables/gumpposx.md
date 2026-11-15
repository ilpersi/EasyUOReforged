---
title: "#GumpPosX"
description: "X position of the selected gump window, in pixels."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpPosY", "#ContPosX"]
aliases: ["gump x"]
---

`#GumpPosX` is the left edge of the window selected by [`#GumpIndex`](/variables/gumpindex/), as
[`#ContPosX`](/variables/contposx/) gives it for the gump on top.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
event sysmessage The window in front is at #GumpPosX #GumpPosY
halt
```
