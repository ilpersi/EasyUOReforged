---
title: "#FindDist"
description: "Distance in tiles to the object FindItem selected, for objects on the ground."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
related: ["#FindX", "#FindKind", "FindItem"]
aliases: ["distance", "range"]
source: wiki
---

`#FindDist` is how many tiles away the object is: the larger of the X and Y distance, the way UO measures
range. It describes the object [`FindItem`](/commands/finditem/) selected, at the current
[`#FindIndex`](/variables/findindex/). It is worked out from your position when you read it, so it changes as you walk.

It reads `N/A` for an object in a container, and when nothing was found.

## Example

```euo
finditem POF G_15
if #FindCnt > 0
  display ok Gold #FindDist tiles away.
```
