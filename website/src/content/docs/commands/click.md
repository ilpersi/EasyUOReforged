---
title: "Click"
description: "Clicks the mouse at a position in the client window."
kind: command
category: client
syntax: "click {x} {y} [option...]"
needsClient: true
related: ["event Drag", "Move", "#CursorX"]
aliases: ["mouse", "mouse click", "double click"]
dll: Click
source: wiki
---

`click` sends mouse clicks to the client window at the given position.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | Position in the client window, in pixels from its top-left corner. |
| `option` | Any of the options below, in any order. |

| Option | Effect |
|---|---|
| `d` | Double click. |
| `x {count}` | Click `count` times. Combined with `d`, each of them is a double click. |
| `r` | Use the right button. |
| `f` | Fast: no pause before each click. Without it, each click waits 150 ms first. |
| `g` | Press the button but don't release it: the start of a drag. |
| `p` | Release the button without pressing it: the end of a drag. |
| `n` | Neither press nor release. With `mc`, this only moves the cursor. |
| `mc` | Move the real mouse cursor to the position first. |
| `dmc` | Don't move the real mouse cursor. |

Whether the real cursor moves by default depends on **Tools → Don't Move Cursor**, which is on by default.
Some client actions, double clicks in particular, can be less reliable when the cursor does not move.

To move items, [`event Drag`](/commands/event/drag/) is simpler and more reliable than `click g` and
`click p`.

## Examples

```euo
; close the gump under 150,150 with a right click
click 150 150 r

; drag something from 100,100 and drop it at 200,300
click 100 100 g
wait 5
click 200 300 p
halt
```
