---
title: "#SysTime"
description: "Milliseconds since 1 January 1980 UTC; for timing."
kind: variable
category: misc
access: ro
type: number
related: ["#SCnt", "#SCnt2", "#Time"]
aliases: ["milliseconds", "timer", "timestamp"]
source: wiki
---

`#SysTime` is the number of milliseconds since 1 January 1980, in UTC. It does not depend on the time zone, so
it is the most precise way to time something: read it before and after, and subtract.

## Example

```euo
set %start #SysTime
gosub work
set %took #SysTime - %start
event SysMessage That took %took ms
```
