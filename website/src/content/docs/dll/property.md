---
title: "Property"
description: "Reads the property tooltip of an object, like `event Property`."
kind: dll-method
category: method
syntax: "Call Property id"
needsClient: true
related: ["event Property", "#Property"]
aliases: ["UO.Property"]
---

Reads the property tooltip of an object, like `event Property`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `id` | number | Object ID, as a number. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `name` | string | First tooltip line. |
| `properties` | string | The other lines. |
