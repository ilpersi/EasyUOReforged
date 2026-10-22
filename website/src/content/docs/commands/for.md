---
title: "For"
description: "Creates a counting loop."
kind: command
category: flow
syntax: "for {variable} {start} {end} { }"
related: ["continue"]
source: wiki
---

The for command controls a loop that iterates a variable over a range of numbers. Both positive and negative iterations are legal.

The variable is assigned the starting number to begin with. After each iteration it either increments or decrements the variable, until it reaches the ending number.

:::note
In EasyUO 1.4, you *must* use brackets, even if there is only a single line of code in a for loop. In EasyUO 1.5 however, brackets are optional when the for loop is only a single line of code.
:::

## Example

```euo
for %i 1 20
{
    msg %i $
    wait 10
}
halt
```
