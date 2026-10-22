---
title: "Event"
description: "Makes the client do something with its own internal functions: macros, dragging, messages and more."
kind: command
category: event
syntax: "event {type} [parameters...]"
needsClient: true
related: ["ExEvent", "event Macro"]
aliases: ["client macro"]
source: wiki
---

`event` makes the client do something by calling its own internal functions, as if you had done it in the
client yourself: run one of its macros, pick up an item, show a message, walk to a spot. Because the client
does the work, what it shows stays in step with what it does.

| Command | What it does |
|---|---|
| [event ContTop](/commands/event/conttop/) | Brings a gump to the front. |
| [event Drag](/commands/event/drag/) | Picks up an item, as if dragged with the mouse. |
| [event ExMsg](/commands/event/exmsg/) | Shows a message above an object. |
| [event Macro](/commands/event/macro/) | Runs one of the client's built-in macros. |
| [event PathFind](/commands/event/pathfind/) | Walks to a nearby spot, finding a way around obstacles. |
| [event Property](/commands/event/property/) | Reads an item's property tooltip into `#Property`. |
| [event SkillLock](/commands/event/skilllock/) | Sets a skill's lock; the same as `exevent SkillLock`. |
| [event Sleep](/commands/event/sleep/) | Not implemented in EasyUO Reforged. |
| [event StatBar](/commands/event/statbar/) | Opens a character's health bar. |
| [event SysMessage](/commands/event/sysmessage/) | Shows a system message in the client. |

Every `event` type needs at least one parameter after it.

Each one calls a function inside the client. On a client version where that function's address is not
known, the command does nothing rather than risk the client. [`exevent`](/commands/exevent/) commands work
differently: they send packets to the server directly.
