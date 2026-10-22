---
title: "Control structures"
description: "Labels, goto, subs and the other statements that control the flow of a script."
sidebar:
  order: 4
source: wiki
---

## Goto's

Goto's are an archaic and powerful command to automatically move to a different point in a program. They never [return](/commands/return/) unless another goto is used. They should **never** be used to return from a subroutine.

### label

A [label](/commands/label/) is a marker for the point a goto command will jump to. These are created by using any word that isn't a command, and suffixing it with a colon, like this...

```euo
mylabel:
```

### goto

A [goto](/commands/goto/) is used to jump directly to a label as defined above. This is accomplished by using [goto](/commands/goto/) {label}

```euo
goto mylabel
```

:::note
You must never use goto to jump out of a sub! Use return to properly terminate a sub routine. To prevent a stack overflow, EUO only supports 1000 consecutive GoSubs without returning. Remember this when using recursion! When the GoSub stack is about to get 1001 levels, the very first level in the bottom of the stack is deleted to make room.
:::

## Subs

The term *sub* is short for subroutine. Subs are an important feature of the EasyUO script that will make your scripts more logically structured, easier to read, and will make you have to write less code.

A basic sub definition starts with a sub statement followed by the subs name (sub names are case insensitive), a number of script lines and ends with a return statement.

```euo
sub testSub
  ...
  return
```

If parameters were added to the calling gosub command they will be present in the variables %1, %2, and so on. The variable %0 holds the number of parameters passed. As all variables are in the global scope, the %0, %1, %2.. will be overwritten if you call another sub from inside a sub.

### gosub

The gosub command transfers the execution to a sub with the name given by the parameter.

```euo
gosub sub_name
```

Parameters can be added after the sub name. They will be transfered in the variables %1, %2, and so on. The variable %0 holds the number of parameters passed.

### return

The **return** command transfers the execution back to where the sub was called using **gosub**.

```euo
return
```
