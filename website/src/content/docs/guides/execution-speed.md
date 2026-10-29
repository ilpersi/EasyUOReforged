---
title: "Script speed and #LPC"
description: "How fast a script runs: cycles of #LPC lines, why GOTO is not faster than GOSUB, and how to speed scripts up."
sidebar:
  order: 6
source: wiki
---

"Is `goto` faster than `gosub`?" comes up often. The answer lies in how EasyUO runs a script.

## Cycles

A script runs in **cycles**. In each cycle it runs [`#LPC`](/variables/lpc/) lines (10 by default) and then
pauses 50 ms, which leaves the computer to the UO client and everything else. That makes about 20 cycles, or
200 lines, a second.

```euo
; what EasyUO does, in pseudo-code
start:
  run #LPC lines of the script
  pause 50 ms
goto start
```

A comment, a `goto` and a `gosub` each count as one line. Running a line takes almost no time compared with the
50 ms pause, so **which command a line holds hardly matters**: `goto` is not faster than `gosub`, and removing
comments only saves lines, not real work. Some commands, such as [`key`](/commands/key/),
[`click`](/commands/click/), [`target`](/commands/target/) and [`wait`](/commands/wait/), wait on purpose and
take as long as they take.

## Making scripts faster

Raise `#LPC` where a script does a lot of quick work, and lower it again afterwards:

```euo
set #LPC 1000
set %sum 0
for %i 1 1000            ; a lot of quick lines
  set %sum %sum + %i
set #LPC 10
display ok The sum is %sum
halt
```

A high `#LPC` lets the script take more of the computer's time. That is fine for bursts of calculation, menu
building or text work. For commands that make the client do work, such as [`finditem`](/commands/finditem/),
a high value only uses more CPU without making the game respond faster.

## Measuring

To compare commands, take the 50 ms pause out of the measurement by setting a very high `#LPC`, and time many
repetitions with [`#SysTime`](/variables/systime/):

```euo
set #LPC 100000000
set %start #SysTime
for %i 1 100000
  set %x 3
set %took #SysTime - %start
set #LPC 10
display ok 100000 sets took %took ms
halt
```

In the original EasyUO, a huge `#LPC` froze the EasyUO window until the loop ended. In EasyUO Reforged each
script runs on its own thread and gives way briefly every 1024 lines, so the window stays usable and **Stop**
still works.

*Based on Cheffe's tutorial on execution speed from the EasyUO wiki.*
