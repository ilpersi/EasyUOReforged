---
title: "#GumpMin"
description: "Whether the selected gump window is minimized: #true or #false."
kind: variable
category: gumps
access: ro
type: boolean
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpSizeX", "#GumpSizeY"]
aliases: ["gump minimized"]
---

`#GumpMin` is `#true` when the window selected by [`#GumpIndex`](/variables/gumpindex/) is minimized, and
`#false` when it is shown at full size. A minimized window keeps its place in the list;
[`#GumpSizeX`](/variables/gumpsizex/) and [`#GumpSizeY`](/variables/gumpsizey/) then give its small size.

Reads `N/A` on client builds older than 7.0.29.97. Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
for #GumpIndex 1 #GumpCnt
  if #GumpMin = #true
    event sysmessage #GumpName is minimized
halt
```
