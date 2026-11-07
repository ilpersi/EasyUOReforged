---
title: "#WaitRes"
description: "How the last waitfor ended: #true if its condition was met, #false if the time ran out."
kind: variable
category: result
access: ro
type: boolean
origin: reforged
related: ["WaitFor", "#Result"]
aliases: ["waitfor result", "timed out"]
---

`#WaitRes` says how the last [`waitfor`](/commands/waitfor/) ended:

| Value | Meaning |
|---|---|
| `-1` (`#true`) | The condition was met. |
| `0` (`#false`) | The time ran out. |
| `N/A` | No `waitfor` has finished yet in this run. |

Pressing Stop during a `waitfor` leaves it as it was.

`#WaitRes` has its own variable so that a `waitfor` doesn't overwrite [`#Result`](/variables/result/), which holds what a
sub returned.

## Example

```euo
event macro 8 7
waitfor #ContName = container_gump 3s
if #WaitRes
  event sysmessage The backpack is open.
if ! #WaitRes
  event sysmessage The backpack did not open.
halt
```
