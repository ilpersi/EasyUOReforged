---
title: "Halt"
description: "Stops the script."
kind: command
category: flow
syntax: "halt"
related: ["stop"]
source: wiki
---

The *halt* command ends the execution of the script. The script cannot be restarted. This command does exactly the same as [stop](/commands/stop/).

## Example

```euo
if #findcnt < %amountNeeded
    halt
```
