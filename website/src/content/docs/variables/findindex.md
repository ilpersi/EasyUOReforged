---
title: '#FindIndex'
description: "Selects which FindItem match the #Find… variables describe, without searching again."
kind: variable
category: finditem
access: rw
type: number
needsClient: true
related: ['#FindCnt', '#FindID', 'IgnoreItem']
aliases: ['find index', 'next item']
source: wiki
---

[`FindItem`](/commands/finditem/) selects one match (the first, unless you pass an index) and
keeps the rest of its snapshot. Setting `#FindIndex` selects another match from that snapshot and
refreshes every `#Find…` variable, without running the slow search again. Valid values go from `1`
to `#FindCnt`.

Reading it gives the position of the match currently selected.

## Examples

Ignore every item of one type in the backpack:

```euo
finditem %TypeToIgnore C_ , #BackpackID
ignoreAgain:
if #FindIndex <= #FindCnt
{
  ignoreitem #FindID
  set #FindIndex #FindIndex + 1
  goto ignoreAgain
}
halt
```

`#FindIndex` also works as a `for` counter. This lists the properties of everything worn by the
character in the journal:

```euo
finditem * C_ , #CharID
for #FindIndex 1 #FindCnt
{
  event property #FindID
  event sysmessage #Property
  wait 20
}
halt
```
