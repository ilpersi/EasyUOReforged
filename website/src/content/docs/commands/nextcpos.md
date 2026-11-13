---
title: "NextCPos"
description: "Sets where the next container will open."
kind: command
category: client
syntax: "nextcpos {x} {y}"
needsClient: true
related: ["ContPos", "#NextCPosX", "#NextCPosY"]
aliases: ["gump position"]
source: wiki
---

`nextcpos` sets the position, in the client window, where the next container opens: the backpack, a bag, a
chest, the bank box. It does the same as setting [`#NextCPosX`](/variables/nextcposx/) and
[`#NextCPosY`](/variables/nextcposy/).

:::note
It only works when the client option *Offset interface windows rather than perfectly stacking them*
(interface options) is turned on. With the option off, every container opens at the top right of the game
window.
:::

Each time a container opens there, the client moves the position 16 pixels right and down, so containers
opened one after the other cascade. Past the edge of the game window it starts again at 16. The paperdoll and
the other gumps don't use it. [`#NextCPosX`](/variables/nextcposx/) has the details.

## Examples

```euo
; close the backpack and open it again at 100,100
event Macro 9 7
wait 20
nextcpos 100 100
event Macro 8 7
halt
```

The position only moves when the option is on, so opening a container shows whether it is:

```euo
set %x #NextCPosX
event Macro 9 7
wait 20
event Macro 8 7
wait 20
if #NextCPosX = %x
  display ok The option is off: containers open at the top right.
else
  display ok The option is on.
halt
```
