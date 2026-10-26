---
title: "#PathZ"
description: "Height of a step of the planned route, or where path can found a place to stand."
kind: variable
category: path
access: ro
type: number
origin: reforged
related: ["#PathX", "#PathY", "path can", "#CharPosZ"]
---

`#PathZ` is the height a character stands at after a step of the planned route, as
[`#CharPosZ`](/variables/charposz/) would show it there. See [`#PathX`](/variables/pathx/) for which step
it is after each `path` command. After [`path can`](/commands/path/can/) it is the height of the place to
stand that was found, `0` when there is none.

Give it to [`event PathFind`](/commands/event/pathfind/), which needs the right height to walk upstairs.

## Example

```euo
path get 10
event PathFind #PathX #PathY #PathZ
```
