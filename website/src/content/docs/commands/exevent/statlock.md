---
title: "exevent StatLock"
description: "Sets the lock of strength, dexterity or intelligence."
kind: subcommand
category: exevent
syntax: "exevent StatLock {str|dex|int} {up|down|locked}"
needsClient: true
related: ["exevent SkillLock", "#Str", "#Dex", "#Int"]
aliases: ["stat lock"]
dll: StatLock
source: wiki
---

`exevent StatLock` sets whether a stat may go up, go down, or stay where it is.

## Parameters

| Parameter | Meaning |
|---|---|
| stat | `str`, `dex` or `int`. |
| lock | `up`, `down` or `locked`. |

## Example

```euo
exevent StatLock dex down
exevent StatLock str locked
halt
```
