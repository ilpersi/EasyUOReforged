---
title: "Terminate"
description: "Closes the client, or the EasyUO Reforged window."
kind: command
category: client
syntax: "terminate {uo|euo}"
related: ["UOXL", "#CliCnt"]
aliases: ["close client", "quit"]
dll: CloseClient
source: wiki
---

`terminate` closes something:

| Parameter | Effect |
|---|---|
| `uo` | Closes the client the script drives, then waits one second. [`#CliCnt`](/variables/clicnt/) and [`#CliNr`](/variables/clinr/) change accordingly. |
| `euo` | Closes the EasyUO Reforged window, as if you had closed it yourself. |

Without a parameter, `terminate` does nothing.

## Example

```euo
if #CharGhost = yes
  terminate uo
```
