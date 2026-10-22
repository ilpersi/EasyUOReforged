---
title: "#SysTime"
description: "Counts the number of milliseconds since 01/Jan/1980 UTC."
kind: variable
category: misc
access: ro
type: number
source: wiki
---

Represents the time passed since 01/Jan/1980 UTC (it is timezone independant) in millisecond increments. It can be useful for timing and time calculations. it is also not affected by overflow issues or speedhack tools.

## Example

```euo
set %startTime #sysTime
for %testLoop 1 1000
{
  set %testCnt %testCnt + 1
}
set %endTime #sysTime - %startTime
Display ok time elapsed in milliseconds: , #spc , %endTime
halt
```
