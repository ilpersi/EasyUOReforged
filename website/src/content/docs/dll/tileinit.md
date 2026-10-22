---
title: "TileInit"
description: "Loads the map files of the attached client, like `tile init`."
kind: dll-method
category: method
syntax: "Call TileInit\nCall TileInit nooverrides"
needsClient: true
related: ["Tile", "dll:TileCnt"]
aliases: ["UO.TileInit"]
---

Loads the map files of the attached client, like `tile init`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `nooverrides` | boolean | Skip `verdata.mul`. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `done` | boolean | False when the client folder was not found. |
