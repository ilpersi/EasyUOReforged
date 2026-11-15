---
title: "#GumpKind"
description: "Kind of the selected gump window, the same code as #ContKind."
kind: variable
category: gumps
access: ro
type: id
origin: reforged
needsClient: true
related: ["ScanGumps", "#ContKind", "#GumpTypeID"]
aliases: ["gump kind"]
---

`#GumpKind` is the code of the window's kind, the same value [`#ContKind`](/variables/contkind/) gives
for the gump on top, in the usual EUO format.

**It changes with every client update.** Don't keep it in a script for long: to recognise a window, use
[`#GumpTypeID`](/variables/gumptypeid/) for a server gump, [`#GumpArt`](/variables/gumpart/) or
[`#GumpName`](/variables/gumpname/) for the others.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
if #GumpKind = #ContKind
  event sysmessage The window in front is the gump on top.
halt
```
