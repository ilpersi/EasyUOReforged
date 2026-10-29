---
title: "#False"
description: "The value false: 0."
kind: variable
category: constant
access: ro
type: boolean
related: ["#True", "If"]
aliases: ["no", "boolean"]
source: wiki
---

`#False` is `0`, the value comparisons give when they are false. See [`#True` and `#False`](/guides/true-and-false/).

## Example

```euo
set %done #False
set %round 0
while %done = #False
{
  set %round %round + 1
  if %round = 3
    set %done #True
}
display ok Done after %round rounds.
halt
```
