---
title: "#Time"
description: "Returns the local time on your computer."
kind: variable
category: misc
access: ro
type: string
source: wiki
---

Represents the local time of the computer that EasyUO is running on. The format is HHMMSS, where HH is the hour in 24 hour format, MM is the minutes and SS is the seconds.

## Example

```euo
if #time = 120000
{
  event SysMessage Time for lunch!
  pause
}
```
