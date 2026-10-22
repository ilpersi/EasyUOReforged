---
title: "#SMC"
description: "A constant that represents the semicolon character."
kind: variable
category: constant
access: ro
type: string
source: wiki
---

A constant that represents *semi-colon* character.

The constant `#smc` is used to assign or compare a variable or an expression with the *semi-colon* character.

This is required because the semi-colon character ';' is used for inline comments.

## Example

```euo
set %charInfo #charName , #smc , #charGhost
menu window size 100 100
menu window title %charInfo
menu show
```
