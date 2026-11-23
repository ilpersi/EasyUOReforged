---
title: "Timer"
description: "Named timers: start one with a time to wait, then ask whether it is due, how long is left or how long it has run. The answer goes to #TimerRes."
kind: command
category: flow
syntax: "timer {start|due|left|elapsed|stop} {name} [time]"
origin: reforged
sets: ['#TimerRes']
related: ["#TimerRes", "#SCnt", "#SysTime", "WaitFor", "Str"]
aliases: ["stopwatch", "countdown", "deadline", "timeout", "every n seconds", "elapsed time"]
---

`timer` keeps as many named timers as a script needs: a world-save timer, a cast timeout, how long the script
has run. Each line answers in [`#TimerRes`](/variables/timerres/).

| Line | `#TimerRes` |
|---|---|
| `timer start {name} [time]` | Starts the timer now, or starts it again. It is due after `time`, or at once without one. `#true`. |
| `timer due {name}` | `#true` once the timer is due, `#false` before. A timer that was never started counts as due. |
| `timer left {name}` | Milliseconds until it is due; `0` once it is due, or if it was never started. |
| `timer elapsed {name}` | Milliseconds since it was started; `N/A` if it was never started. |
| `timer stop {name}` | Forgets it. `#true` if there was such a timer, `#false` if not. |

`time` is written as for [`wait`](/commands/wait/): a number of **ticks** of 50 ms (`20` is one second), or a
whole number of **seconds** followed by `s` (`30s`). A line without a name, or with another word after `timer`,
sets `#TimerRes` to `N/A` and does nothing else.

## Examples

Give up when something takes too long:

```euo
timer start cast 4s
repeat
  wait 2
  timer due cast
until #TargCurs = 1 || #TimerRes
halt
```

Do something every 30 seconds, in a loop that does other work meanwhile. The first time round the timer was
never started, so it is due and the work runs at once:

```euo
mainloop:
  timer due save
  if #TimerRes
  {
    event sysmessage Checking for a world save
    timer start save 30s
  }
  wait 10
goto mainloop
```

Show how long the script has run, as `h:mm:ss` with [`str duration`](/commands/str/#time-and-numbers-reforged):

```euo
timer start run
wait 3s
timer elapsed run
set %secs #TimerRes / 1000
str duration %secs
event sysmessage Running for #StrRes
halt
```

## What a timer is

- Names are one word and ignore case: `Cast` and `CAST` are the same timer. A name may be built with `.`, as
  `timer start cast . %i 5s` is the timer `cast3` when `%i` is 3.
- Timers count real time, from the moment `start` runs. Pausing the script doesn't stop them.
- Nothing else moves them. [`#SCnt`](/variables/scnt/) and [`#SCnt2`](/variables/scnt2/) can be set, and a script
  that does `set #SCnt 0` to time something moves every deadline built on `#SCnt`. A timer can only be moved by
  `timer start`.
- Each script has its own timers, and a script it [`call`](/commands/call/)s shares them, as it shares the `%`
  variables. They are kept when the script starts over from the top (an [`exit`](/commands/exit/), or the end of
  the script) and forgotten when you start it again.

## Writing for EasyUO 1.5 too

`timer` is new in EasyUO Reforged. In EasyUO 1.5 a line starting with `timer` is ignored, and `#TimerRes` reads
`N/A`. A script that must also run there builds its deadlines from [`#SysTime`](/variables/systime/), which a
script can't set:

```euo
set %save #SysTime + 30000
mainloop:
  if #SysTime >= %save
  {
    event sysmessage Checking for a world save
    set %save #SysTime + 30000
  }
  wait 10
goto mainloop
```

A sub or label called `timer` keeps working: `gosub timer` and `goto timer` find it as before.
