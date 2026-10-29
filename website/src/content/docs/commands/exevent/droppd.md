---
title: "exevent DropPD"
description: "Puts the held item on: drops it on your paperdoll."
kind: subcommand
category: exevent
syntax: "exevent DropPD"
needsClient: true
related: ["exevent Drag", "exevent Equip"]
aliases: ["equip", "wear", "paperdoll"]
dll: DropPD
source: wiki
---

`exevent DropPD` puts on the item picked up with [`exevent Drag`](/commands/exevent/drag/), as if you had
dropped it on your paperdoll. It takes no parameters.

- It only works after **`exevent Drag`**, which records what kind of item is held. After `event Drag` it
  does nothing.
- The item has to be something EasyUO knows how to wear; for anything else nothing happens.

To put on several items at once, [`exevent Equip`](/commands/exevent/equip/) is simpler.

## Example

```euo
set %weapon TSF              ; a dagger
finditem %weapon C_ , #BackpackID
if #FindCnt > 0
{
  exevent Drag #FindID
  wait 10
  exevent DropPD
  wait 10
}
halt
```
