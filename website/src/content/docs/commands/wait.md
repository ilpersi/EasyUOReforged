---
title: "Wait"
description: "Waits a specified amount of time."
kind: command
category: client
syntax: "wait {time} [random time]"
needsClient: true
related: ["sleep"]
source: wiki
---

The wait command waits for a specified amount of time. Time is given in steps of 50 miliseconds by default, or in seconds by using the "s" specifier after the number.

Random time adds to the length of time the script waits, with a random time between 0 and the random time given.

## Example

```euo
; Wait for 5 seconds
wait 5s

; Wait for 1 second
wait 20

; Wait for 2 seconds with a random length of 1 second
wait 2s 1s
```
