---
title: "#ContSizeX"
description: "Width of the top gump in pixels."
kind: variable
category: container
access: ro
type: number
needsClient: true
related: ["#ContSizeY", "#ContSize", "#ContPosX", "IgnoreCont"]
aliases: ["container width", "gump width"]
dll: ContSizeX
---

`#ContSizeX` is the width, in pixels, of the gump on top (the last one opened or clicked). It is the first half
of [`#ContSize`](/variables/contsize/) as a plain number, so you can calculate with it without splitting the
`x_y` text.

Gumps on the ignore list (see [`IgnoreCont`](/commands/ignorecont/)) are skipped.

## Example

```euo
; click the bottom-right corner of the top gump
set %x #ContPosX + #ContSizeX - 10
set %y #ContPosY + #ContSizeY - 10
click %x %y
halt
```
