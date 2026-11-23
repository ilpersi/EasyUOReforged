---
title: "#TimerRes"
description: "The answer of the last timer line: #true or #false, or a number of milliseconds."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["Timer", "#SysTime", "#SCnt"]
aliases: ["timer result", "time left", "elapsed"]
---

`#TimerRes` holds the answer of the last [`timer`](/commands/timer/) line:

| Line | `#TimerRes` |
|---|---|
| `timer start` | `-1` (`#true`). |
| `timer due` | `-1` (`#true`) when the timer is due or was never started, `0` (`#false`) before. |
| `timer left` | Milliseconds until the timer is due, `0` once it is. |
| `timer elapsed` | Milliseconds since the timer was started, `N/A` if it was never started. |
| `timer stop` | `-1` (`#true`) if there was such a timer, `0` (`#false`) if not. |

It is `N/A` before the first `timer` line of a run, and after a line without a name or with an unknown word.

`#TimerRes` has its own variable so that a `timer` line doesn't overwrite [`#Result`](/variables/result/), which
holds what a sub returned.

## Example

```euo
timer start potion 10s
wait 3s
timer left potion
set %secs #TimerRes / 1000
event sysmessage Next potion in %secs seconds
halt
```
