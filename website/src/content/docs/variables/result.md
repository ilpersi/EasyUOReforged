---
title: "#Result"
description: "Returns the result of the last return command."
kind: variable
category: result
access: rw
type: string
related: ["return"]
source: wiki
---

holds the value from the last [return](/commands/return/) statement executed.

## Example

```euo
gosub xor 1875 618
display #result
halt

sub xor
{
  return %1 && ! %2 || ! %1 && %2
}
```
