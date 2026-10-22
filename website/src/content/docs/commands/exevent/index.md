---
title: "ExEvent"
description: "Sends actions straight to the server as packets: drag, drop, context menus, locks and more."
kind: command
category: exevent
syntax: "exevent {type} [parameters...]"
needsClient: true
related: ["Event", "exevent Drag"]
aliases: ["packet"]
source: wiki
---

`exevent` sends an action straight to the server as a packet, without going through the client's own
functions the way [`event`](/commands/event/) does. The client finds out about the result when the server
answers, so its display can lag behind for a moment.

| Command | What it does |
|---|---|
| [exevent Drag](/commands/exevent/drag/) | Picks up an item, or part of a stack. |
| [exevent DropC](/commands/exevent/dropc/) | Drops the held item into a container, or onto a stack. |
| [exevent DropG](/commands/exevent/dropg/) | Drops the held item on the ground. |
| [exevent DropPD](/commands/exevent/droppd/) | Puts the held item on, on your paperdoll. |
| [exevent Equip](/commands/exevent/equip/) | Equips one or more items in one request. |
| [exevent PopUp](/commands/exevent/popup/) | Opens the context menu of an item or character. |
| [exevent RenamePet](/commands/exevent/renamepet/) | Renames a pet. |
| [exevent SkillLock](/commands/exevent/skilllock/) | Sets the lock of a skill. |
| [exevent StatLock](/commands/exevent/statlock/) | Sets the lock of a stat. |

The usual way to move an item is `exevent Drag` followed by one of the `exevent Drop…` commands, with a
short `wait` in between.
