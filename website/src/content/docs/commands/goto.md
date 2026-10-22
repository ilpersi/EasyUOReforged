---
title: "Goto"
description: "Jumps to another part of the script given by a label."
kind: command
category: flow
syntax: "goto {label}"
related: ["label"]
source: wiki
---

The *goto* command moves the execution to another part of the script. The destination point is given by a [label](/commands/label/).

:::note
- Don't goto out of a [sub](/commands/sub/). Always use [return](/commands/return/)! EasyUO will probably not crash but it is VERY bad programming style.
- A label in the code must be followed by a colon, where as gotoing to the label does **not** require a following colon.
- Inline comments do not work with labels in EasyUO 1.4.
:::

## Example

```euo
loop:
if %donotloop
    goto exit
goto loop

exit:
```

## Simulating a Switch Statement

Switch structures (like seen in C/C++) can be simulated in EasyUO using the goto statement:

```euo
set %a #random % 3 + 1
goto case , %a

case1:
  display ok One
  goto case_exit

case2:
  display ok Two
  goto case_exit

case3:
  display ok Three
  goto case_exit

case_exit:
halt
```
