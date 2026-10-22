---
title: "OpenClient"
description: "Starts another client, like `uoxl new`."
kind: dll-method
category: method
syntax: "Call OpenClient switch"
needsClient: true
related: ["UOXL", "dll:CloseClient"]
aliases: ["UO.OpenClient"]
---

Starts another client, like `uoxl new`. With `switch` true, the handle then drives the new client.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `switch` | boolean | Drive the new client afterwards. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `started` | boolean | True when the client was started. |
