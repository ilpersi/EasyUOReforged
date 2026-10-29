---
title: "Set"
description: "Gives a variable a value, or the result of an expression."
kind: command
category: misc
syntax: "set {variable} [value]"
related: ["DeleteVar", "For"]
aliases: ["assign", "variable"]
source: wiki
---

`set` gives a variable a value. The value can be an [expression](/language/expressions/), which is worked out
first.

## Parameters

| Parameter | Meaning |
|---|---|
| `variable` | Any variable a script can write: `%x`, `!x`, `*x`, or a read/write system variable such as [`#LPC`](/variables/lpc/). |
| `value` | Optional. A value or expression. Without it, the variable becomes empty. |

## Details

- **One word only.** A value is a single word: `set %a hello world` stores `hello`. Join words with `_`, or
  glue them with commas: `set %a hello , #spc , world`.
- `abs` after the value stores its absolute value: `set %a -5 abs` stores `5`.
- A lone `+` or `-` after a number adds or takes away 1: `set %i %i +` is the same as `set %i %i + 1`.

## Example

```euo
set %a 2
set %b $A                       ; hexadecimal: 10
set %c ( %a * %b ) + 1          ; 21
set %d %a * ( %b + 1 )          ; 22
set %name Sir , #spc , Robin    ; "Sir Robin"
set %empty
set #LPC 100
display ok %c %d %name
halt
```
