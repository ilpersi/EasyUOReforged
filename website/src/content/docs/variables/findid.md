---
title: '#FindID'
description: ID of the object FindItem selected, or X when nothing was found.
kind: variable
category: finditem
access: ro
type: id
needsClient: true
related: ['#FindType', '#FindCnt', '#FindIndex', '#FindKind']
aliases: ['find id', 'item id']
source: wiki
---

`#FindID` holds the ID of the object at the current [`#FindIndex`](/variables/findindex/)
position of the last [`FindItem`](/commands/finditem/) search: the unique 6–8 letter ID of that
one item or character, not its type. Use it to act on the object: drag it, use it, target it.

When the search found nothing, `#FindID` reads `X`. Check `#FindCnt > 0` (or
`#FindKind <> -1`) before you use it.

## Example

```euo
finditem POF C_ , #BackpackID
if #FindCnt > 0
  msg #FindID is the ID of the gold in my bag. There is #FindStack gold in that stack.$
halt
```
