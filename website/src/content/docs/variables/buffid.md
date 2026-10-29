---
title: "#BuffID"
description: "Icon ID of the selected buff, a plain number (Bless is 30018)."
kind: variable
category: buffs
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex", "#BuffBarOpen"]
aliases: ["buff icon"]
---

`#BuffID` is the icon ID of the buff selected by [`#BuffIndex`](/variables/buffindex/). It is a plain
number, not a Sys26 ID: Bless is `30018` (`$7542`). Pass it to `ScanBuffs` to look for one buff only:
`scanbuffs 30018`.

Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.

## Example

```euo
scanbuffs
for %i 1 #BuffCnt
{
  set #BuffIndex %i
  if #BuffID = 30018
    display ok Blessed: #BuffTime s left
}
halt
```
