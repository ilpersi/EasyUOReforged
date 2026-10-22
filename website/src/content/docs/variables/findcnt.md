---
title: "#FindCnt"
description: "Returns the number of objects that matches what was searched for with the findItem command."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findCnt system variable contains the number of objects that matches what was searched for with the [findItem](/commands/finditem/) command.

## Example

```euo
....
loop:
finditem %housesign G_5
if #findcnt < 1
{
gosub placement
}
goto loop
....

finditem * C_ , #BACKPACKID
if #FINDCNT > 0
{
 display ok There are #FINDCNT items in your backpack!
}
if #FINDCNT < 1
{
 display ok No items were found in your backpack!
}
halt
```
