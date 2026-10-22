---
title: "#LPC"
description: "Lines run per 50 ms cycle; 10 by default."
kind: variable
category: result
access: rw
type: number
related: ["LinesPerCycle"]
aliases: ["lines per cycle", "speed"]
source: wiki
---

`#LPC` is how many lines the script runs before each 50 ms pause; [`linespercycle`](/commands/linespercycle/)
sets the same value. It is `10` when a script starts. `0` and negative values are ignored.

Raise it for plain calculations, or to build a big [`menu`](/commands/menu/) window quickly; commands that wait
for the client take the time they need regardless.

## Example

```euo
set #LPC 1000
gosub buildmenu
set #LPC 10
```
