---
title: "#GumpObjID"
description: "ID of the object the selected gump window belongs to: a container or a character."
kind: variable
category: gumps
access: ro
type: id
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpArt", "#ContID"]
aliases: ["gump object", "gump container"]
---

`#GumpObjID` is the ID of the object the window selected by [`#GumpIndex`](/variables/gumpindex/) belongs
to, in the usual EUO format, as [`#ContID`](/variables/contid/) gives it for the gump on top: the container
of a container window, the character of a paperdoll or status bar, the spellbook of a spellbook window.

Reads `N/A` for a window that belongs to no object (the skills window, the buff bar, the gumps the server
sends). Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
for #GumpIndex 1 #GumpCnt
  if #GumpObjID = #BackpackID
    event sysmessage The backpack is open at #GumpPosX #GumpPosY
halt
```
