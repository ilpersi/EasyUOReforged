---
title: "path Unblock"
description: "Removes the path blocks that cover a place or a rectangle."
kind: subcommand
category: path
syntax: "path unblock {x} {y} [{x2} {y2}] [facet]"
origin: reforged
sets: ["#PathState"]
related: ["path block", "path clear"]
---

`path unblock` removes every [`path block`](/commands/path/block/) that covers the place `x`, `y`, or any
place of the rectangle from `x`, `y` to `x2`, `y2`. A block is removed whole, also where it reaches beyond
the rectangle.

`facet` is a number as in [`#CursKind`](/variables/curskind/); the default is the facet you are on.
[`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for bad arguments.

## Example

```euo
path block 1450 1680 1460 1690
path unblock 1455 1685           ; removes the whole block above
halt
```
