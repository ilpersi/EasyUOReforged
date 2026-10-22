---
title: "#FindStack"
description: "Returns the number of stacked items in the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findStack system variable contains the number of stacked items in the object returned by [findItem](/commands/finditem/).

## Example

```euo
finditem POF C_ , #BACKPACKID
if #FINDCNT > 0
{
    display ok I found a stack of gold and there are #FINDSTACK gold pieces in it.
}
if #FINDCNT < 1
{
    display ok No gold was found in backpack.
}
halt
```
