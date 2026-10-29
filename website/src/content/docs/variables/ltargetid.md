---
title: "#LTargetID"
description: "ID of the last object targeted; set it, then event Macro 22 targets that object."
kind: variable
category: lastaction
access: rw
type: id
needsClient: true
related: ["#LTargetKind", "#LObjectID", "Target", "event Macro"]
aliases: ["last target", "target object"]
dll: LTargetID
source: wiki
---

`#LTargetID` is the ID of the object you targeted last. To target any object from a script: wait for the
target cursor, set `#LTargetID` and [`#LTargetKind`](/variables/ltargetkind/) `1`, then run
[`event Macro 22`](/commands/event/macro/) (*Last Target*).

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.

## Example

```euo
; carve a corpse with a dagger
finditem TSF C_ , #BackpackID    ; a dagger
set %dagger #FindID
finditem YFM G_2                 ; a corpse next to you
set %corpse #FindID
set #LObjectID %dagger
event Macro 17 0
target 5s
set #LTargetID %corpse
set #LTargetKind 1
event Macro 22 0
halt
```
