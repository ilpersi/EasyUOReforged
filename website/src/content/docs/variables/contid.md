---
title: "#ContID"
description: "ID of the item a container gump on top belongs to."
kind: variable
category: container
access: ro
type: id
needsClient: true
related: ["#ContType", "#ContName", "FindItem"]
aliases: ["container id"]
dll: ContID
source: wiki
---

`#ContID` is the ID of the item the gump on top belongs to: for a container gump, the container itself, so
you can search it with [`finditem`](/commands/finditem/). For a gump that belongs to no item, such as a
crafting menu, it reads `YC`, the code for 0. Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

## Example

```euo
; search whatever container was opened last
finditem * C_ , #ContID
display ok #FindCnt items in it
halt
```
