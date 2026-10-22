---
title: "#FindCol"
description: "Colour (hue) of the object FindItem selected."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["FindItem", "#FindType"]
aliases: ["colour", "color", "hue"]
source: wiki
---

`#FindCol` is the colour (hue) number of the object. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/). `0` is the item's normal colour. It tells apart items
of the same type that differ only in colour, such as dyed cloth or coloured ore.

## Example

```euo
finditem %ore C_ , #BackpackID
if #FindCol = 0
  event SysMessage Plain iron ore.
```
