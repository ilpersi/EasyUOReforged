---
title: "#ContPosY"
description: "Y position of the gump on top; set it to move the gump."
kind: variable
category: container
access: rw
type: number
needsClient: true
related: ["#ContPosX", "ContPos", "#ContSize"]
aliases: ["gump position"]
dll: ContPosY
source: wiki
---

`#ContPosY` is the Y position of the gump on top, in pixels from the top edge
of the client window. Setting it moves the gump; [`contpos`](/commands/contpos/) sets both positions at once.
Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

## Example

```euo
set #ContPosY 10
set #ContPosX 10       ; move the gump to the top-left corner
halt
```
