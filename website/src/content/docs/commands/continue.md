---
title: "Continue"
description: "Jumps execution of a loop to next iteration."
kind: command
category: flow
syntax: "continue"
related: ["for"]
source: wiki
---

Continue stops execution of code inside of a loop. Control is returned at the point of the next evaluation.

## Example

```euo
gosub testrandom
sub testrandom
{
  for %cnt 1 10
  {
    if #random % 10 <> 5
      continue
    display ok Five has been found!
    return
  }
  display ok Nothing could be found!
  return
}
display ok HALT!
halt
```

When random is something other than 5, the if sentence is true and therefore continue is executed. It jumps over the [display](/commands/display/) and [return](/commands/return/) commands and continues the [for](/commands/for/) loop with it's next iteration. In the case that the evaluation is false, execution proceeds to the statement following the loop structure.
