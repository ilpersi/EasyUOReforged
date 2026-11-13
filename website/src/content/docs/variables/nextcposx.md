---
title: "#NextCPosX"
description: "X position where the next container will open."
kind: variable
category: container
access: rw
type: number
needsClient: true
related: ["#NextCPosY", "NextCPos"]
aliases: ["gump position"]
dll: NextCPosX
source: wiki
---

`#NextCPosX` is the X position, in the client window, where the next container opens: the backpack, a
bag, a chest, the bank box. Set it, together with [`#NextCPosY`](/variables/nextcposy/), before opening a
container; [`nextcpos`](/commands/nextcpos/) sets both at once.

:::note
It only works when the client option *Offset interface windows rather than perfectly stacking them* is on.
With the option off, every container opens at the top right of the game window, and `#NextCPosX` and
`#NextCPosY` don't change.
:::

## How the client uses it

- A container opens at `#NextCPosX`, `#NextCPosY`. Then the client adds 16 to both, so the next container
  opens a little lower and to the right of it.
- When the container would come within 16 pixels of the right edge of the game window, it opens at X 16
  instead, and `#NextCPosX` then reads 32.
- A container that is already open normally just comes to the front, where it is.
- The paperdoll and the other gumps don't use it.

The values only change when the option is on, so a script can tell whether it is: read them before and after
opening a container (the [`nextcpos`](/commands/nextcpos/) page has an example).

## Example

```euo
set #NextCPosX 10
set #NextCPosY 10
msg bank$                    ; the bank box opens at 10,10
halt
```
