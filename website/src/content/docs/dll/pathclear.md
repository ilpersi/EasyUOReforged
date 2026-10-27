---
title: "PathClear"
description: "Forgets rules, like `path clear`."
kind: dll-method
category: method
syntax: "Call PathClear\nCall PathClear what"
needsClient: true
related: ["path clear", "dll:GetPath"]
aliases: ["UO.PathClear"]
---

Forgets rules, like `path clear`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `what` | string | `blocks`, `avoid`, `links`, `learned` or `all`. Default: `all`. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `state` | string | `ok`, or `error: …`. |
