---
title: "#FindType"
description: "Returns the type of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: id
needsClient: true
source: wiki
---

The #findType system variable contains the type of the object returned by [findItem](/commands/finditem/).

## Example

```euo
finditem * C_ , #BACKPACKID
for #FINDINDEX 1 #FINDCNT
{
 event sysmessage Found item, the type of that item is #FINDTYPE
 wait 20
}
halt
```
