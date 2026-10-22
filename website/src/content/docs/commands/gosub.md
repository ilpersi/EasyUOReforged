---
title: "Gosub"
description: "Runs a sub and comes back when it returns, optionally passing parameters."
kind: command
category: flow
syntax: "gosub {sub name} [parameter...]"
related: ["sub", "return", "#Result", "call"]
source: wiki
---

`gosub` runs the [`sub`](/commands/sub/) with the given name. When the sub reaches
[`return`](/commands/return/), the script goes on with the line after the `gosub`.

## Parameters

| Parameter | Meaning |
|---|---|
| `sub name` | Name of the sub. Case does not matter. |
| `parameter` | Optional values passed to the sub. Inside it, `%1`, `%2`, … hold them and `%0` holds how many there are. |

## Details

- **No sub with that name:** nothing happens and the script goes on with the next line.
- **Several subs with the same name:** the last one in the script is used.
- **Nesting:** about 1000 `gosub` calls can be open at once without returning. Beyond that the oldest one is
  dropped, so recursion that deep loses track of where to come back to.
- **Leave a sub with `return`**, never with [`goto`](/commands/goto/): every `gosub` that does not return
  stays open.

A sub can return a value in [`#Result`](/variables/result/): `return %value`.

## Examples

```euo
gosub greet Jim Bob
halt

sub greet
  ; %0 = 2, %1 = Jim, %2 = Bob
  display ok Hello %1 and %2
return
```

Any number of parameters, walked with `%0`:

```euo
gosub joinwords These are the parameters
display ok #Result
halt

sub joinwords
  set %message
  for %n 1 %0
    set %message %message , % . %n , #spc
return %message
```
