---
title: "FilterItems"
description: "Narrows the list `ScanItems` made, and returns how many items are left."
kind: dll-method
category: method
syntax: "Call FilterItems filter\nCall FilterItems filter value"
needsClient: true
related: ["FindItem", "dll:ScanItems", "dll:GetItem"]
aliases: ["UO.FilterItems"]
---

Narrows the list `ScanItems` made, and returns how many items are left. Filters add up until cleared:

| `filter` | `value` | Keeps |
|---|---|---|
| 0 | | Clears every filter. |
| 1 | item ID | Items with that ID; several add up. |
| 2 | item type | Items of that type; several add up. |
| 3 | container ID | Items in that container; without a value, in any container. |
| 4 | distance | Items on the ground within that distance; without a value, anywhere on the ground. |

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `filter` | number | Filter number, see above. |
| `value` | number | Filter value. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `count` | number | How many items are left. |
