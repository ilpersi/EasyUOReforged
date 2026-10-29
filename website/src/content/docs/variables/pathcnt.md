---
title: "#PathCnt"
description: "Number of steps of the route the last path find planned."
kind: variable
category: path
access: ro
type: number
origin: reforged
related: ["path find", "path get", "#PathState"]
aliases: ["path count", "path length"]
---

`#PathCnt` is the number of steps of the route the last [`path find`](/commands/path/find/) planned: the
steps [`path get`](/commands/path/get/) can load, from `1` to `#PathCnt`. It is `0` when no route was found
(see [`#PathState`](/variables/pathstate/)) and when you are already at the goal.

## Example

```euo
path find 1823 2821
display ok Trinsic is #PathCnt steps away
halt
```
