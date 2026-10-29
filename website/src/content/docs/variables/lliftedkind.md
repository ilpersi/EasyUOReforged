---
title: "#LLiftedKind"
description: "1 while something hangs on the cursor, 0 otherwise."
kind: variable
category: lastaction
access: ro
type: number
needsClient: true
related: ["#LLiftedID", "event Drag"]
aliases: ["holding", "on cursor"]
dll: LLiftedKind
source: wiki
---

`#LLiftedKind` is `1` while an object hangs on the cursor (picked up and not dropped yet) and `0` otherwise.
[`event Drag`](/commands/event/drag/) does nothing while it is `1`.

## Example

```euo
set %item ABCDEFG            ; the ID of an item in your backpack
event Drag %item
wait 10
if #LLiftedKind = 0
  display ok The pick-up failed.
halt
```
