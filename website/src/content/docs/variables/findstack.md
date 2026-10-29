---
title: "#FindStack"
description: "Number of items in the stack FindItem selected; 0 for characters."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["#FindID", "exevent Drag"]
aliases: ["amount", "stack size"]
source: wiki
---

`#FindStack` is the number of items in the stack. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/). Characters (mobiles) read `0`, which is a quick way to
tell them from items.

## Example

```euo
finditem POF C_ , #BackpackID
if #FindCnt > 0
  display ok That pile holds #FindStack gold.
halt
```
