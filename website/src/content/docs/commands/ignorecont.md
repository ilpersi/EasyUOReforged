---
title: "IgnoreCont"
description: "Makes the #Cont… variables skip a gump, by name or kind; reset empties the list."
kind: command
category: client
syntax: "ignorecont {gump name|gump kind|reset}"
needsClient: true
related: ["#ContName", "#ContKind", "event ContTop", "ContPos"]
aliases: ["ignore container", "ignore gump"]
dll: IgnoreCont
---

The `#Cont…` variables ([`#ContName`](/variables/contname/), [`#ContKind`](/variables/contkind/),
[`#ContPosX`](/variables/contposx/), …) describe the gump on top of the client's screen. `IgnoreCont` adds a
gump to the list of gumps they skip, so the variables describe the next one down instead. It works the same
for [`event ContTop`](/commands/event/conttop/), which counts gumps the same way.

## Parameters

| Parameter | Meaning |
|---|---|
| gump name | The name as [`#ContName`](/variables/contname/) shows it, for example `status_gump` (a health bar). Case does not matter; spaces and `_` are the same. |
| gump kind | The value of [`#ContKind`](/variables/contkind/) for that kind of gump. |
| `reset` | Empties the list. |

Some gumps are on the list from the start, because scripts almost never mean them: `BARK_GUMP`,
`DAMAGENUMBERS_GUMP`, `DUMB_GUMP`, `GAMEAREAEDGEGUMP`, `MAP_GUMP`, `MENUBAR`, `MISSILE_GUMP`,
`NEW_ITEM_PROP_GUMP`, `RETICLE_GUMP`, `TARGET_GUMP` and `UNICODE_BARK_GUMP`. **`ignorecont reset` removes
these too**, so after it `#ContName` can report, for example, the menu bar.

## Example

```euo
; don't let health bars count as the top gump
ignorecont status_gump

; or ignore whatever kind of gump is on top right now
ignorecont #ContKind
```
