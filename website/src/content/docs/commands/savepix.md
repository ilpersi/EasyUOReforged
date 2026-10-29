---
title: "SavePix"
description: "Reads the colour of a pixel into #PixCol and a numbered slot for cmppix."
kind: command
category: client
syntax: "savepix {x} {y} {slot} [colour]"
needsClient: true
sets: ["#PixCol"]
related: ["CmpPix", "#PixCol"]
aliases: ["pixel", "read pixel"]
dll: GetPix
source: wiki
---

`savepix` reads the colour of the pixel at `x`, `y` in the client window. It stores it in
[`#PixCol`](/variables/pixcol/) and in a numbered slot, together with the position, for
[`cmppix`](/commands/cmppix/) to compare later.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | Position in the client window. |
| `slot` | Slot number, `0` to `1000`. |
| `colour` | Optional. Store this colour instead of reading the screen; `#PixCol` is not changed. |

Pixels are read from the screen, so the client window has to be visible, not covered by another window.

## Example

```euo
; remember the colour under the mouse in slot 1
savepix #CursorX #CursorY 1
display ok Colour #PixCol saved
halt
```
