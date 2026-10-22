---
title: "#FindDist"
description: "Returns the distance from the character to the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findDist system variable contains the distance from the character to the object returned by [findItem](/commands/finditem/).

## Example

```euo
finditem POF G_15
if #FINDCNT > 0
{
    display ok I found a stack of gold #FINDDIST tiles away from me
}
if #FINDCNT < 1
{
    display ok No gold was found on the ground.
}
halt
```
