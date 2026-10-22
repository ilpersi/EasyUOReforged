---
title: "#BuffIndex"
description: "Selects which buff the #Buff… variables describe; 1 is the first."
kind: variable
category: buffs
access: rw
type: number
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffBarOpen"]
aliases: ["buff index"]
---

`#BuffIndex` selects one entry of the snapshot [`ScanBuffs`](/commands/scanbuffs/) took, the way
[`#FindIndex`](/variables/findindex/) selects one `FindItem` match. Set it to a number from `1` to
`#BuffCnt`; [`#BuffID`](/variables/buffid/), [`#BuffName`](/variables/buffname/) and the other `#Buff…`
variables then describe that buff.

Reading it gives the position of the selected buff. Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.

## Example

```euo
scanbuffs
for #BuffIndex 1 #BuffCnt
  event sysmessage #BuffName
```

Positions can shift while you loop if a buff ends meanwhile. Run `ScanBuffs` again when you need a fixed
list.
