---
title: "#FindCnt"
description: "How many objects the last FindItem found."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["FindItem", "#FindIndex", "#FindKind"]
aliases: ["find count", "how many"]
source: wiki
---

`#FindCnt` is the number of objects the last [`FindItem`](/commands/finditem/) found; `0` means none. It is the
way to check whether a search found anything, and the upper bound for [`#FindIndex`](/variables/findindex/).

## Example

```euo
finditem * C_ , #BackpackID
if #FindCnt > 0
  display ok There are #FindCnt items in your backpack.
```
