---
title: "Operators"
description: "Arithmetic, comparison, logical and text operators, and the order they are worked out in."
sidebar:
  order: 3
source: wiki
---

Operators are worked out by the five commands that calculate: [`set`](/commands/set/), [`if`](/commands/if/),
[`while`](/commands/while/), [`until`](/commands/repeat/) and [`return`](/commands/return/). Every operator has
to be a separate word, with spaces around it; see [Expressions](/language/expressions/).

## Arithmetic

| Example | Operator | Result |
|---|---|---|
| `%a + %b` | Addition | |
| `%a - %b` | Subtraction | |
| `%a * %b` | Multiplication | |
| `%a / %b` | Division | Whole numbers only: the remainder is dropped, `7 / 2` is `3`. Dividing by 0 gives `0`. |
| `%a % %b` | Remainder | What is left over after dividing: `7 % 2` is `1`. By 0 it gives `0`. |
| `abs %a` | Absolute value | The value without its sign: `abs -5` is `5`. |

Arithmetic works on whole numbers. A value that is not a number (`hello`, `N/A`) counts as `0`.

## Comparison

Comparisons give `-1` ([`#true`](/variables/true/)) or `0` ([`#false`](/variables/false/)).

| Example | Operator | True when |
|---|---|---|
| `%a = %b` | Equal | Both are the same. When either is not a number they are compared as text, ignoring case. |
| `%a <> %b` | Not equal | They are not the same, by the same rule. |
| `%a < %b` | Less than | `%a` is smaller. |
| `%a > %b` | Greater than | `%a` is larger. |
| `%a <= %b` | Less than or equal | Also written `=<`. |
| `%a >= %b` | Greater than or equal | Also written `=>`. |
| `%a in %b` | Contained in | The text `%a` appears inside `%b`, ignoring case. |
| `%a notin %b` | Not contained in | It does not. |

`<`, `>`, `<=` and `>=` are **always false** when either side is not a number: `hello > 33` is false, and so is
`hello < 33`. That makes a quick test for "is this a number?":

```euo
set %cnt hello
if ! ( %cnt > 0 || %cnt < 1 )
  set %cnt 0                     ; %cnt was not a number
display ok %cnt
halt
```

## Logical

| Example | Operator | True when |
|---|---|---|
| `%a && %b` | And | Both are true. |
| `%a \|\| %b` | Or | At least one is true. |
| `! %a` | Not | `%a` is false (it turns `-1` into `0` and `0` into `-1`). |

These are meant for true/false values (`-1` and `0`), such as the results of comparisons. On other numbers
they work bit by bit (`! 5` is `-6`), which is rarely what you want. Both sides of `&&` and `||` are always
worked out.

## Text and lines

These are handled while the line is read, before the command runs, so they work with every command, not just
the five above.

| Example | Operator | What it does |
|---|---|---|
| `%a , %b` | Join | Joins the two values into one word: with `%a` = `A` and `%b` = `B`, `%a , %b` is `AB`. |
| `%a . %b` | Glue a name | Glues the word on the left to the **value** on the right, then reads the result as a variable. See below. |
| `+` at the start of a line | Continue | The line continues the previous one, joined without a space. |

Joining works on any word, even command names: `h , a , l , t` is `halt`.

### Building variable names with `.`

`.` works from right to left: the right side is replaced by its value first, then glued to the left word, and
the result is read as a variable. That builds variable names from other values, a little like arrays:

```euo
set %a 3
set %item3 sword
set %x %item . %a          ; %item . 3  ->  %item3  ->  sword
set %y %item , %a          ; "%item" has no value, so N/A , 3  ->  N/A3
display ok %x %y
halt
```

```euo
set %slot1 sword
set %slot2 shield
set %slot3 helmet
for %i 1 3
{
  set %name %slot . %i     ; %slot1, %slot2, %slot3
  display ok %name
}
halt
```

A `.` or `,` only works as a separate word. To put a full stop or a comma into text, use [`#DOT`](/variables/dot/)
or glue the pieces with `,`.

## Order of operations

Within each pair of parentheses, starting with the innermost, operators are worked out in this order. Operators
on the same row are worked out from left to right.

| Order | Operators |
|---|---|
| 1 | `!` and `abs`, from right to left |
| 2 | `*` `/` `%` |
| 3 | `+` `-` |
| 4 | `=` `<>` `<` `>` `<=` `>=` `in` `notin` |
| 5 | `&&` |
| 6 | `\|\|` |

Before any of this, while the line is read, `.` (right to left) and then `,` (left to right) have already been
applied, and variables have been replaced by their values.

```euo
set %r 5 + 3 * 2               ; 5 + ( 3 * 2 ) = 11
set %r 8 - 3 - 2               ; ( 8 - 3 ) - 2 = 3
set %r ( 1 + 2 ) * 2 * 4       ; 24
set %a 1
set %b 2
if %a = 1 && %b = 2            ; ( %a = 1 ) && ( %b = 2 )
  display ok Both are true.
if ! ( %a = 1 )                ; parentheses needed: ! %a = 1 means ( ! %a ) = 1
  display ok Not shown: %a is 1.
halt
```
