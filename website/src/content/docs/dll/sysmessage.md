---
title: "SysMessage"
description: "Shows a system message in the client, like `event SysMessage`."
kind: dll-method
category: method
syntax: "Call SysMessage text\nCall SysMessage text colour"
needsClient: true
related: ["event SysMessage", "dll:ExMsg"]
aliases: ["UO.SysMessage"]
---

Shows a system message in the client, like `event SysMessage`. Default colour: 0.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `text` | string | The text. |
| `colour` | number | Colour (hue) number. |

## Returns

Nothing.
