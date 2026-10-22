---
title: "Popup"
description: "Opens the context menu of an object, like `exevent PopUp`."
kind: dll-method
category: method
syntax: "Call Popup id\nCall Popup id x y"
needsClient: true
related: ["exevent PopUp"]
aliases: ["UO.Popup"]
---

Opens the context menu of an object, like `exevent PopUp`. Unlike the script command, `x` and `y` are used: they position the menu.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `id` | number | Object ID, as a number. |
| `x` | number | X position. |
| `y` | number | Y position. |

## Returns

Nothing.
