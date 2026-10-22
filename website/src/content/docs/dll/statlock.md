---
title: "StatLock"
description: "Sets a stat's lock, like `exevent StatLock`: `stat` is `str`, `dex` or `int`; `lock` 0 up, 1 down, 2 locked."
kind: dll-method
category: method
syntax: "Call StatLock stat lock"
needsClient: true
related: ["exevent StatLock"]
aliases: ["UO.StatLock"]
---

Sets a stat's lock, like `exevent StatLock`: `stat` is `str`, `dex` or `int`; `lock` 0 up, 1 down, 2 locked.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `stat` | string | `str`, `dex` or `int`. |
| `lock` | number | 0 up, 1 down, 2 locked. |

## Returns

Nothing.
