---
title: "Drag"
description: "Picks up an item through the server, like `exevent Drag`."
kind: dll-method
category: method
syntax: "Call Drag id\nCall Drag id amount"
needsClient: true
related: ["exevent Drag", "dll:CliDrag", "dll:DropC"]
aliases: ["UO.Drag"]
---

Picks up an item through the server, like `exevent Drag`. Default amount: 1.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `id` | number | Object ID, as a number. |
| `amount` | number | How many to take from a stack. |

## Returns

Nothing.
