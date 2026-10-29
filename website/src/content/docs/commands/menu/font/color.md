---
title: "menu Font Color"
description: "Sets the text colour of the controls created after it."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Font Color {colour}"
related: ["menu Font BGColor", "menu Window Color"]
source: wiki
---

`menu Font Color` sets the text colour of the controls created after it. The default is black.

A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number.

## Example

```euo
menu Clear
menu Window Size 200 40
menu Font Color red
menu Text warn 10 10 Low on reagents
menu Show
halt
```
