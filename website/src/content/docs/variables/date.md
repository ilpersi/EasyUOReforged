---
title: "#Date"
description: "Local date of the computer as yymmdd."
kind: variable
category: misc
access: ro
type: string
related: ["#Time", "#SysTime"]
aliases: ["today", "calendar"]
source: wiki
---

`#Date` is the computer's local date, written `yymmdd`: `261225` is 25 December 2026.

## Example

```euo
str right #Date 4
if #StrRes = 1225
  event SysMessage Merry Christmas!
```
