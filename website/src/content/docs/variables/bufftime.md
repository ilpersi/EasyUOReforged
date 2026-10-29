---
title: "#BuffTime"
description: "Seconds left on the selected buff; -1 when it has no timer."
kind: variable
category: buffs
access: ro
type: number
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex", "#BuffBarOpen"]
aliases: ["buff timer", "buff time left"]
---

`#BuffTime` is the number of seconds left on the buff selected by [`#BuffIndex`](/variables/buffindex/),
exactly as its tooltip shows it.

- `-1` means the buff has no countdown (Hiding, for example).
- `0` means the client no longer knows the timer.
- The client refreshes the tooltip in coarse steps, about every 5 seconds, so the value jumps rather than
  counting down second by second.

It is read live: the variable inspector shows it counting down without a new `ScanBuffs`. Reads `N/A` when no buff is selected: the buff bar is closed or empty, the client's buff bar layout is not
supported, or the selected buff has left the bar since the last [`ScanBuffs`](/commands/scanbuffs/) or
`set #BuffIndex`.

## Example

```euo
scanbuffs 30018
if #BuffCnt = 0 || #BuffTime < 10
  display ok Time to recast Bless.
halt
```
