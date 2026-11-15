---
title: "GumpReply"
description: "Answers the open server gump of that type ID, like `exevent GumpReply`: the frontmost one, with the serial it has now, and closes its window."
kind: dll-method
category: method
syntax: "Call GumpReply typeid button\nCall GumpReply typeid button switches\nCall GumpReply typeid button switches texts"
needsClient: true
related: ["exevent GumpReply", "dll:GetGumpReply", "dll:ScanGumps"]
aliases: ["UO.GumpReply"]
---

Answers the open server gump of that type ID, like `exevent GumpReply`: the frontmost one, with the serial it has now, and closes its window. `switches` and `texts` are written as the script writes them: `3/7` (or `-`) and `5:hello_world 6:x`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `typeid` | number |  |
| `button` | number |  |
| `switches` | string |  |
| `texts` | string |  |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `result` | string | `sent`, `nogump` (no such gump open: nothing sent) or `error`. |
