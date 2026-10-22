---
title: "#SCnt2"
description: "A tenths-of-a-second counter; set it to start counting from that value."
kind: variable
category: misc
access: rw
type: number
related: ["#SCnt", "#SysTime"]
aliases: ["tenths", "stopwatch"]
source: wiki
---

`#SCnt2` counts tenths of seconds. Like [`#SCnt`](/variables/scnt/), it counts from Windows' start until you set
it, then on from the value you set.

## Example

```euo
set #SCnt2 0
gosub work
event SysMessage That took #SCnt2 tenths of a second
```
