---
title: "#GumpArt"
description: "Graphic of the selected gump window, as an ID: the backpack is YE."
kind: variable
category: gumps
access: ro
type: id
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpName", "#GumpObjID"]
aliases: ["gump art", "gump graphic"]
---

`#GumpArt` is the graphic the window selected by [`#GumpIndex`](/variables/gumpindex/) is drawn with, in
the usual EUO format. It comes from the game's art files, so it is the same on every client build:

| Window | `#GumpArt` |
|---|---|
| backpack | `YE` |
| paperdoll | `YWC` |
| status bar | `KZP` |
| skills | `STL` |
| buff bar | `EUB` |
| spellbook | `AKD` |

`ScanGumps A_YE` lists only the windows drawn with that graphic.

Reads `N/A` for a window without a single graphic, which is every gump the server sends, and on client builds
older than 7.0.29.97. Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps A_YE
for #GumpIndex 1 #GumpCnt
  event sysmessage A backpack-style container is open: #GumpObjID
halt
```
