---
title: "Break"
description: "Leaves the loop it is in and goes on after the loop."
kind: command
category: flow
syntax: "break"
related: ["continue", "for", "while", "repeat"]
source: wiki
---

`break` leaves the [`for`](/commands/for/), [`while`](/commands/while/) or
[`repeat … until`](/commands/repeat/) loop it is in. The script goes on with the line after the loop.

Only the innermost loop is left. A `break` outside any loop does nothing.

## Example

```euo
set %test 1
while %test < 10
{
  if %test = 7
    break
  set %test %test + 1
}
display ok %test     ; shows 7
halt
```
