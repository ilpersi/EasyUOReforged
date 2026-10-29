---
title: "exevent DropC"
description: "Drops the held item into a container, or onto a stack to combine them."
kind: subcommand
category: exevent
syntax: "exevent DropC {container id} [x y]"
needsClient: true
related: ["exevent Drag", "exevent DropG", "#BackpackID"]
aliases: ["drop in container"]
dll: DropC
source: wiki
---

`exevent DropC` drops the item picked up with [`exevent Drag`](/commands/exevent/drag/) into a container.

## Parameters

| Parameter | Meaning |
|---|---|
| `container id` | The container. Give the ID of a stack instead to combine the held items with it. |
| `x`, `y` | Optional. Where to put it inside the container, relative to the container's own top-left corner. Without them, the server chooses. |

Pick the item up with `exevent Drag`, not [`event Drag`](/commands/event/drag/): mixing `event Drag` with
the `exevent Drop…` commands can leave a ghost item on the cursor.

## Example

```euo
; move all gold within reach into the backpack
finditem POF G_2
if #FindCnt > 0
{
  exevent Drag #FindID #FindStack
  wait 10
  exevent DropC #BackpackID
  wait 10
}
halt
```
