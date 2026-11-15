---
title: "#GumpSizeY"
description: "Height of the selected gump window, in pixels."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpSizeX", "#ContSizeY"]
aliases: ["gump height"]
---

`#GumpSizeY` is the height of the window selected by [`#GumpIndex`](/variables/gumpindex/), as
[`#ContSizeY`](/variables/contsizey/) gives it for the gump on top. A minimized window has its small size.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
set %bottom #GumpPosY + #GumpSizeY
event sysmessage The window in front ends at y = %bottom
halt
```
