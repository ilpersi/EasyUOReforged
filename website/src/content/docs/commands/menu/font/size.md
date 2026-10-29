---
title: "menu Font Size"
description: "Sets the font size of the controls created after it."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
syntax: "menu Font Size {points}"
related: ["menu Font Name"]
source: wiki
---

`menu Font Size` sets the font size, in points, of the controls created after it. The default is 10.

## Example

```euo
menu Clear
menu Window Size 200 70
menu Font Size 14
menu Text title 10 10 Big title
menu Font Size 10
menu Text body 10 40 Normal text
menu Show
halt
```
