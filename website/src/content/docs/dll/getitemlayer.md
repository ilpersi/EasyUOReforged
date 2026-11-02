---
title: "GetItemLayer"
description: "Reads the equip layer of one item of the filtered list, as `#FindLayer`."
kind: dll-method
category: method
syntax: "Call GetItemLayer index"
needsClient: true
related: ["FindItem", "#FindLayer", "dll:GetItem", "dll:ScanItems"]
aliases: ["UO.GetItemLayer"]
---

Reads the equip layer of one item of the filtered list, as `#FindLayer`. It is the layer number in which a character wears the item (21 backpack, 25 mount, …; the table is on [`#FindLayer`](/variables/findlayer/)), or 0 when the item lies in a container or on the ground, or when there is no such item. A call of its own, so `GetItem`'s results stay as they were.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `layer` | number | The layer a character wears it in, as `#FindLayer`; 0 when nobody wears it. |
