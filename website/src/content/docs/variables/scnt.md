---
title: "#SCnt"
description: "A seconds counter; set it to start counting from that value."
kind: variable
category: misc
access: rw
type: number
related: ["#SCnt2", "#SysTime"]
aliases: ["seconds", "stopwatch"]
source: wiki
---

`#SCnt` counts seconds. Read alone it is the time since Windows started, but setting it makes it count on from
the value you set, which turns it into a stopwatch. [`#SCnt2`](/variables/scnt2/) counts tenths of seconds.

## Example

```euo
set #SCnt 0
wait 3s
display ok That took #SCnt seconds
halt
```
