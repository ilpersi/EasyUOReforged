---
title: "Halt"
description: "Stops the script."
kind: command
category: flow
syntax: "halt"
related: ["stop", "pause", "exit"]
source: wiki
---

`halt` stops the script. Unlike [`pause`](/commands/pause/), it cannot be resumed: pressing Play starts the
script again from the first line. [`stop`](/commands/stop/) does exactly the same.

A main script that reaches its last line without `halt` starts over from the top, as with
[`exit`](/commands/exit/).

## Example

```euo
set %amountNeeded 3
finditem TSF C_ , #BackpackID      ; daggers
if #FindCnt < %amountNeeded
  halt
display ok #FindCnt daggers: enough to go on.
halt
```
