---
title: "#FindBagID"
description: "ID of the container holding the object FindItem selected."
kind: variable
category: finditem
access: ro
type: id
needsClient: true
related: ["#FindKind", "#ContID"]
aliases: ["container", "bag"]
source: wiki
---

`#FindBagID` is the ID of the container the object is in. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/). It reads `X` for objects on the ground.

## Example

```euo
finditem POF C
if #FindCnt > 0
  display ok Gold found in container #FindBagID
halt
```
