---
title: "Pathfind"
description: "Walks to a nearby position with the client's pathfinding, like `event PathFind`."
kind: dll-method
category: method
syntax: "Call Pathfind x y\nCall Pathfind x y z"
needsClient: true
related: ["event PathFind", "dll:Move"]
aliases: ["UO.Pathfind"]
---

Walks to a nearby position with the client's pathfinding, like `event PathFind`. Default height: your own.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |

## Returns

Nothing.
