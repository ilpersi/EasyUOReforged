---
title: "ExMsg"
description: "Shows a message above an object, like `event ExMsg`."
kind: dll-method
category: method
syntax: "Call ExMsg id text\nCall ExMsg id font colour text"
needsClient: true
related: ["event ExMsg", "dll:SysMessage"]
aliases: ["UO.ExMsg"]
---

Shows a message above an object, like `event ExMsg`. The short form uses font 3 and colour 0.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `id` | number | Object ID, as a number. |
| `font` | number | Font number, as for `event ExMsg`. |
| `colour` | number | Colour (hue) number. |
| `text` | string | The text. |

## Returns

Nothing.
