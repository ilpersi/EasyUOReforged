---
title: "menu Window Color"
description: "Sets the background colour of the menu window."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Window Color {colour}"
related: ["menu Font BGColor", "menu Window Transparent"]
source: wiki
---

`menu Window Color` sets the background colour of the menu window.

A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number.

## Example

```euo
menu Clear
menu Window Size 200 40
menu Window Color $202020
menu Font Color white
menu Font BGColor $202020
menu Text t 10 10 Light text on a dark window
menu Show
halt
```
