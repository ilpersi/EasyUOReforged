---
title: "#CliNr"
description: "Which of the running clients the script drives, counting from 1."
kind: variable
category: client
access: ro
type: number
related: ["#CliCnt", "UOXL"]
aliases: ["client number"]
dll: CliNr
source: wiki
---

`#CliNr` is the number of the client the script drives, from `1` to [`#CliCnt`](/variables/clicnt/), or `0` when
none is attached. Switch with [`uoxl swap`](/commands/uoxl/) or *Tools → Swap To Next Client*; `#CliNr` itself
cannot be set.

## Example

```euo
display ok This is client #CliNr of #CliCnt
halt
```
