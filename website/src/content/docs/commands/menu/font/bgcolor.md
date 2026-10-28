---
title: "menu Font BGColor"
description: "Sets the background colour of the controls created after it."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Font BGColor {colour}"
related: ["menu Font Color", "menu Font Transparent"]
source: wiki
---

`menu Font BGColor` sets the background colour of the controls created after it: behind a label's text,
inside an edit field or list, on a button. The default is the standard button colour, `btnface`.

A colour, see [Colours](/commands/menu/#colours): a name such as `red` or `btnface`, or a `$BBGGRR` number.

## Example

```euo
menu Font BGColor white
menu List Create lst 10 10 180 120
```
