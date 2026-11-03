---
title: "GetItem"
description: "Reads one item of the filtered list, like the `#Find…` variables after `finditem`."
kind: dll-method
category: method
syntax: "Call GetItem index"
needsClient: true
related: ["FindItem", "#FindID", "#FindLayer", "dll:ScanItems", "dll:FilterItems"]
aliases: ["UO.GetItem"]
---

Reads one item of the filtered list, like the `#Find…` variables after `finditem`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `id` | number | Item or character ID. |
| `type` | number | Its type. |
| `kind` | number | 0 in a container, 1 on the ground, -1 none. |
| `container` | number | Container ID; 0 on the ground. |
| `x` | number | X position: in the world, or inside the container gump. |
| `y` | number | Y position. |
| `z` | number | Height. |
| `stack` | number | How many in the stack; 0 for characters. |
| `notoriety` | number | As `#FindRep`. |
| `colour` | number | Colour (hue). |
| `layer` | number | The layer a character wears it in, as `#FindLayer` (21 backpack, 25 mount, …); 0 when nobody wears it. |

:::note
The 11th value, `layer`, is new in EasyUO Reforged; the first ten are those of EasyUO 1.5, in the same order. The layer numbers are listed on [`#FindLayer`](/variables/findlayer/).
:::
