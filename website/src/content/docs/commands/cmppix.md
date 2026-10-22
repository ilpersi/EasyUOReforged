---
title: "CmpPix"
description: "Runs a line or block depending on whether a saved pixel still has the same colour."
kind: command
category: client
syntax: "cmppix {slot} [t|f] [lines]"
needsClient: true
related: ["SavePix", "#PixCol"]
aliases: ["compare pixel", "pixel colour"]
source: wiki
---

`cmppix` reads the pixel saved in a slot by [`savepix`](/commands/savepix/) again and compares it with the
colour saved there. Depending on the result, it runs the next line or block, or skips it, like an
[`if`](/commands/if/).

## Parameters

| Parameter | Meaning |
|---|---|
| `slot` | The slot `savepix` used, `0` to `1000`. |
| `t` / `f` | Optional. `t` (the default): run the next line or block when the colour is the **same**. `f`: run it when the colour is **different**. |
| `lines` | Optional. Without a block, how many of the following lines are controlled. Default: 1. |

As with `if`, a block's `{` has to be the very next line.

Pixels are read from the screen, so the client window has to be visible, not covered by another window.

## Example

```euo
; wait until the colour at 580,13 changes, then press Alt+F4
savepix 580 13 1
check:
cmppix 1 f
{
  key F4 alt
  halt
}
wait 5
goto check
```
