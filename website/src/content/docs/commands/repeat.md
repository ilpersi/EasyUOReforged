---
title: "Repeat … Until"
description: "Repeats lines until a condition is true, testing it after each round."
kind: command
category: flow
syntax: "repeat\n...\nuntil {condition}"
related: ["while", "for", "break", "continue"]
aliases: ["repeat", "until", "repeat until", "do while"]
source: wiki
---

`repeat` and `until` repeat the lines between them. After each round the condition of `until` is tested:
when it is true the loop ends, otherwise it starts again from `repeat`. The lines therefore always run at
least once, unlike a [`while`](/commands/while/) loop, which tests its condition before the first round.

The condition is true only when it evaluates to [`#true`](/variables/true/), which is `-1`. Comparisons
(`=`, `<`, `in`, …) produce `-1` or `0`, and `&&`, `||` and `!` combine those as expected.
A plain value is **not** turned into true or false: `if 1` and `if yes` are both false, and `if %flag` is
true only when `%flag` holds `#true`. See [`#True` and `#False`](/guides/true-and-false/).

Braces between `repeat` and `until` are optional; they only make the loop easier to read. Loops can be
nested: each `until` belongs to the nearest `repeat` before it that is not already taken.

Leave the loop early with [`break`](/commands/break/), or skip to the test with
[`continue`](/commands/continue/).

## Example

```euo
set %str Hello , #spc , World
repeat
  set %str %str , !
  str len %str
until #StrRes >= 30
display ok %str
halt
```

The `!` is added and `str len` runs once before `#StrRes >= 30` is tested for the first time.
