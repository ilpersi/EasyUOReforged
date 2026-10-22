---
title: "GetCont"
description: "Describes one open gump, counted from the top (0), skipping the ignored ones."
kind: dll-method
category: method
syntax: "Call GetCont index"
needsClient: true
related: ["#ContName", "IgnoreCont", "dll:ContTop"]
aliases: ["UO.GetCont"]
---

Describes one open gump, counted from the top (0), skipping the ignored ones. Returns nil when there is no such gump.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `name` | string | Gump name, as `#ContName` but with spaces. |
| `x` | number | Left edge, in pixels. |
| `y` | number | Top edge, in pixels. |
| `width` | number | In pixels. |
| `height` | number | In pixels. |
| `kind` | number | As `#ContKind`, as a number. |
| `id` | number | Item the gump belongs to; 0 for none. |
| `type` | number | Its type. |
| `hp` | number | Health in percent, for a health bar. |
