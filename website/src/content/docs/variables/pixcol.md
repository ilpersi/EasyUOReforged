---
title: "#PixCol"
description: "Returns the color of the pixel last saved with savePix."
kind: variable
category: misc
access: ro
type: number
source: wiki
---

Holds the color of the last pixel saved using [savePix](/commands/savepix/). The colors returned by #pixCol are in the format $BBGGRR (where BB = hex value of blue color channel, GG = hex value of green color channel, RR = hex value of red channel). All colors rendered on the screen are created from these 3 primary colors. Each color ranges from 0 (darkest) to 255 (brightest) -- or $00 to $FF.

:::note
- The client window **must** be unobscured by other windows in order for savePix and #pixColor to work.
- #pixCol values differ slightly from computer to computer.
- Most of the content of this page is shamelessly ripped off from a post that Cedryk made in the CC forum. Thanks for the knowledge Cedryk! --Kedrick Valorite
:::

## Example

```euo
sub TestColor
; pass   %1   Color to Test
;   %2   Color to Match
;   %3   Channel Similarity
  set %_ct %1
  set %_cm %2
  set %_cs %3
  gosub ColorChannels %_cm
  set %_rm %r
  set %_bm %b
  set %_gm %g
  gosub ColorChannels %_ct
  set %_rd %r - %_rm abs
  set %_bd %b - %_bm abs
  set %_gd %g - %_gm abs
  set %_result ( %_rd <= %_cs ) && ( %_bd <= %_cs ) && ( %_gd <= %_cs )
return %_result
```
