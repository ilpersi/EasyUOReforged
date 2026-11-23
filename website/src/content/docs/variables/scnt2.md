---
title: "#SCnt2"
description: "A tenths-of-a-second counter; set it to start counting from that value."
kind: variable
category: time
access: rw
type: number
related: ["#SCnt", "#SysTime", "Timer"]
aliases: ["tenths", "stopwatch"]
source: wiki
---

`#SCnt2` counts tenths of seconds. Like [`#SCnt`](/variables/scnt/), it counts from Windows' start until you set
it, then on from the value you set. For deadlines and stopwatches that nothing else can move, EasyUO Reforged
has [`timer`](/commands/timer/).

## Example

```euo
set #SCnt2 0
wait 3s
display ok That took #SCnt2 tenths of a second
halt
```
