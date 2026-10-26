---
title: "path Clear"
description: "Forgets the path blocks, avoid areas, links and refused places, or one kind of them."
kind: subcommand
category: path
syntax: "path clear [blocks|avoid|links|learned|all]"
origin: reforged
sets: ["#PathState"]
related: ["path block", "path avoid", "path link", "path go"]
---

`path clear` removes every [`path block`](/commands/path/block/) (`blocks`), every
[`path avoid`](/commands/path/avoid/) area (`avoid`) or every [`path link`](/commands/path/link/) (`links`),
on every facet. `learned` forgets the places where a walk had a step refused, which the walker otherwise
avoids for a while (see [`path go`](/commands/path/go/#how-it-walks)). Without a word, or with `all`, it
removes all four. The options of [`path set`](/commands/path/set/) are not touched.

Starting the script again clears them too. [`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for
an unknown word.

## Example

```euo
path clear links
```
