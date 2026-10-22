---
title: "If"
description: "Runs a line or a block only when a condition is true."
kind: command
category: flow
syntax: "if {condition}\nif {condition} {lines}"
related: ["else", "while", "#True", "#False"]
source: wiki
---

`if` runs the line or block after it only when the condition is true; otherwise the script skips it. An
[`else`](/commands/else/) after it runs instead when the condition is false.

## Parameters

| Parameter | Meaning |
|---|---|
| `condition` | An [expression](/language/expressions/), such as `%a > %b` or `#FindCnt = 0`. |
| `lines` | Optional. Without a block, how many of the following lines belong to the `if`. Default: 1. |

## When is it true?

The condition is true only when it evaluates to [`#true`](/variables/true/), which is `-1`. Comparisons
(`=`, `<`, `in`, …) produce `-1` or `0`, and `&&`, `||` and `!` combine those as expected.
A plain value is **not** turned into true or false: `if 1` and `if yes` are both false, and `if %flag` is
true only when `%flag` holds `#true`. See [`#True` and `#False`](/guides/true-and-false/).

## One line, a block, or a number of lines

Without a block, the `if` controls only the next line:

```euo
set %a 100
set %b #random
if %a > %b
  display ok a is bigger than b
else
  display ok a is equal to or less than b
halt
```

To control several lines, put them in a block:

```euo
if %a > %b
{
  display ok a is bigger than b
  set %b %a
}
else
{
  display ok b is equal to or bigger than a
  set %a %b
}
```

A block is a `{` line, the lines to run, and a matching `}` line. The `{` has to be **the very next line**:
a blank line or a comment in between means only that line belongs to the command, and the block after it
runs every time. Braces go on lines of their own.

The older form gives the number of lines instead of a block. Every script line counts, blank lines and
comments included:

```euo
if %a > %b 2
  display ok a is bigger than b
  set %b %a
else 2
  display ok b is equal to or bigger than a
  set %a %b
```

## Negating a condition

`!` reverses only the value **right after it**, before any comparison is made. So `if ! %var = world` does
not mean "if `%var` is not `world`": it compares `! %var` with `world`, which is never equal. Use `<>`, or
put the condition in parentheses:

```euo
set %var hello
if %var <> world
  display ok shown: hello is not world
if ! ( %var = world )
  display ok shown as well
if ! %var = world
  display ok never shown
halt
```

## Nesting

`if` and `else` can be nested to any depth:

```euo
set %a #random % 3 + 1
if %a = 1
  display ok One
else
{
  if %a = 2
    display ok Two
  else
    display ok Three
}
halt
```
