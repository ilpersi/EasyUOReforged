---
title: "Sub"
description: "Starts a named block of lines that gosub can call."
kind: command
category: flow
syntax: "sub {name}\n...\nreturn [value]"
related: ["gosub", "return", "goto"]
aliases: ["subroutine", "function", "procedure"]
source: wiki
---

`sub` starts a sub: a named group of lines that [`gosub`](/commands/gosub/) runs, ending with
[`return`](/commands/return/). Parameters passed by `gosub` are in `%1`, `%2`, … and their number is in
`%0`.

```euo
mainloop:
  gosub say hi
  wait 1s
goto mainloop

sub say
  event macro 1 0 %1
return
```

## Where to put subs

When the normal flow of the script reaches a `sub` line, it does not run the sub: it jumps over it, to the
line after the sub's **first** `return`. A sub with an early `return`, such as one inside an `if`, is
therefore not skipped completely: the script lands in the middle of it. Two ways to avoid that:

- **Put the subs after the main part of the script**, after its `halt` or its final `goto`, where the flow
  never reaches them. This is the usual layout.
- **Or wrap the body in a block** right after the `sub` line. The script then skips the whole block:

```euo
sub check
{
  if %x = 0
    return 0
  return 1
}
```

## Details

- Names are not case-sensitive. When two subs have the same name, `gosub` uses the last one in the script.
- Leave a sub with `return`, never with [`goto`](/commands/goto/).
