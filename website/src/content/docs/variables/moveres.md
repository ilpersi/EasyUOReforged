---
title: "#MoveRes"
description: "How the last moveitem ended: ok, left, refused, nolift, noitem, nodest, held or error."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["MoveItem", "#Result"]
aliases: ["moveitem result", "move result", "did it move"]
---

`#MoveRes` says how the last [`moveitem`](/commands/moveitem/) ended:

| Value | Meaning |
|---|---|
| `ok` | The item is in the destination. |
| `left` | It was moved, but the client can't see it in the destination (often a container you haven't opened). |
| `refused` | The server refused every drop; the item went back. |
| `nolift` | The server never let it be picked up. |
| `noitem` | The client doesn't know the item. |
| `nodest` | The client doesn't know the destination. |
| `held` | Something hung on the cursor. |
| `error` | A parameter was missing or wrong. |
| `N/A` | No `moveitem` has finished yet in this run. |

The [`moveitem`](/commands/moveitem/#results) page says where the item is after each of them. Only `left`,
`refused` and `ok` sent a drop; `nolift` sent pick-ups but no drop, and the rest sent nothing.

Pressing Stop during a `moveitem` leaves it as it was. `#MoveRes` has its own variable so that a `moveitem`
doesn't overwrite [`#Result`](/variables/result/), which holds what a sub returned.

## Example

```euo
set %bag ABCDEFG                     ; the ID of a bag in your backpack
finditem ZLK C_ , #BackpackID        ; logs
if #FindCnt > 0
{
  moveitem #FindID %bag
  if #MoveRes = left
    event sysmessage Moved, but open the bag to see it.
  if #MoveRes = nolift || #MoveRes = refused
    event sysmessage The logs did not move.
}
halt
```
