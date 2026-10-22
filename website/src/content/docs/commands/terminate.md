---
title: "Terminate"
description: "Terminates the current client."
kind: command
category: client
syntax: "terminate [{\"uo\"} | {\"euo\"}]"
needsClient: true
related: ["uoxl", "execute"]
source: wiki
---

The terminate command terminates the current client or the current EasyUO instance. If the current client is terminated the system variables #cliNr and #cliCnt are updated accordingly.

| uo (default) | Closes the current UO client |
|---|---|
| euo | Closes the current EasyUO instance |

## Example

```euo
; This will cause the script containing this line to close and will NOT
; automatically save your work!
terminate euo
```
