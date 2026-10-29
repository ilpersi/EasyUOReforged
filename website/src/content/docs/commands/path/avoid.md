---
title: "path Avoid"
description: "Marks an area routes should go around if they can: a guarded zone, a spawn."
kind: subcommand
category: path
syntax: "path avoid {x} {y} {x2} {y2} {cost} [facet]"
origin: reforged
sets: ["#PathState"]
related: ["path block", "path clear"]
---

`path avoid` makes every step that ends in the rectangle from `x`, `y` to `x2`, `y2` cost more for
[`path find`](/commands/path/find/). `cost` is in hundredths of a step: with `500`, a step inside counts as
six. The route goes around the area when the detour is shorter than that, and still crosses it when there
is no other way, unlike [`path block`](/commands/path/block/).

`facet` is a number as in [`#CursKind`](/variables/curskind/); the default is the facet you are on. Areas
that overlap add up. They last until [`path clear`](/commands/path/clear/) or the script is started again.
[`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for bad arguments.

## Example

```euo
path avoid 1380 1500 1420 1560 1000   ; keep away from a monster spawn
path find 1434 1699
display ok #PathState - #PathCnt steps
halt
```
