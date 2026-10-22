---
title: "#True"
description: "A constant that represents boolean true."
kind: variable
category: constant
access: ro
type: boolean
related: ["#false"]
source: wiki
---

A constant that represents boolean true.

The constant `#true` is used to assign or compare a variable or an expression with the boolean *true* value.

Internally, `#true` is represented by the integer value -1.

## Example

```euo
if #false
  display ok This will never be displayed
if #true
  display ok This will always be displayed
```
