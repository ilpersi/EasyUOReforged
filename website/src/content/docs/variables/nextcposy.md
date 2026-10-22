---
title: "#NextCPosY"
description: "Returns the y-coordinate of where the next container/gump will open."
kind: variable
category: container
access: rw
type: number
needsClient: true
source: wiki
---

The #nextCPosY system variable determines the y-coordinate of where the next container/gump will open.

:::note
The "Offset interface windows rather than perfectly stacking them" option, in Interface options (Mouse Icon) must be turned on for the #nextCPosX and #nextCPosY variables to work.
:::

## Example

```euo
; Open bank box at 10,10
set #nextCPosX 10
set #nextCPosY 10
msg bank$
halt
```
