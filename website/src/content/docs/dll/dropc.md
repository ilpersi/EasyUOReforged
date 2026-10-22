---
title: "DropC"
description: "Drops the item last dragged into a container, or onto a stack, like `exevent DropC`."
kind: dll-method
category: method
syntax: "Call DropC container\nCall DropC container x y"
needsClient: true
related: ["exevent DropC", "dll:Drag"]
aliases: ["UO.DropC"]
---

Drops the item last dragged into a container, or onto a stack, like `exevent DropC`. Without `x` and `y` the server chooses the spot.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `container` | number | Container ID, or the ID of a stack to add to. |
| `x` | number | X position. |
| `y` | number | Y position. |

## Returns

Nothing.
