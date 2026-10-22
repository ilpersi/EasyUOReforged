---
title: "Control structures"
description: "Labels, goto, subs and the other statements that control the flow of a script."
sidebar:
  order: 4
source: wiki
---

A script runs from its first line down. These commands change that order. Each has its own page with the
details.

## Choosing: `if` and `else`

[`if`](/commands/if/) runs a line or block only when a condition is true; [`else`](/commands/else/) runs another
when it is false. Only `#true` (`-1`) counts as true.

```euo
if #Hits < 50
  gosub heal
else
  gosub fight
```

## Repeating

| Loop | Use it to |
|---|---|
| [`for`](/commands/for/) | Count through numbers. |
| [`while`](/commands/while/) | Repeat while a condition holds; test first. |
| [`repeat … until`](/commands/repeat/) | Repeat until a condition holds; test after each round. |

[`break`](/commands/break/) leaves a loop; [`continue`](/commands/continue/) skips to its next round.

```euo
for %i 1 10
  event SysMessage %i
while #Weight > #MaxWeight
  gosub dropsomething
```

## Jumping: labels and `goto`

A [label](/commands/label/) is a name followed by a colon, on a line of its own. [`goto`](/commands/goto/) jumps
to it. It is the simplest way to build the main loop of a script:

```euo
mainloop:
  gosub work
  wait 5
goto mainloop
```

Use `goto` within a part of the script, but never to leave a sub: that leaves the sub open.

## Subs: `sub`, `gosub` and `return`

A [sub](/commands/sub/) is a named group of lines ending with [`return`](/commands/return/). [`gosub`](/commands/gosub/)
runs it and comes back to the line after the `gosub`. Subs keep scripts short and readable: write something once,
use it from many places.

```euo
gosub greet Jim
halt

sub greet
  display ok Hello %1
return
```

- Parameters after the sub name arrive in `%1`, `%2`, …, and `%0` holds how many there are. These are ordinary
  variables shared by the whole script, so a sub that calls another sub loses its own `%1`, `%2`; copy them
  into variables of their own first.
- `return %value` hands a value back in [`#Result`](/variables/result/).
- Put subs after the main part of the script, where the normal flow never reaches them; see
  [`sub`](/commands/sub/) for why.
- To give a sub variables of its own, switch [namespace](/commands/namespace/) inside it.

## Other scripts: `call` and `exit`

[`call`](/commands/call/) runs another script file and comes back when it ends or reaches
[`exit`](/commands/exit/). In the main script, `exit` and reaching the last line both start the script over;
[`halt`](/commands/halt/) stops it.
