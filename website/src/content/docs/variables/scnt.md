---
title: "#SCnt"
description: "Timer in seconds since Windows boot."
kind: variable
category: misc
access: rw
type: number
source: wiki
---

Represents the time passed in seconds since the last time that windows started.

## Example

```euo
set %startTime #sCnt
for %testLoop 1 1000
{
  set %testCnt %testCnt + 1
}
set %endTime %startTime - #sCnt
Display ok time elapsed in seconds: , #spc , %endTime
halt
```
