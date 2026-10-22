---
title: "#Random"
description: "A new random number from 0 to 999 each time it is read."
kind: variable
category: misc
access: ro
type: number
related: ["wait"]
aliases: ["random number", "dice"]
source: wiki
---

`#Random` is a random whole number from `0` to `999`, different each time you read it. Use `%` (remainder) to
bring it into a range.

## Example

```euo
set %a #Random % 100          ; 0 to 99
set %b #Random % 8 + 3        ; 3 to 10
```
