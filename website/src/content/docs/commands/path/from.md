---
title: "path From"
description: "Plans routes from another place instead of your character's position."
kind: subcommand
category: path
syntax: "path from [{x} {y} {z} [facet]]"
origin: reforged
sets: ["#PathState"]
related: ["path find", "path can"]
---

`path from` makes [`path find`](/commands/path/find/) and [`path can`](/commands/path/can/) start from `x`,
`y`, `z` on `facet` instead of from your character, until the next `path from`. Without arguments, they
start from your character again. `facet` is a number as in [`#CursKind`](/variables/curskind/); the default
is the facet you are on.

Use it to plan a route before going there, for example to check that a list of places can all be reached.
A client must still be attached: the map is read from its files.

## Example

```euo
path from 1434 1699 0          ; the Britain bank
path find 1823 2821            ; to Trinsic
display ok Britain to Trinsic: #PathCnt steps
path from
halt
```
