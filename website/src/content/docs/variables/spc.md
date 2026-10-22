---
title: "#SPC"
description: "A constant that represents the space character."
kind: variable
category: constant
access: ro
type: string
source: wiki
---

A constant that represents *space* character.

The constant `#spc` is used to assign or compare a variable or an expression with the *space* character.

This is required to be used in variables that contain strings which have embedded spaces. EasyUO uses whitespace (spaces, tabs, newlines) as delimiters, therefore you cannot include spaces in strings with the [set](/commands/set/) command.

## Example

```euo
set %testMessage hello , #spc , world
msg %testMessage , $
```
