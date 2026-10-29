---
title: "#DOT"
description: "A full stop, which could not be typed alone because . joins words."
kind: variable
category: constant
access: ro
type: string
related: ["#SPC", "#SMC"]
aliases: ["period", "full stop"]
source: wiki
---

`#DOT` is a full stop (`.`). A lone `.` in a line glues the words on either side together, so use `#DOT` when
the text needs a separate full stop.

## Example

```euo
set %file mylog , #DOT , txt         ; mylog.txt
display ok %file
halt
```
