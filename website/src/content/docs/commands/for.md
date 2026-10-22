---
title: "For"
description: "Repeats a line or block while a variable counts from one number to another."
kind: command
category: flow
syntax: "for {variable} {start} {end}"
related: ["while", "repeat", "break", "continue", "#FindIndex"]
source: wiki
---

`for` runs the line or block after it once for each value of `variable`, counting from `start` to `end`.
It counts up when `start` is smaller than `end` and down when it is larger.

## Parameters

| Parameter | Meaning |
|---|---|
| `variable` | The counter. Any variable works, including system variables such as [`#FindIndex`](/variables/findindex/). |
| `start` | First value, a whole number. |
| `end` | Last value, a whole number. It is read once, when the loop starts: changing it inside the loop has no effect. |

A block is a `{` line, the lines to run, and a matching `}` line. The `{` has to be **the very next line**:
a blank line or a comment in between means only that line belongs to the command, and the block after it
runs every time. Braces go on lines of their own. Without a block, only the next line is repeated.

Leave a loop early with [`break`](/commands/break/), or skip to the next value with
[`continue`](/commands/continue/).

## Examples

```euo
for %i 1 20
{
  event sysmessage %i
  wait 10
}
halt
```

Counting down, and using a system variable as the counter:

```euo
for %i 10 1
  event sysmessage %i

finditem POF C_ , #BackpackID
for #FindIndex 1 #FindCnt
  event sysmessage #FindID holds #FindStack gold
halt
```
