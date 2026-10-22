---
title: "#BuffCnt"
description: "Number of buffs on the buff bar, counted live."
kind: variable
category: buffs
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffIndex", "#BuffBarOpen"]
aliases: ["buff count"]
---

`#BuffCnt` is the number of buffs and debuffs shown on the client's buff bar. It is the live count: it
changes as buffs come and go, even without a new [`ScanBuffs`](/commands/scanbuffs/).

It is `0` when the buff bar window is closed. Use [`#BuffBarOpen`](/variables/buffbaropen/) to tell a
closed bar from an open one with no buffs.

## Example

```euo
scanbuffs
if #BuffCnt = 0
  display ok No buffs right now.
```
