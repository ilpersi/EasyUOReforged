---
title: "ScanGumps"
description: "Lists the open gump windows, front to back, like `scangumps`."
kind: dll-method
category: method
syntax: "Call ScanGumps\nCall ScanGumps filter"
needsClient: true
related: ["ScanGumps", "dll:GetGump"]
aliases: ["UO.ScanGumps"]
---

Lists the open gump windows, front to back, like `scangumps`. `filter` is the same text the script takes, for example `'T_JHEIIPI'` or `'A_YE'`. Read them with `GetGump`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `filter` | string | Filter number, see above. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `count` | number | How many windows. |
