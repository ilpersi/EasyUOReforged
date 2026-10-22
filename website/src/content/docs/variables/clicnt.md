---
title: "#CliCnt"
description: "Number of supported UO clients running."
kind: variable
category: client
access: ro
type: number
related: ["#CliNr", "UOXL"]
aliases: ["client count"]
dll: CliCnt
source: wiki
---

`#CliCnt` is the number of supported UO clients running, the ones EasyUO Reforged can attach to. Clients of an
unsupported version, or that cannot be opened (for example because they run as administrator and EasyUO
Reforged does not), are not counted.

## Example

```euo
for %i 1 #CliCnt
{
  msg hello$
  uoxl swap
}
```
