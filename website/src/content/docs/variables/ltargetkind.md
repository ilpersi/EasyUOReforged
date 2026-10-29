---
title: "#LTargetKind"
description: "What the last target was: 1 object, 2 ground, 3 resource such as a tree or water."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
related: ["#LTargetID", "#LTargetX", "#LTargetTile", "event Macro"]
aliases: ["target kind"]
dll: LTargetKind
source: wiki
---

`#LTargetKind` is what kind of thing was targeted last, and what [`event Macro 22`](/commands/event/macro/)
(*Last Target*) will target:

| Value | Target | Uses |
|---|---|---|
| `1` | An object | [`#LTargetID`](/variables/ltargetid/) |
| `2` | The ground, mountains, caves | [`#LTargetX`](/variables/ltargetx/), [`#LTargetY`](/variables/ltargety/), [`#LTargetZ`](/variables/ltargetz/) |
| `3` | A resource on the map: tree, water | The position, and [`#LTargetTile`](/variables/ltargettile/) |

**Set it every time before `event Macro 22`.** Leaving it as it was is one of the most common causes of
targeting going wrong now and then.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.

## Example

```euo
; teleport to a spot on the ground
event Macro 15 21            ; cast Teleport
target 5s
set #LTargetX 1000
set #LTargetY 1000
set #LTargetZ 0
set #LTargetKind 2
event Macro 22 0
halt
```
