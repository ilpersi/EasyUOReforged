---
title: "#FindZ"
description: "Returns the z-coordinate of the object returned by findItem."
kind: variable
category: finditem
access: ro
type: number
needsClient: true
source: wiki
---

The #findZ system variable contains the z-coordinate of the object returned by [findItem](/commands/finditem/). If [#findKind](/variables/findkind/) equals 0, the coordinate is a screen coordinate, if [#findKind](/variables/findkind/) equals 1, the coordinate is a world coordinate.

## Example
