---
title: "#FindType"
description: "Type of the object FindItem selected."
kind: variable
category: finditem
access: ro
type: id
needsClient: true
related: ["#FindID", "FindItem"]
aliases: ["item type"]
source: wiki
---

`#FindType` is the item type of the object, the 2–3 letter code shared by all items of the same kind (`POF`
for gold). It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/). It reads `X` when nothing was found.

## Example

```euo
finditem * C_ , #BackpackID
for #FindIndex 1 #FindCnt
  event SysMessage #FindID is of type #FindType
halt
```
