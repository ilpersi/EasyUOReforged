---
title: "PathAvoid"
description: "Marks the rectangle from `x`, `y` to `x2`, `y2` as a place routes should go round if they can, like `path avoid`."
kind: dll-method
category: method
syntax: "Call PathAvoid x y x2 y2 cost\nCall PathAvoid x y x2 y2 cost facet"
needsClient: true
related: ["path avoid", "dll:GetPath"]
aliases: ["UO.PathAvoid"]
---

Marks the rectangle from `x`, `y` to `x2`, `y2` as a place routes should go round if they can, like `path avoid`. `cost` is what each step in it costs on top.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `x2` | number | X of the opposite corner, or of the other end. |
| `y2` | number | Y of the opposite corner, or of the other end. |
| `cost` | number | Extra cost, in hundredths of a step. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or `error: …`. |
