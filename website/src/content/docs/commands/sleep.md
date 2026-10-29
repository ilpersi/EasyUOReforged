---
title: "Sleep"
description: "Pauses the script for a number of milliseconds."
kind: command
category: flow
syntax: "sleep {milliseconds}"
related: ["Wait"]
aliases: ["delay", "milliseconds"]
source: wiki
---

`sleep` pauses the script for the given number of milliseconds.

## Sleep or wait?

`sleep` and [`wait`](/commands/wait/) pause the script the same way; only the unit differs. `wait` counts in
ticks of 50 ms (or whole seconds) and can add a random extra; `sleep` counts in milliseconds. Use `sleep`
for pauses shorter than 50 ms or that are not a multiple of it.

Both stop at once when you press Stop, and neither uses CPU while it waits. Old advice to keep `sleep`
short because it froze the EasyUO window does not apply: in EasyUO Reforged each script runs on its own
thread.

## Example

```euo
set %start #SysTime
sleep 25
set %took #SysTime - %start
display ok Slept %took ms
halt
```
