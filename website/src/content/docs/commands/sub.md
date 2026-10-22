---
title: "Sub"
description: "The sub command starts a smaller macro within the macro."
kind: command
category: flow
syntax: "sub {sub name}"
related: ["gosub", "return"]
source: wiki
---

The *sub* command starts a smaller macro within the macro. You transfer to the [sub](/commands/sub/) by using [gosub](/commands/gosub/) elsewhere in the macro. Use [return](/commands/return/) to go back to where the [gosub](/commands/gosub/) was previously.

:::note
You must not jump out of a sub! Use return to properly terminate a sub routine. To prevent a stack overflow, EUO only supports 1000 consecutive GoSubs without returning. Remember this when using recursion! When the GoSub stack is about to get 1001 levels, the very first level in the bottom of the stack is deleted to make room.
:::

## Example

```euo
mainloop:
 gosub speakgame hi
 wait 1s
goto mainloop

sub speakgame
   exevent macro 1 0 %1
return
```
