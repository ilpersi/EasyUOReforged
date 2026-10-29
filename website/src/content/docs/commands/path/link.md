---
title: "path Link"
description: "Adds a teleporter, gate or ladder that routes may use: a one-way jump between two places."
kind: subcommand
category: path
syntax: "path link {x} {y} {z} {x2} {y2} {z2} [cost] [facet]"
origin: reforged
sets: ["#PathState"]
related: ["path find", "path clear", "#PathDir"]
aliases: ["teleporter", "moongate"]
---

`path link` tells [`path find`](/commands/path/find/) that a character standing at `x`, `y`, `z` can get to
`x2`, `y2`, `z2` in one go: a teleporter tile, a gate, a ladder. The map files don't know about these;
they depend on the shard.

- It is **one way**. Add a second link for the way back.
- It is used by a route that reaches `x`, `y` within 5 of the height `z`.
- `cost` is in hundredths of a step; the default `100` makes the jump count as one step. Give a gate you
  must double-click, or a slow ladder, a higher cost.
- In the route, the step through a link has [`#PathDir`](/variables/pathdir/) `8`. Your script does what the
  link needs there: wait for the teleporter, use the gate.
- Both ends are on the same facet: `facet`, a number as in [`#CursKind`](/variables/curskind/), by default
  the facet you are on.

Links last until [`path clear`](/commands/path/clear/) or the script is started again.
[`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for bad arguments.

## Example

```euo
path link 1500 1600 0 1700 1600 0      ; a teleporter, and where it leads
path find 1720 1600
for %i 1 #PathCnt
{
  path get %i
  if #PathDir = 8
    event SysMessage Step %i uses the teleporter
}
halt
```
