---
title: "While"
description: "Repeats a line or block as long as a condition is true, testing it first."
kind: command
category: flow
syntax: "while {condition}"
related: ["repeat", "for", "break", "continue", "if"]
source: wiki
---

`while` tests its condition and, as long as it is true, runs the line or block after it and tests again.
When the condition is false the script goes on after the loop. If it is false from the start, the loop
does not run at all; use [`repeat … until`](/commands/repeat/) to run the lines at least once.

The condition is true only when it evaluates to [`#true`](/variables/true/), which is `-1`. Comparisons
(`=`, `<`, `in`, …) produce `-1` or `0`, and `&&`, `||` and `!` combine those as expected.
A plain value is **not** turned into true or false: `if 1` and `if yes` are both false, and `if %flag` is
true only when `%flag` holds `#true`. See [`#True` and `#False`](/guides/true-and-false/).

A block is a `{` line, the lines to run, and a matching `}` line. The `{` has to be **the very next line**:
a blank line or a comment in between means only that line belongs to the command, and the block after it
runs every time. Braces go on lines of their own. Without a block, only the next line is repeated.

Leave the loop early with [`break`](/commands/break/), or skip to the next test with
[`continue`](/commands/continue/).

## Example

```euo
set %test 1
while %test < 10
  set %test %test + 1
display ok %test     ; shows 10
halt
```
