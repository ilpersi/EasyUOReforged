---
title: "path Block"
description: "Marks a place or a rectangle that routes must never use."
kind: subcommand
category: path
syntax: "path block {x} {y} [{x2} {y2}] [facet]"
origin: reforged
sets: ["#PathState"]
related: ["path unblock", "path avoid", "path clear"]
aliases: ["obstacle"]
---

`path block` marks the place `x`, `y`, or the rectangle from `x`, `y` to `x2`, `y2`, as impassable for
[`path find`](/commands/path/find/), at every height. Use it for what the map files don't know about: a
player house, a locked door, a spot where you got stuck.

`facet` is a number as in [`#CursKind`](/variables/curskind/); the default is the facet you are on. A
diagonal step that would brush past a blocked place is not taken either, as with a wall.

Blocks last until [`path unblock`](/commands/path/unblock/), [`path clear`](/commands/path/clear/) or the
script is started again. [`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for bad arguments.

## Example

```euo
path block 1450 1680 1460 1690   ; a house on the way
path find 1500 1690
```
