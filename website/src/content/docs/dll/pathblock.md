---
title: "PathBlock"
description: "Marks a tile, or the rectangle from `x`, `y` to `x2`, `y2`, as a place routes must never use, like `path block`."
kind: dll-method
category: method
syntax: "Call PathBlock x y\nCall PathBlock x y facet\nCall PathBlock x y x2 y2\nCall PathBlock x y x2 y2 facet"
needsClient: true
related: ["path block", "dll:PathUnblock", "dll:GetPath"]
aliases: ["UO.PathBlock"]
---

Marks a tile, or the rectangle from `x`, `y` to `x2`, `y2`, as a place routes must never use, like `path block`.

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
