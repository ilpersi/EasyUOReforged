---
title: "#PathDir"
description: "Direction of a step of the planned route, 0 (north) to 7, or 8 for a link."
kind: variable
category: path
access: ro
type: number
origin: reforged
related: ["#PathX", "path get", "path link", "#CharDir"]
---

`#PathDir` is the direction of a step of the planned route, numbered as [`#CharDir`](/variables/chardir/):

| Value | Direction | Value | Direction |
|---|---|---|---|
| 0 | North | 4 | South |
| 1 | North-east | 5 | South-west |
| 2 | East | 6 | West |
| 3 | South-east | 7 | North-west |

`8` marks a step through a [`path link`](/commands/path/link/) (a teleporter, a gate). `-1` means there is
no step: before any route, when the route has no steps, or after [`path can`](/commands/path/can/).

See [`#PathX`](/variables/pathx/) for which step it is after each `path` command.

:::note
[`event Macro 5`](/commands/event/macro/) (walk) numbers directions differently: its `0` is north-west. Add
1 to `#PathDir`, and take 8 back to 0, to get the macro's number.
:::

## Example

```euo
path find 1823 2821
path get 1
display ok The first step goes #PathDir
halt
```
