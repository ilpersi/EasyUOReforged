---
title: "#NextCPosY"
description: "Y position where the next gump will open."
kind: variable
category: container
access: rw
type: number
needsClient: true
related: ["#NextCPosX", "NextCPos"]
aliases: ["gump position"]
dll: NextCPosY
source: wiki
---

`#NextCPosY` is the Y position, in the client window, where the next gump opens. Set it, together with
[`#NextCPosX`](/variables/nextcposx/), before opening a gump; [`nextcpos`](/commands/nextcpos/)
sets both at once.

:::note
It only works when the client option *Offset interface windows rather than perfectly stacking them* is on.
:::

## Example

```euo
set #NextCPosX 10
set #NextCPosY 10
msg bank$                    ; the bank box opens at 10,10
halt
```
