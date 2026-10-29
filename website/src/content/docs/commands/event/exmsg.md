---
title: "event ExMsg"
description: "Shows a message above an object, in a chosen font and colour."
kind: subcommand
category: event
syntax: "event ExMsg {id} {font} {colour} {message}"
needsClient: true
related: ["event SysMessage", "#CharID"]
aliases: ["overhead message", "message over head"]
dll: ExMsg
source: wiki
---

`event ExMsg` shows a message above an object or character, like the text that appears above people when
they speak. Only you see it; nothing is sent to the server.

## Parameters

| Parameter | Meaning |
|---|---|
| `id` | The object or character, for example [`#CharID`](/variables/charid/) for yourself. |
| `font` | Font number, see the table below. |
| `colour` | Colour (hue) number. `0` is the default. |
| `message` | The text. `$` starts a new line. |

| Font | Look |
|---|---|
| 0 | Big, with dark edges. |
| 1 | Small, with a white drop shadow. |
| 2 | Big, with a white drop shadow. |
| 3 | Small, with dark edges. |
| 4 | Big and fancy. |
| 5 | Medium. |
| 6 | Tiny. |
| 7 | Small, recessed. |
| 8 | Runic letters for A–Z and some symbols; moon phases for a few others. |
| 9 | Tiny. |

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Example

```euo
event ExMsg #CharID 3 0 Welcome to my world!
halt
```
