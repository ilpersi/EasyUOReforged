---
title: "Break"
description: "Jumps to first statement outside of loop."
kind: command
category: flow
syntax: "Break"
source: wiki
---

*break* can be used to immediately exit any loop structure.

## Example

```euo
set %Test 1
while %Test < 10
{
;Code between these brackets, gets executed, while %Test is smaller than 10
;When its 10, it wont jump back to first bracket.
if %Test = 7
   break
set %Test %Test + 1
}
display ok %Test $
halt
;%Test will hold the value of 7, notice how we break out from the loop when %Test is 7.
```
