---
title: "TileCnt"
description: "Counts the tiles at a map position, like `tile cnt`."
kind: dll-method
category: method
syntax: "Call TileCnt x y\nCall TileCnt x y facet"
needsClient: true
related: ["Tile", "dll:TileGet"]
aliases: ["UO.TileCnt"]
---

Counts the tiles at a map position, like `tile cnt`. Call `TileInit` first.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `count` | number | Number of tiles there. |
