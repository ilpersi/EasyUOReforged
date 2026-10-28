---
title: "#MenuRes"
description: "Value read by the last menu Get or menu GetNum."
kind: variable
category: result
menuDiffers: true
credits: ['scriptuo']
access: rw
type: string
related: ["menu Get", "menu GetNum", "#MenuButton"]
aliases: ["menu value"]
source: wiki
---

`#MenuRes` is the value read from a menu control by the last [`menu Get`](/commands/menu/get/) or
[`menu GetNum`](/commands/menu/getnum/). See `menu Get` for what each kind of control gives.

## Example

```euo
menu Clear
menu Window Size 180 80
menu Edit name 10 10 150 Bob
menu Button ok 10 45 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Get name
display ok The field says #MenuRes
halt
```

## 1.5 and 1.6

- **1.5:** keeps its value from one run to the next.
- **1.6:** is emptied when a script starts, and is also set by [`menu GetProp`](/commands/menu/getprop/) and
  [`menu GetDef`](/commands/menu/getdef/).
