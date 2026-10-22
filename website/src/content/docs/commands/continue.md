---
title: "Continue"
description: "Skips the rest of the loop body and goes on with the next round of the loop."
kind: command
category: flow
syntax: "continue"
related: ["break", "for", "while", "repeat"]
source: wiki
---

`continue` skips the rest of the body of the [`for`](/commands/for/), [`while`](/commands/while/) or
[`repeat … until`](/commands/repeat/) loop it is in. The loop then goes on as if the body had ended: a
`for` moves its counter to the next value, a `while` or an `until` tests its condition again.

Only the innermost loop is affected. A `continue` outside any loop does nothing.

## Example

```euo
for %i 1 10
{
  if %i % 2 = 1
    continue                       ; skip the odd numbers
  event sysmessage %i is even
}
halt
```
