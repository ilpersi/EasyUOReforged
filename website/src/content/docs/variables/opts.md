---
title: "#Opts"
description: "Active options: always SYS, EXEC and SEND, plus DMC when Don’t Move Cursor is on."
kind: variable
category: result
access: ro
type: string
related: ["Click", "Execute", "Send"]
aliases: ["options", "settings"]
source: wiki
---

`#Opts` lists the active EasyUO options, separated by `_`:

| Option | Meaning |
|---|---|
| `SYS` | [`event SysMessage`](/commands/event/sysmessage/) is allowed. |
| `DMC` | *Tools → Don't Move Cursor* is on: [`click`](/commands/click/) does not move the real cursor. |
| `EXEC` | [`execute`](/commands/execute/) is allowed. |
| `SEND` | [`send`](/commands/send/) is allowed. |

In EasyUO Reforged `SYS`, `EXEC` and `SEND` are always on, so `#Opts` is `SYS_DMC_EXEC_SEND` with *Don't Move
Cursor* on (the default) and `SYS_EXEC_SEND` with it off.

## Example

```euo
if DMC notin #Opts
  display ok This script works best with Don't Move Cursor turned on.
```
