---
title: "NextCPos"
description: "Sets where the next gump will open."
kind: command
category: client
syntax: "nextcpos {x} {y}"
needsClient: true
related: ["ContPos", "#NextCPosX", "#NextCPosY"]
aliases: ["gump position"]
source: wiki
---

`nextcpos` sets the position, in the client window, where the next gump opens. It does the same as setting
[`#NextCPosX`](/variables/nextcposx/) and [`#NextCPosY`](/variables/nextcposy/).

:::note
It only works when the client option *Offset interface windows rather than perfectly stacking them*
(interface options) is turned on.
:::

## Example

```euo
; close the paperdoll and open it again at 0,0
event Macro 9 1
wait 20
nextcpos 0 0
event Macro 8 1
halt
```
