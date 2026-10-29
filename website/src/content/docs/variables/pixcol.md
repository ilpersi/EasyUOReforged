---
title: "#PixCol"
description: "Colour of the pixel last read by savepix, a $BBGGRR number."
kind: variable
category: misc
access: ro
type: number
needsClient: true
related: ["SavePix", "CmpPix"]
aliases: ["pixel colour", "color"]
source: wiki
---

`#PixCol` is the colour of the pixel last read by [`savepix`](/commands/savepix/). The colour is a number in
Windows' `$BBGGRR` order: blue, green, red, each from `$00` to `$FF`. It reads as an ordinary number, so compare
it with `$` numbers: `#PixCol = $0000FF` is pure red.

Pixels are read from the screen, so the client window has to be visible, and the same spot can give slightly
different values on different computers.

## Example

```euo
savepix 100 100 1
if #PixCol = $000000
  display ok Black.
halt
```
