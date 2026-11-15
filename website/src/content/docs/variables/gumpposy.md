---
title: "#GumpPosY"
description: "Y position of the selected gump window, in pixels."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpPosX", "#ContPosY"]
aliases: ["gump y"]
---

`#GumpPosY` is the top edge of the window selected by [`#GumpIndex`](/variables/gumpindex/), as
[`#ContPosY`](/variables/contposy/) gives it for the gump on top.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
set %x #GumpPosX + #GumpSizeX
event sysmessage The window in front ends at x = %x
halt
```
