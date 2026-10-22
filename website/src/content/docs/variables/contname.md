---
title: "#ContName"
description: "Name of the gump on top, such as container_gump or paperdoll_gump."
kind: variable
category: container
access: ro
type: string
needsClient: true
related: ["#ContKind", "#ContID", "IgnoreCont"]
aliases: ["gump name", "container name"]
source: wiki
---

`#ContName` is the client's internal name for the gump on top. Spaces in the name read as `_`. Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

Some names seen so far (shards can add their own):

| Name | Gump |
|---|---|
| `container_gump` | Any container: backpack, bag, chest, corpse. |
| `paperdoll_gump` | A paperdoll. |
| `status_gump` | Your status window, or a health bar (see [`#ContHP`](/variables/conthp/)). |
| `skill_gump` | The skills list. |
| `generic_gump` | Server gumps: crafting menus, runebooks, the help menu. |
| `stack_gump` | The amount prompt when you drag part of a stack. |
| `drag_gump` | Something hanging on the cursor. |
| `text_gump` | The journal. |
| `YesNo_gump` | A yes/no question, such as the logout confirmation. |
| `OptionsGump` | The options window. |
| `normal_gump` | The chat window and the shard list. |
| `MainMenu_gump`, `login_gump`, `waiting_gump` | Login screens and messages. |

## Example

```euo
if #ContName = container_gump
  event SysMessage A container is on top.
```
