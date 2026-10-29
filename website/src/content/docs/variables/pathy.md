---
title: "#PathY"
description: "Y position of a step of the planned route: the last one after path find, step n after path get."
kind: variable
category: path
access: ro
type: number
origin: reforged
related: ["#PathX", "#PathZ", "#PathDir", "path get"]
---

`#PathY` is the Y position of a step of the planned route. See [`#PathX`](/variables/pathx/) for which
step it is after each `path` command.

## Example

```euo
path find 1434 1699
path get 1
display ok First step: #PathX #PathY
halt
```
