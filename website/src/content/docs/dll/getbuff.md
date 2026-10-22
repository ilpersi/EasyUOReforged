---
title: "GetBuff"
description: "Reads one buff of the list `ScanBuffs` made."
kind: dll-method
category: method
syntax: "Call GetBuff index"
needsClient: true
related: ["ScanBuffs", "#BuffID", "dll:ScanBuffs"]
aliases: ["UO.GetBuff"]
---

Reads one buff of the list `ScanBuffs` made. Returns nil (nothing) when there is no such buff.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `id` | number | Icon ID. |
| `cliloc` | number | Cliloc number of the title. |
| `name` | string | Title. |
| `description` | string | Second tooltip line. |
| `seconds` | number | Seconds left; -1 = no timer. |
