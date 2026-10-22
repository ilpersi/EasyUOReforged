---
title: "Repeat … Until"
description: "Creates a loop that checks condition after execution."
kind: command
category: flow
syntax: "repeat { } until ( expression )"
aliases: ["repeat", "until", "repeat until"]
source: wiki
---

The *repeat..until* control structure executes the code block between the statements, and then evaluates the expression. This will make it so that [repeat..until](/commands/repeat/) loops will always execute the code within the loop at least once. This command differs from the [while](/commands/while/) command because the expression is evaluated prior to the code inside the code block, where [while](/commands/while/) evaluates the expression after executing it's code block.

## Example

```euo
set %str Hello , #spc , World
repeat
{
  set %str %str , !
  str len %str
}
until #strres >= 30
display ok %str
halt
```

The example above illustrates the difference between a repeat..until loop and a while loop. the exclamation point will always be concatinated to the end of the %str variable, and str len will be executed once before the test for #strRes \>= 30 is first evaluated.
