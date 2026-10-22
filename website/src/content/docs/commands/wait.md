---
title: "Wait"
description: "Pauses the script for a time, in 50 ms ticks or seconds, plus an optional random extra."
kind: command
category: flow
syntax: "wait {time} [random]"
related: ["Sleep", "Pause"]
aliases: ["delay", "pause script"]
source: wiki
---

`wait` pauses the script.

## Parameters

| Parameter | Meaning |
|---|---|
| `time` | How long. A time is a number of **ticks** of 50 ms (`20` is one second), or a whole number of **seconds** followed by
`s` (`5s`). |
| `random` | Optional. Up to this much longer, a different random amount each time. Same units. |

For pauses in milliseconds, or shorter than one tick, use [`sleep`](/commands/sleep/). Pressing Stop ends
a `wait` at once.

## Examples

```euo
wait 20          ; 1 second
wait 5s          ; 5 seconds
wait 2s 1s       ; between 2 and 3 seconds
```
