---
title: "#PathX"
description: "X position of a step of the planned route: the last one after path find, step n after path get."
kind: variable
category: path
access: ro
type: number
origin: reforged
related: ["#PathY", "#PathZ", "#PathDir", "path get"]
---

`#PathX` is the X position of a step of the planned route, with [`#PathY`](/variables/pathy/),
[`#PathZ`](/variables/pathz/) and [`#PathDir`](/variables/pathdir/):

- after [`path find`](/commands/path/find/), the last step: where the route ends;
- after [`path get`](/commands/path/get/) `n`, step `n`;
- after [`path can`](/commands/path/can/), the place checked.

## Example

```euo
path set accuracy 2
path find 1434 1699
event SysMessage The route ends at #PathX #PathY
```
