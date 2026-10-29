---
title: "exevent DropG"
description: "Drops the held item on the ground at a world position."
kind: subcommand
category: exevent
syntax: "exevent DropG {x} {y} [z]"
needsClient: true
related: ["exevent Drag", "exevent DropC", "#CharPosX"]
aliases: ["drop on ground"]
dll: DropG
source: wiki
---

`exevent DropG` drops the item picked up with [`exevent Drag`](/commands/exevent/drag/) on the ground.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | World position, within reach. |
| `z` | Optional height. Default: your current [`#CharPosZ`](/variables/charposz/). |

Pick the item up with `exevent Drag`, not [`event Drag`](/commands/event/drag/): mixing `event Drag` with
the `exevent Drop…` commands can leave a ghost item on the cursor.

## Example

```euo
; drop a piece of trash at your feet
set %trash ABCDEFG           ; the ID of what to drop
finditem %trash C_ , #BackpackID
if #FindCnt > 0
{
  exevent Drag #FindID #FindStack
  wait 10
  exevent DropG #CharPosX #CharPosY
  wait 10
}
halt
```
