---
title: "Target"
description: "Waits for a target cursor to appear."
kind: command
category: client
syntax: "target {timeout}"
needsClient: true
related: ["event macro"]
source: wiki
---

The target command waits for a target cursor to appear. If no timeout is given, the default timeout is 2 seconds.

## Example

```euo
; This will pause the script until either the target cursor is displayed,
; or 3 seconds passes.
; Set the timout just over what you expect the delay to take, otherwise
; you may miss the target cursor and cause errors in your script.
target 3s
```
