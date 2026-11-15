---
title: "#GumpCnt"
description: "Number of gump windows ScanGumps found."
kind: variable
category: gumps
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpIndex"]
aliases: ["gump count"]
---

`#GumpCnt` is the number of entries in the snapshot the last [`ScanGumps`](/commands/scangumps/) took:
the open gump windows, or those that matched its filter. `0` when there are none.

It does not change until the next `ScanGumps`, even if windows open or close meanwhile.

## Example

```euo
scangumps
event sysmessage #GumpCnt windows are open
halt
```
