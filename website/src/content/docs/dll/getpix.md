---
title: "GetPix"
description: "Reads the colour of a pixel of the client window."
kind: dll-method
category: method
syntax: "Call GetPix x y"
needsClient: true
related: ["SavePix", "#PixCol"]
aliases: ["UO.GetPix"]
---

Reads the colour of a pixel of the client window.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `x` | number | X position. |
| `y` | number | Y position. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `colour` | number | In `$BBGGRR` order. |

:::note
The client window has to be visible.
:::
