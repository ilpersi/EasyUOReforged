---
title: "PathCan"
description: "Says whether a character can stand at `x`, `y`, like `path can`."
kind: dll-method
category: method
syntax: "Call PathCan x y\nCall PathCan x y z"
needsClient: true
related: ["path can", "dll:GetPath"]
aliases: ["UO.PathCan"]
---

Says whether a character can stand at `x`, `y`, like `path can`. Default height: your own.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, `blocked`, `noclient`, `nomap` or `error: …`. |
| `z` | number | The height a character would stand at, the floor nearest `z`; 0 when it can't. |
