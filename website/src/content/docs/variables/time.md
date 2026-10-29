---
title: "#Time"
description: "Local time of the computer as hhmmss, 24-hour clock."
kind: variable
category: misc
access: ro
type: string
related: ["#Date", "#SysTime"]
aliases: ["clock", "hour"]
source: wiki
---

`#Time` is the computer's local time, written `hhmmss` on a 24-hour clock: `143005` is 14:30:05.
[`#Date`](/variables/date/) is the date; [`#SysTime`](/variables/systime/) is better for measuring durations.

## Example

```euo
if #Time >= 120000 && #Time < 130000
  display ok Lunch time.
halt
```
