---
title: "WaitFor"
description: "Waits until a condition is true or a timeout passes, and reports which happened in #WaitRes."
kind: command
category: flow
syntax: "waitfor {condition} [timeout]"
origin: reforged
sets: ['#WaitRes']
related: ["If", "Target", "Wait", "#WaitRes"]
aliases: ["wait until", "wait for gump", "wait for condition", "poll"]
---

`waitfor` checks a condition every tick (50 ms) until it is true or the timeout passes.
[`#WaitRes`](/variables/waitres/) then says which happened: `#true` if the condition was met, `#false` if the
time ran out. If the condition is already true, the script goes on without any delay.

It replaces the loops scripts write to wait for the client, and the fixed waits they guess at:

```euo
event macro 8 7                       ; open the backpack
waitfor #ContName = container_gump 3s
if #WaitRes = #false
  display ok The backpack did not open.
halt
```

## Parameters

| Parameter | Meaning |
|---|---|
| `condition` | What to wait for, written as for [`if`](/commands/if/). |
| `timeout` | Optional. The longest to wait. Default: 2 seconds. A time is a number of **ticks** of 50 ms (`20` is one second), or a whole number of **seconds** followed by `s` (`5s`). `0` checks once and doesn't wait. A value that can't be read as a time, such as an unset variable, counts as the default. |

## Conditions

The condition is read exactly as `if` reads it, so `=`, `<>`, `<`, `>`, `<=`, `>=`, `in`, `notin`, `&&`, `||`, `!` and
parentheses all work the same. Combine as many conditions as you need and nest them to any depth:

```euo
event macro 8 7
waitfor ( ( #ContName = generic_gump || #ContName = container_gump ) && #ContSizeX > 100 ) || #TargCurs = 1 5s
if #WaitRes
  event sysmessage Something happened
halt
```

Variables are read again on every check. The rules are those of `if`:

- Every word, including each parenthesis and operator, needs a space around it: `( #ContID = %id )`, not `(#ContID = %id)`.
- `&&` binds tighter than `||`. Without parentheses, `%a = 1 || %b = 2 && %c = 3` means `%a = 1 || ( %b = 2 && %c = 3 )`.
- A parenthesis left unbalanced gives no error. The condition just can't come true as you meant it, and the timeout may
  count as the default.
- A single variable counts as true only when it holds `#true` (`-1`).

A long condition can go on over [`+` lines](/language/expressions/#lines-and-blocks). They join without a space, so write
the space after the `+`:

```euo
waitfor ( #ContName = generic_gump && #ContSizeX > 100 )
+ || ( #ContName = container_gump && #ContSizeX > 50 )
+ || #TargCurs = 1 5s
halt
```

`#WaitRes` tells only whether the whole condition came true. To know which part did, test it afterwards:

```euo
event macro 15 28                     ; cast Greater Heal, which needs a target
waitfor #TargCurs = 1 || recovered in #SysMsg 3s
if #TargCurs = 1
  event macro 22 0
halt
```

## Pause, Stop and stepping

- **Pause** holds the wait, and the time paused doesn't count towards the timeout. The condition is checked again on
  resuming, so one that came true during the pause counts as met.
- **Stop** ends the wait at once and leaves `#WaitRes` as it was.
- **Step Into** and **Step Over** treat the whole wait as one step.
- The editor stays responsive during a wait, and the variable inspector keeps updating.

## Notes

- `waitfor` works without a client. Client variables then read `N/A`, so a condition on them never comes true and the
  command runs its timeout. Conditions on `%` variables or [`#SCnt`](/variables/scnt/) work as usual.
- A state that lasts less than a tick can be missed between two checks.
- The wait can end up to one tick after the timeout.
- `waitfor 5s` has `5s` as its **condition**, which is never true, so it waits for the default 2 seconds. To wait a fixed
  time, use [`wait`](/commands/wait/).
- In a `for` loop whose body is a single line with no braces, the loop variable has already moved on when `waitfor` checks
  for the second time. If the condition uses that variable, put the body in `{ }`.

## Reforged notes

`waitfor` and `#WaitRes` are new in EasyUO Reforged. No existing command changes because of them, and a sub or label
called `waitfor` keeps working. It's the only change for old scripts: a line starting with the word `waitfor` used to be
ignored and is now this command.

`uo.dll` has no equivalent. A program using it polls the properties itself.
