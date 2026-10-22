---
title: "BlockInfo"
description: "Reads the client's walkability data for an area of up to 32×32 tiles starting at `x`, `y`, `z`."
kind: dll-method
category: method
syntax: "Call BlockInfo x y z width height"
needsClient: true
related: ["event PathFind"]
aliases: ["UO.BlockInfo"]
---

Reads the client's walkability data for an area of up to 32×32 tiles starting at `x`, `y`, `z`. Meant for pathfinding tools; the two bytes per tile are in the client's own format. On a client whose function address is unknown, every byte is 0.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `width` | number | Width in tiles. |
| `height` | number | Height in tiles. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `data` | string | Two bytes per tile, `width × height × 2` bytes in all. |
