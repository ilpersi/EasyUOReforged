---
title: "PathCheck"
description: "Asks the client itself whether the character can step onto `x`, `y` in direction `dir` from the tile behind it, at height `z`, like `path check`: the check the client makes before every step, with everything it has loaded."
kind: dll-method
category: method
syntax: "Call PathCheck x y\nCall PathCheck x y z\nCall PathCheck x y z dir"
needsClient: true
related: ["path check", "dll:BlockInfo", "dll:GetPath"]
aliases: ["UO.PathCheck"]
---

Asks the client itself whether the character can step onto `x`, `y` in direction `dir` from the tile behind it, at height `z`, like `path check`: the check the client makes before every step, with everything it has loaded. Default height: your own. A tile the client hasn't loaded reads as blocked.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `dir` | number | Direction of the step, 0 north to 7 north-west, as `CharDir`. Default: 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, `blocked`, `noclient`, or `nocheck` when EasyUO Reforged doesn't know this client's check or the client didn't answer. |
| `z` | number | The height the step lands at; 0 when it is refused. |
