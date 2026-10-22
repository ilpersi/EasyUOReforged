---
title: "#FindBagID"
description: "Returns the bag the object returned by findItem is contained in."
kind: variable
category: finditem
access: ro
type: id
needsClient: true
source: wiki
---

The #findBagID system variable contains the bagID the object returned by [findItem](/commands/finditem/) is contained in.

## Example

```euo
finditem POF C
if #FINDCNT > 0
{
    display ok I found a stack of gold in a bag, the ID of the bag I found it in is #FINDBAGID
}
if #FINDCNT < 1
{
    display ok I could not find any gold in open containers.
}
halt
```
