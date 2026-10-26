---
title: "path Can"
description: "Says whether a character can stand at a place, and at what height."
kind: subcommand
category: path
syntax: "path can {x} {y} [z]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathX", "#PathY", "#PathZ"]
related: ["path find", "Tile"]
aliases: ["walkable", "passable"]
---

`path can` checks whether a character can stand at `x`, `y` on the facet you are on: something to stand
on, enough head room above it, and not a [`path block`](/commands/path/block/)ed place.

[`#PathState`](/variables/pathstate/) is `ok` or `blocked` (or `noclient` / `nomap`, as for
[`path find`](/commands/path/find/)). [`#PathZ`](/variables/pathz/) is the height the character would stand
at: of the floors there, the one nearest to `z`. Without `z`, the nearest to your character's own height
(or to the height given to [`path from`](/commands/path/from/)). It doesn't check whether the place can be
reached.

## Example

```euo
path can 1434 1699
if #PathState = ok
  event SysMessage You can stand there, at height #PathZ
```
