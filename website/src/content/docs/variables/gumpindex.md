---
title: "#GumpIndex"
description: "Selects which gump the #Gump… variables describe; 1 is the window in front."
kind: variable
category: gumps
access: rw
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpCnt"]
aliases: ["gump index"]
---

`#GumpIndex` selects one entry of the snapshot [`ScanGumps`](/commands/scangumps/) took, the way
[`#FindIndex`](/variables/findindex/) selects one `FindItem` match. Set it to a number from `1` to
[`#GumpCnt`](/variables/gumpcnt/); [`#GumpName`](/variables/gumpname/) and the other `#Gump…` variables then
describe that window. Entry `1` is the window in front (on `client_beta.exe`, its menu bar).

`ScanGumps` sets it to `1`. Reading it gives the position selected. A position past `#GumpCnt` selects
nothing, and the other `#Gump…` variables then read `N/A`.

## Example

```euo
scangumps
for #GumpIndex 1 #GumpCnt
  event sysmessage #GumpIndex : #GumpName
halt
```
