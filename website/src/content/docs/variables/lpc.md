---
title: "#LPC"
description: "Determines the number of lines that are executed per cycle."
kind: variable
category: result
access: rw
type: number
source: wiki
---

References the current setting for [linesPerCycle](/commands/linespercycle/), which determines how many lines are processed during each cycle that EasyUO is operating. One cycle is 1/20th of a second.

## Example

```euo
set #lpc 10
set %beginTimeNormal #sysTime
for %test 1 1000
{
  set %speedTest %speedTest + 1
}
set %endTimeNormal #sysTime - %beginTimeNormal

set #lpc 250
set %beginTimeFast #sysTime
for %test 1 1000
{
  set %speedTest %speedTest + 1
}
set %endTimeFast #sysTime - %beginTimeFast
display ok at normal LPC the time was , #spc , %endTimeNormal , $At a fast LPC the time was , #spc , %endTimeFast
```
