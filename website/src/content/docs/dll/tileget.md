---
title: "TileGet"
description: "Reads one tile at a map position, like `tile get`; `layer` counts from 1."
kind: dll-method
category: method
syntax: "Call TileGet x y layer\nCall TileGet x y layer facet"
needsClient: true
related: ["Tile", "#TileFlags", "dll:TileCnt"]
aliases: ["UO.TileGet"]
---

Reads one tile at a map position, like `tile get`; `layer` counts from 1.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `layer` | number | Which tile, counting from 1. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `type` | number | Graphic number. |
| `z` | number | Height. |
| `name` | string | Name, such as `tree` or `water`. |
| `flags` | number | The flags as one number, one bit each, in the order `#TileFlags` lists. |
