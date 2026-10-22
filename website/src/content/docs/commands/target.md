---
title: "Target"
description: "Waits until a target cursor appears, or the timeout passes."
kind: command
category: client
syntax: "target [timeout]"
needsClient: true
related: ["#TargCurs", "#LTargetID", "event Macro"]
aliases: ["wait for target", "target cursor"]
source: wiki
---

`target` waits until the client shows a target cursor. It returns at once if one is already showing.

## Parameters

| Parameter | Meaning |
|---|---|
| `timeout` | Optional. The longest to wait. Default: 2 seconds. A time is a number of **ticks** of 50 ms (`20` is one second), or a whole number of **seconds** followed by
`s` (`5s`). |

`target` does not say whether the cursor appeared. Check [`#TargCurs`](/variables/targcurs/) afterwards.

## Example

```euo
event macro 15 %spell        ; cast a spell that needs a target
target 3s
if #TargCurs = 1
  event macro 22 0           ; target the last target
```
