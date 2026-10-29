---
title: "ShutDown"
description: "Shuts down and powers off the computer."
kind: command
category: misc
syntax: "shutdown [force]"
related: ["Terminate", "Execute"]
aliases: ["power off", "turn off computer"]
source: wiki
---

`shutdown` shuts down Windows and powers off the computer. With `force`, programs that do not close by
themselves are closed anyway, and unsaved work in them is lost.

:::caution[Only run scripts you trust]
There is no setting to turn this command off: any script you run can use it.
:::

## Example

```euo
if #CharGhost = yes
  shutdown
halt
```
