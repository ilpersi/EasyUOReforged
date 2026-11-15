---
title: "#GumpSizeX"
description: "Width of the selected gump window, in pixels."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpSizeY", "#ContSizeX"]
aliases: ["gump width"]
---

`#GumpSizeX` is the width of the window selected by [`#GumpIndex`](/variables/gumpindex/), as
[`#ContSizeX`](/variables/contsizex/) gives it for the gump on top. A minimized window has its small size.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
event sysmessage The window in front is #GumpSizeX by #GumpSizeY
halt
```
