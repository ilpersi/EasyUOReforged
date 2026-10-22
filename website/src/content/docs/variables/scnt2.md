---
title: "#SCnt2"
description: "Timer in tenths of seconds since Windows boot."
kind: variable
category: misc
access: rw
type: number
source: wiki
---

Represents the time passed in tenths of seconds since the last time that windows started.

## Example

```euo
set %startTime #scnt2
for %testLoop 1 1000
{
  set %testCnt %testCnt + 1
}
set %endTime %startTime - #scnt2
Display ok time elapsed in tenths of a second: , #spc , %endTime
halt
```
