---
title: "Else"
description: "Used in conjunction with if, processed only when the if statement evaluates as false."
kind: command
category: flow
syntax: "Else"
related: ["if"]
source: wiki
---

Used in conjunction with [if](/commands/if/), processed only when the [if](/commands/if/) statement evaluates as [false](/variables/false/). Must be placed immediately after the [true](/variables/true/) command from the [if](/commands/if/) statement.

## Example

```euo
set %a #false
if %a
   display ok % , a is True
else
   display ok % , a is False
halt
```

Will always display %a is [false](/variables/false/)
