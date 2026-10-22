---
title: "#Result"
description: "Value given to the last return; N/A when it had none."
kind: variable
category: result
access: rw
type: string
related: ["Return", "Gosub"]
aliases: ["return value"]
source: wiki
---

`#Result` is the value the last [`return`](/commands/return/) gave back from a sub, or `N/A` when that `return`
had no value. A `return` outside a sub leaves it as it was.

## Example

```euo
gosub double 21
display ok #Result            ; 42
halt

sub double
return %1 * 2
```
