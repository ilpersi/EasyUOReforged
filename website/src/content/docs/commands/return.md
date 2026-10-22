---
title: "Return"
description: "Ends a sub and goes back to the line after its gosub, optionally with a value."
kind: command
category: flow
syntax: "return [value]"
related: ["gosub", "sub", "#Result"]
source: wiki
---

`return` ends the [`sub`](/commands/sub/) it is in. The script goes on with the line after the
[`gosub`](/commands/gosub/) that called it.

## Parameters

| Parameter | Meaning |
|---|---|
| `value` | Optional. A value or [expression](/language/expressions/) to put in [`#Result`](/variables/result/). Without it, `#Result` reads `N/A`. |

A `return` that is not inside a sub called with `gosub` does nothing at all, and leaves `#Result` as it was.

## Example

```euo
gosub lowercase #CharName
event sysmessage My name is #Result
halt

; returns its first parameter in lower case
sub lowercase
  str lower %1
return #StrRes
```
