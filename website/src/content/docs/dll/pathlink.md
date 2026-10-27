---
title: "PathLink"
description: "Adds a teleporter, gate or ladder routes may use, from `x`, `y`, `z` to `x2`, `y2`, `z2` on the same facet, like `path link`."
kind: dll-method
category: method
syntax: "Call PathLink x y z x2 y2 z2\nCall PathLink x y z x2 y2 z2 cost\nCall PathLink x y z x2 y2 z2 cost facet"
needsClient: true
related: ["path link", "dll:GetPath"]
aliases: ["UO.PathLink"]
---

Adds a teleporter, gate or ladder routes may use, from `x`, `y`, `z` to `x2`, `y2`, `z2` on the same facet, like `path link`. Default cost: 100, one step.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `x2` | number | X of the opposite corner, or of the other end. |
| `y2` | number | Y of the opposite corner, or of the other end. |
| `z2` | number | Height of the other end. |
| `cost` | number | Extra cost, in hundredths of a step. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or `error: …`. |
