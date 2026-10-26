---
title: "path Clear"
description: "Forgets the path blocks, avoid areas and links, or one kind of them."
kind: subcommand
category: path
syntax: "path clear [blocks|avoid|links|all]"
origin: reforged
sets: ["#PathState"]
related: ["path block", "path avoid", "path link"]
---

`path clear` removes every [`path block`](/commands/path/block/) (`blocks`), every
[`path avoid`](/commands/path/avoid/) area (`avoid`) or every [`path link`](/commands/path/link/) (`links`),
on every facet. Without a word, or with `all`, it removes all three. The options of
[`path set`](/commands/path/set/) are not touched.

Starting the script again clears them too. [`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for
an unknown word.

## Example

```euo
path clear links
```
