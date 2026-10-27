---
title: "GetPath"
description: "Plans a walking route, like `path find`: from your character on its facet, or from `fromx`, `fromy`, `fromz` on `facet`, to `x`, `y` (with `z`, to the floor nearest that height)."
kind: dll-method
category: method
syntax: "Call GetPath x y\nCall GetPath x y z\nCall GetPath x y z fromx fromy fromz facet"
needsClient: true
related: ["path find", "dll:PathSet", "dll:PathCheck", "dll:Move"]
aliases: ["UO.GetPath"]
---

Plans a walking route, like `path find`: from your character on its facet, or from `fromx`, `fromy`, `fromz` on `facet`, to `x`, `y` (with `z`, to the floor nearest that height). It reads the map files of the attached client and what the client holds around the character. It doesn't walk: walk the steps with `Move` or the walk macro. The options and rules set with `PathSet`, `PathBlock`, `PathAvoid` and `PathLink` apply. They belong to this uo.dll handle, not to the scripts in the editor.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `fromx` | number | X position to plan from. |
| `fromy` | number | Y position to plan from. |
| `fromz` | number | Height to plan from. |
| `facet` | number | Facet number, as in `CursKind`. Default: the current facet. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or why there is no route: `nopath`, `budget`, `timeout`, `noclient`, `nomap` or `error: …`, as `#PathState` after `path find`. |
| `count` | number | Steps in the route; 0 without one. |
| `steps` | string | Six bytes a step: x and y (2 bytes each, low byte first), the height (1 byte, signed) and the direction (1 byte: 0 north to 7 north-west, 8 a link). Empty without a route. |

:::note
Where EasyUO Reforged can't read the walls of player houses (every client but `client_beta.exe` 7.0.117.31), a route can run through a house. Before walking a step, `PathCheck` asks the client about it: the walker of `path go` does the same.
:::
