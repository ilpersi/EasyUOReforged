---
title: "#Date"
description: "Returns the local date on your computer."
kind: variable
category: misc
access: ro
type: string
source: wiki
---

Represents the local date of the computer that EasyUO is running on. The format is YYMMDD, where YY is the year, MM is the month and DD is the day.

## Example

```euo
if #date = 031225
{
  event SysMessage Merry christmas!
  pause
}
```
