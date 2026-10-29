---
title: "exevent Drag"
description: "Picks up an item, or a given amount of a stack, through the server."
kind: subcommand
category: exevent
syntax: "exevent Drag {id} [amount]"
needsClient: true
related: ["exevent DropC", "exevent DropG", "exevent DropPD", "event Drag"]
aliases: ["pick up", "drag item", "move item"]
dll: Drag
source: wiki
---

`exevent Drag` asks the server to pick up an item. Follow it with
[`exevent DropC`](/commands/exevent/dropc/), [`DropG`](/commands/exevent/dropg/) or
[`DropPD`](/commands/exevent/droppd/) to put it down again.

## Parameters

| Parameter | Meaning |
|---|---|
| `id` | The item. It has to be known to the client: on screen, or in an open container. |
| `amount` | Optional. How many to take from a stack. **Default: 1**, not the whole stack: pass [`#FindStack`](/variables/findstack/) to take all of it. |

## Example

```euo
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
