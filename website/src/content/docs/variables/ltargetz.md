---
title: "#LTargetZ"
description: "Returns the world z-coordinate of the last target used."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
source: wiki
---

The #lTargetZ system variable determines the world z-coordinate of the last target used.

:::note
[#lTargetKind](/variables/ltargetkind/) must be set to 2 or 3 for event Macro 22 to use the target position.
:::

## Example

```euo
; use the shovel
set #lObjectID %shovel
event Macro 17

; wait for target cursor
target 5s

; mine a spot
set #lTargetX 1000
set #lTargetY 1000
set #lTargetZ -1
set #lTargetKind 3
event Macro 22
...
```
