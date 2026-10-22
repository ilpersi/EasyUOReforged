---
title: "Gosub"
description: "Transfers execution to the matching sub."
kind: command
category: flow
syntax: "gosub {sub name} {param1, param2, ...}"
related: ["sub", "return"]
source: wiki
---

The *gosub* command transfers the execution to a [sub](/commands/sub/) with the name given by the parameter.

Parameters can be added after the sub name. They will be transfered in the variables %1, %2, and so on. The variable %0 holds the number of parameters passed.

:::note
You must not jump out of a sub! Use return to properly terminate a sub routine. To prevent a stack overflow, EUO only supports 1000 consecutive GoSubs without returning. Remember this when using recursion! When the GoSub stack is about to get 1001 levels, the very first level in the bottom of the stack is deleted to make room.
:::

## Example 1

```euo
gosub s7IsGreaterThan CEO RK
; %1 = CEO
; %2 = RK
; %0 = 2
sub s7IsGreaterThan
   display ok %1 && %2 even %0 , gether < una
return
```

## Example 2

```euo
; syntax =
;   gosub {subName} [parameters...]

gosub example_goSub These are the parameters

sub example_goSub
; %0 = 4
; %1 = These
; %2 = are
; %3 = the
; %4 = parameters
set %message
for %_cnt 1 %0
{
   set %message %message , % . %_cnt , #spc
}
display ok %message
halt
```
