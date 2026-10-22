---
title: "#MenuRes"
description: "Value read by the last menu Get or menu GetNum."
kind: variable
category: result
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
menu Get name
set %name #MenuRes
```
