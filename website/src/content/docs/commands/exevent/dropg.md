---
title: "exevent Dropg"
description: "Drops an object on the ground using packets."
kind: subcommand
category: exevent
syntax: "Exevent Dropg {x} {y} [z]"
needsClient: true
related: ["exevent"]
source: wiki
---

The *Exevent Dropg* command drops obects you drag using the [Exevent Drag](/commands/exevent/drag/) command to the given ground coordinate. If no Z coordinate is specified, the default will be [#charPosZ](/variables/charposz/).

:::note
- This command is only available from EUO 1.5
- You shouldn't use [Event Drag](/commands/event/drag/) in connection with [Exevent Dropg](/commands/exevent/dropg/) command or you'll end up with a ghost item on your cursor. That's why there is an [Exevent Drag](/commands/exevent/drag/) command
:::

## Example

```euo
finditem %trash C_ , #backpackid
if #FINDCNT > 0
{
    Exevent Drag #findid #findstack
    wait 10
    Exevent Dropg #charposx #charposy #charposz
    wait 10
}
halt
```
