---
title: "While"
description: "Creates a loop that checks condition before execution."
kind: command
category: flow
syntax: "while ( expression ) { }"
source: wiki
---

While loops test the expression and if true, continuously executes the code provided until the expression is no longer true. Unlike [repeat..until](/commands/repeat/), while loops will not execute at all if the expression evaluates to false.

## Example

```euo
set %Test 1

while %Test < 10
{
;Code between these brackets, gets executed, while %Test is smaller than 10
;When its 10, it wont jump back to first bracket.
set %Test %Test + 1
}
display ok %Test $
halt
```

%Test holds the value of 10. Notice the condition "%Test \< 10". If that becomes true, the script won't jump back to the while loop start, but continues normally.
