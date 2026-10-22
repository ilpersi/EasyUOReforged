---
title: "exevent Droppd"
description: "Drops wearable items into the paperdoll."
kind: subcommand
category: exevent
syntax: "Exevent Droppd"
needsClient: true
related: ["exevent"]
source: wiki
---

The *Exevent Droppd* command drops previously dragged (using [Exevent Drag](/commands/exevent/drag/)) wearable item into the paperdoll.

:::note
- This command is only available from EUO 1.5 TV 57
- You shouldn't use [Event Drag](/commands/event/drag/) in connection with [Exevent Droppd](/commands/exevent/droppd/) command or you'll end up with a ghost item on your cursor. That's why there is an [Exevent Drag](/commands/exevent/drag/) command
:::

## Example

```euo
finditem %weapon C_ , #backpackid
if #FINDCNT > 0
{
    Exevent Drag #findid #findstack
    wait 10
    Exevent Droppd
    wait 10
}
halt
```
