---
title: "Move"
description: "Walks towards a position without pathfinding, like `move`."
kind: dll-method
category: method
syntax: "Call Move x y\nCall Move x y tolerance\nCall Move x y tolerance timeout"
needsClient: true
related: ["Move", "dll:Pathfind"]
aliases: ["UO.Move"]
---

Walks towards a position without pathfinding, like `move`. Default tolerance: 0. `timeout` is in milliseconds; without it, there is none.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `tolerance` | number | Tiles away that count as arrived. |
| `timeout` | number | Milliseconds before giving up. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `arrived` | boolean | True when the character got there. |
