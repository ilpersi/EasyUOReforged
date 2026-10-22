---
title: "#NextCPosX"
description: "Returns the x-coordinate of where the next container/gump will open."
kind: variable
category: container
access: rw
type: number
needsClient: true
source: wiki
---

The #nextCPosX system variable determines the x-coordinate of where the next container/gump will open.

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
