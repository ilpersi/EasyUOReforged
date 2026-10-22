---
title: "Expressions"
description: "Calculations and conditions: which commands evaluate them, how words are separated, and how lines and blocks are built."
sidebar:
  order: 2
source: wiki
---

An expression is a calculation or a condition: `%a + 1`, `( 2 + 2 ) * 3`, `#Hits < 50`, `%a = 1 && %b = 2`.
It is built from values, variables, [operators](/language/operators/) and parentheses.

```euo
set %var 1337                           ; a value
set %temp %var                          ; a variable
set %next %var + 1                      ; an operator
set %calc ( 2 + 2 ) * ( 3 - 1 )         ; parentheses: 8
set %flag ! #true                       ; an operator before a value: 0
```

## Which commands calculate

**Only five commands work out expressions:** [`set`](/commands/set/), [`if`](/commands/if/),
[`while`](/commands/while/), [`until`](/commands/repeat/) and [`return`](/commands/return/). Every other command
takes its parameters as they are: `wait %a + 1` waits `%a` ticks and ignores the rest. To pass a calculated
value to another command, calculate it with `set` first:

```euo
set %delay %a + 1
wait %delay
```

## Spaces matter

A line is split into words at spaces, and **every operator and parenthesis has to be a word of its own**:

```euo
set %a %b + 1          ; right
set %a %b+1            ; wrong: "%b+1" is one word, so nothing is added
if ( %a > 2 )          ; right
if (%a > 2)            ; wrong: "(%a" and "2)" are not understood
```

Calculations use whole numbers only. A value that is not a number counts as `0` in arithmetic. See
[Operators](/language/operators/) for every operator and the order they are worked out in.

## Lines and blocks

A script is a list of lines. Each line holds one command and its parameters, and runs from the first word to
the end of the line or to a `;`, which starts a comment.

- **A long line** can continue on the next lines: start each continuation with `+`. The pieces are joined
  without a space, so write `+ more text` (with a space after `+`) where you want one.
- **A block** is a group of lines between a `{` line and a `}` line. Blocks belong to
  [`if`](/commands/if/), [`else`](/commands/else/), [`for`](/commands/for/), [`while`](/commands/while/),
  [`sub`](/commands/sub/) and a few others. The braces go on lines of their own, and the `{` has to be the line
  right after the command it belongs to.

```euo
if %a > 2
{
  set %b %a * 2
  display ok %b
}
display ok This is a long message that
+ goes on over two lines.
```
