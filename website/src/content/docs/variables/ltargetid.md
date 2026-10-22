---
title: "#LTargetID"
description: "Returns the id of the last target used."
kind: variable
category: lastaction
access: rw
type: id
needsClient: true
source: wiki
---

The #lTargetID system variable determines the id of the last target used. You can also write to this variable and use it in conjuction with "event Macro 22" (LastTarget), which will target the object as if it was clicked with the mouse.

:::note
[#lTargetKind](/variables/ltargetkind/) must be set to 2 or 3 for event Macro 22 to use the target position.
:::

## Example

```euo
; use the dagger
set #lObjectID %dagger
event Macro 17

; wait for target cursor
target 5s

; carve the hides from the corpse
set #lTargetID %cowCorpse
set #lTargetKind 1 ; make sure it targets an object
event Macro 22
...
```
