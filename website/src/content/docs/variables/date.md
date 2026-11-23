---
title: "#Date"
description: "Local date of the computer as yymmdd."
kind: variable
category: time
access: ro
type: string
related: ["#Time", "#SysTime", "Str"]
aliases: ["today", "calendar"]
source: wiki
---

`#Date` is the computer's local date, written `yymmdd`: `261225` is 25 December 2026.
In EasyUO Reforged, [`str date`](/commands/str/#time-and-numbers-reforged) writes it as `2026-12-25` or in a format
of your choice, such as `25/12/2026` or `Friday 25 December 2026`.

## Example

```euo
str right #Date 4
if #StrRes = 1225
  display ok Merry Christmas!
halt
```
