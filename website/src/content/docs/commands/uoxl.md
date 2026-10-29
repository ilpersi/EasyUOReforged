---
title: "UOXL"
description: "Starts another client, or switches the script to the next running one."
kind: command
category: client
syntax: "uoxl {new|swap}"
related: ["#CliNr", "#CliCnt", "Terminate"]
aliases: ["multiple clients", "switch client", "new client"]
dll: OpenClient
source: wiki
---

`uoxl` manages several clients.

| Parameter | Effect |
|---|---|
| `new` | Starts another client, like *Tools → New Client*. You are asked where `client.exe` is the first time. |
| `swap` | Makes the script drive the next running client, wrapping around after the last one, like *Tools → Swap To Next Client*. |

[`#CliCnt`](/variables/clicnt/) is the number of clients and [`#CliNr`](/variables/clinr/) the one the
script drives.

## Example

```euo
; say hello on every client
for %i 1 #CliCnt
{
  msg hello$
  uoxl swap
  wait 10
}
halt
```
