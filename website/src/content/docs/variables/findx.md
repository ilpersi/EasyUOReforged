---
title: "#FindX"
description: "Returns the x-coordinate of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findX system variable contains the x-coordinate of the object returned by [findItem](/commands/finditem/). If [#findKind](/variables/findkind/) equals 0, the coordinate is a screen coordinate, if [#findKind](/variables/findkind/) equals 1, the coordinate is a world coordinate.

## Example

```euo
.....
loop:
finditem %target
if #CHARPOSX <> #findx || #CHARPOSY <> #findy
{
move #findx #findy 0 0
goto loop
}
.....
```
