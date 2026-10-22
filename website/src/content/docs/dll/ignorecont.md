---
title: "IgnoreCont"
description: "Adds a gump to the ignore list, by name or by kind, like `ignorecont`."
kind: dll-method
category: method
syntax: "Call IgnoreCont name\nCall IgnoreCont kind"
needsClient: true
related: ["IgnoreCont", "dll:GetCont"]
aliases: ["UO.IgnoreCont"]
---

Adds a gump to the ignore list, by name or by kind, like `ignorecont`. With the number `0`, empties the list; with `-1`, restores the default list.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `name` | string | Name. |
| `kind` | number | Gump kind, as `#ContKind`, as a number. |

## Returns

Nothing.
