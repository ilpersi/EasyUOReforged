---
title: "#False"
description: "A constant that represents boolean false."
kind: variable
category: constant
access: ro
type: boolean
related: ["#true"]
source: wiki
---

A constant that represents boolean false.

The constant `#false` is used to assign or compare a variable or an expression with the boolean *false* value.

Internally, `#false` is represented by the integer value 0.

## Example

```euo
if #false
  display ok This will never be displayed
if #true
  display ok This will always be displayed
```
