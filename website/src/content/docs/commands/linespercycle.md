---
title: "LinesPerCycle"
description: "Sets how many lines the script runs before each 50 ms pause; the same as set #LPC."
kind: command
category: misc
syntax: "linespercycle {lines}"
related: ["#LPC", "Wait"]
aliases: ["speed", "lpc"]
source: wiki
---

A script runs in cycles: it runs a number of lines, then pauses 50 ms, which leaves the computer to the UO
client. `linespercycle` sets that number. It does the same as `set #LPC`: see [`#LPC`](/variables/lpc/).

The default is 10, and a script starts with 10 again each time it is run. `0` and negative numbers are
ignored.

Raise it to make plain calculations run faster, for example while building a big
[`menu`](/commands/menu/) window. Commands that wait for the client, such as `finditem` or the `event`
commands, take the time they need regardless.

## Example

```euo
linespercycle 1000       ; add up 1 to 1000 quickly
set %sum 0
for %i 1 1000
  set %sum %sum + %i
linespercycle 10
display ok The sum is %sum
halt
```
