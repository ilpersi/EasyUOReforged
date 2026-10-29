---
title: "path Get"
description: "Loads one step of the last planned route into #PathX, #PathY, #PathZ and #PathDir."
kind: subcommand
category: path
syntax: "path get {n}"
origin: reforged
sets: ["#PathState", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path find", "#PathCnt"]
---

`path get` loads step `n` (from `1` to [`#PathCnt`](/variables/pathcnt/)) of the route the last
[`path find`](/commands/path/find/) planned: [`#PathX`](/variables/pathx/), [`#PathY`](/variables/pathy/) and
[`#PathZ`](/variables/pathz/) are where the step ends, [`#PathDir`](/variables/pathdir/) the direction it
goes in.

A number out of range sets all four to `0` (`#PathDir` to `-1`) and [`#PathState`](/variables/pathstate/)
to `error: no step …`.

## Example

```euo
path find 1600 1690
for %i 1 #PathCnt
{
  path get %i
  if #PathZ > 10
    event SysMessage Step %i goes up to #PathZ
}
halt
```
