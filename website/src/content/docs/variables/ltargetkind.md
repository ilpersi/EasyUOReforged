---
title: "#LTargetKind"
description: "Returns the kind of what was last targeted."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
source: wiki
---

The #LTargetKind system variable determines the class of object that was last targeted. The possible values of this variable are listed in the table below.

| Setting | Object Class           |
|---------|------------------------|
| 1       | Object                 |
| 2       | Ground,Mountains,Caves |
| 3       | Resource: Tree,Water   |

LTargetKind Values

:::note
Not setting #LTargetKind (usually to 1) is by far one of the most common mistakes made when scripting. Simply put, every time that you use Event Macro 22 you must *always* make sure #LTargetKind is set properly or you will most likely have sporadic targeting problems.
:::

## Object Example

```euo
; use the dagger
set #LObjectID %dagger
event Macro 17

; wait for target cursor
target 5s

; carve the hides from the corpse
set #LTargetID %cowCorpse
set #LTargetKind 1 ; make sure it targets an object
event Macro 22
...
```

## World Position Example

```euo
; use the shovel
set #LObjectID %shovel
event Macro 17

; wait for target cursor
target 5s

; mine a spot
set #LTargetX 1000
set #LTargetY 1000
set #LTargetZ -1
set #LTargetKind 3
event Macro 22
...
```
