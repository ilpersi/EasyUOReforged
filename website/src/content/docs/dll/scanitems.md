---
title: "ScanItems"
description: "Makes a fresh list of the items and characters the client knows, like the first step of `finditem`."
kind: dll-method
category: method
syntax: "Call ScanItems\nCall ScanItems visibleonly"
needsClient: true
related: ["FindItem", "dll:FilterItems", "dll:GetItem"]
aliases: ["UO.ScanItems"]
---

Makes a fresh list of the items and characters the client knows, like the first step of `finditem`. Default: visible ones only; with `visibleonly` false, hidden ones too (the `A` filter). Narrow it with `FilterItems`, read it with `GetItem`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `visibleonly` | boolean | False to include hidden items. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `count` | number | How many items. |
