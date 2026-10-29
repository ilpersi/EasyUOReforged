---
title: "exevent PopUp"
description: "Opens the context menu of an item or character."
kind: subcommand
category: exevent
syntax: "exevent PopUp {id}"
needsClient: true
related: ["FindItem", "Click"]
aliases: ["context menu"]
dll: Popup
source: wiki
---

`exevent PopUp` opens the context menu of an item or character, the menu you get when you click it with
the mouse: vendor *Buy* and *Sell*, *Open Paperdoll*, pet commands, and so on. Then click the entry you
want.

The item or character has to be known to the client, which usually means on screen.

Older documentation shows `x` and `y` after the ID. They are accepted but ignored: the interpreter always
passes `0, 0`.

## Example

```euo
set %vendor ABCDEFG          ; the vendor's ID
finditem %vendor G_10
if #FindCnt > 0
  exevent PopUp #FindID
halt
```
