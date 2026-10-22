---
title: "exevent StatLock"
description: "Changes the stat locks on the different stats."
kind: subcommand
category: exevent
syntax: "Exevent StatLock {str|dex|int} {[up] | [down] | [locked]}"
needsClient: true
related: ["exevent"]
source: wiki
---

The Exevent StatLock command changes the stat lock on the specified stat to either: up, down or locked.

:::note
This command is only available from EUO 1.5 Test version 53.
:::

## Example

```euo
; changes dex to down
Exevent StatLock dex down
; locks str
Exevent StatLock str locked
```
