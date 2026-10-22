---
title: "#LLiftedID"
description: "ID of the object last picked up (dragged)."
kind: variable
category: lastaction
access: ro
type: id
needsClient: true
related: ["#LLiftedKind", "#LLiftedType", "event Drag"]
aliases: ["dragged item"]
source: wiki
---

`#LLiftedID` is the ID of the object you picked up (dragged) last, with the mouse or with
[`event Drag`](/commands/event/drag/). [`#LLiftedKind`](/variables/lliftedkind/) tells whether it is still on
the cursor.

## Example

```euo
event Drag %item
wait 20
event SysMessage You picked up #LLiftedID
```
