---
title: "#FindCol"
description: "Returns the color of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findCol system variable contains the color of the object returned by [findItem](/commands/finditem/).

## Example

```euo
finditem POF C_ , #BACKPACKID
if #FINDCNT > 0
{
    display ok I found a stack of gold, the color value of it is #FINDCOL
}
if #FINDCNT < 1
{
    display ok No gold was found.
}
halt
```
