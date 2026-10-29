---
title: "Goto"
description: "Jumps to a label; the nearest label with that name wins."
kind: command
category: flow
syntax: "goto {label}"
related: ["label", "gosub", "sub"]
source: wiki
---

`goto` makes the script go on at the line after a [label](/commands/label/).

## Parameters

| Parameter | Meaning |
|---|---|
| `label` | Name of the label, with or without the trailing `:`. Case does not matter. |

## Which label

`goto` looks for the label starting from its own line, one line further each step, **forward and backward
at the same time**, and takes the first match. At equal distance the forward one wins. So if a label name is
used twice, the nearest one is chosen, not the first one in the script.

When no label matches, nothing happens and the script goes on with the next line.

:::caution
Don't `goto` out of a [`sub`](/commands/sub/): use [`return`](/commands/return/). A sub left with `goto`
stays open, and enough of them fill up the `gosub` stack.
:::

## Examples

```euo
loop:
  if %done
    goto finished
  gosub work
goto loop

finished:
display ok Done after %rounds rounds.
halt

sub work
  set %rounds %rounds + 1
  if %rounds = 3
    set %done #true
return
```

A `switch` built from labels. The comma glues `case` and the number into one label name:

```euo
set %a #random % 3 + 1
goto case , %a

case1:
  display ok One
  goto case_end
case2:
  display ok Two
  goto case_end
case3:
  display ok Three
case_end:
halt
```
