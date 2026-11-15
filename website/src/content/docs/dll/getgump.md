---
title: "GetGump"
description: "Reads one window of the list `ScanGumps` made, counted from the front (0)."
kind: dll-method
category: method
syntax: "Call GetGump index"
needsClient: true
related: ["ScanGumps", "#GumpTypeID", "dll:ScanGumps"]
aliases: ["UO.GetGump"]
---

Reads one window of the list `ScanGumps` made, counted from the front (0). A value a script reads as `N/A` is nil in its slot, so there are always eleven values. Returns a single nil when there is no such window.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `index` | number | Position in the list, counting from 0. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `name` | string | The client's name for the window, as `#GumpName` but with spaces. |
| `kind` | number | As `#GumpKind`, as a number. |
| `x` | number | Left edge, in pixels. |
| `y` | number | Top edge, in pixels. |
| `width` | number | In pixels. |
| `height` | number | In pixels. |
| `object` | number | The container or character the window belongs to; nil for none. |
| `art` | number | The window's graphic; nil for none. |
| `minimized` | boolean | True when minimized; nil where it is not known. |
| `serial` | number | Server gumps only, nil otherwise: new each time the server opens it. |
| `typeid` | number | Server gumps only, nil otherwise: which gump it is, the same every time. |
