---
title: "CmpPix"
description: "Compares a current pixel to a previously saved pixel."
kind: command
category: client
syntax: "cmpPix {number} [true | false]"
needsClient: true
related: ["savepix"]
source: wiki
---

The cmpPix command compares the pixel given by {number} previously saved with [savePix](/commands/savepix/) command. If it evaluates to either true or false (given by the option) it will execute the next statement or statement block.

| Option | Description |
|----|----|
| **true** | Executes next statement if current pixel **equals** to the previously saved pixel. |
| **false** | Executes next statement if current pixel **differs** from the previously saved pixel. |

:::note
the UO client **must** be top most in order for savepix and #pixcol to work
:::

## Example

```euo
;Go to the client login screen and make
;sure your mouse cursor is not over the
;Quit button (upper right corner)
;Start the script and move your mouse
;over the Quit button. The client will
;close even if you don't make a click.

savePix 580 13 1
comparePixelAgain:
cmpPix 1 f
{
  key F4 Alt
  halt
}
goto comparePixelAgain
```
