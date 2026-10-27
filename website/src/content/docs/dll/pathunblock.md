---
title: "PathUnblock"
description: "Removes the blocks that overlap a tile or a rectangle, like `path unblock`."
kind: dll-method
category: method
syntax: "Call PathUnblock x y\nCall PathUnblock x y facet\nCall PathUnblock x y x2 y2\nCall PathUnblock x y x2 y2 facet"
needsClient: true
related: ["path unblock", "dll:PathBlock"]
aliases: ["UO.PathUnblock"]
---

Removes the blocks that overlap a tile or a rectangle, like `path unblock`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |
| `x2` | number | X of the opposite corner, or of the other end. |
| `y2` | number | Y of the opposite corner, or of the other end. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or `error: …`. |
