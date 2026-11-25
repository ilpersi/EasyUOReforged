---
title: "GetGumpReply"
description: "Returns the last answer `GumpReply` sent through this handle, or, once the click hook is in the client (`GumpReply`, `GetGumpReply` and `GumpReplyCnt` put it there), the last one recorded, clicks by hand included."
kind: dll-method
category: method
syntax: "Call GetGumpReply"
needsClient: true
related: ["exevent GumpReply", "#GumpReply", "dll:GumpReply"]
aliases: ["UO.GetGumpReply"]
---

Returns the last answer `GumpReply` sent through this handle, or, once the click hook is in the client (`GumpReply`, `GetGumpReply` and `GumpReplyCnt` put it there), the last one recorded, clicks by hand included. A click made before the hook was in is not recorded. Nil when there is none yet.

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `typeid` | number | The gump's type ID. |
| `button` | number | The button. |
| `switches` | string | The switches that were on, as `3/7`; `-` for none. |
| `texts` | string | The text fields, as `5:hello_world 6:x`; empty for none. |
