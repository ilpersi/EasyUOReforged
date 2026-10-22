---
title: "exevent Drag"
description: "Drags an object using packets."
kind: subcommand
category: exevent
syntax: "Exevent Drag {object id} [amount]"
needsClient: true
related: ["exevent"]
source: wiki
---

The *exEvent Drag* command drags an object given by its id. *exEvent Drag* is also able to drag a given amount from a stack of items by using the amount argument. if no amount is specified, the default amount is 1.

## Example

```euo
finditem %gold G_2
if #FINDCNT > 0
{
    Exevent Drag #findid #findstack
    wait 10
    Exevent Dropc #backpackid
    wait 10
}
halt
```
