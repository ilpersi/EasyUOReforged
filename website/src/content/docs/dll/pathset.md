---
title: "PathSet"
description: "Changes a planning option, like `path set`: `accuracy`, `accuracyz`, `maxnodes`, `timeout`, `margin`, `turncost`, `heuristic`, `doorcost`, `difs`, `mobiles` or `doors`."
kind: dll-method
category: method
syntax: "Call PathSet option value\nCall PathSet option value"
needsClient: true
related: ["path set", "dll:GetPath"]
aliases: ["UO.PathSet"]
---

Changes a planning option, like `path set`: `accuracy`, `accuracyz`, `maxnodes`, `timeout`, `margin`, `turncost`, `heuristic`, `doorcost`, `difs`, `mobiles` or `doors`. `value` is a number, or a word for `difs`, `mobiles` and `doors`. `timeout` is in milliseconds here. The walking options are refused: uo.dll doesn't walk.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `option` | string | Option name, as for `path set`. |
| `value` | string | Filter value. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or `error: …`. |
