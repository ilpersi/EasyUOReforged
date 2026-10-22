---
title: "#ContPosX"
description: "X position of the gump on top; set it to move the gump."
kind: variable
category: container
access: rw
type: number
needsClient: true
related: ["#ContPosY", "ContPos", "#ContSize"]
aliases: ["gump position"]
source: wiki
---

`#ContPosX` is the X position of the gump on top, in pixels from the left edge
of the client window. Setting it moves the gump; [`contpos`](/commands/contpos/) sets both positions at once.
Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

## Example

```euo
set #ContPosX 10
set #ContPosY 10       ; move the gump to the top-left corner
```
