---
title: "menu GetNum"
description: "Reads a control into #MenuRes, with a default when it is not a number."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu GetNum {name} [default]"
sets: ["#MenuRes"]
related: ["menu Get", "#MenuRes"]
source: wiki
---

`menu GetNum` works like [`menu Get`](/commands/menu/get/), but when the value is not a number (an empty
field, or text), [`#MenuRes`](/variables/menures/) gets `default` instead. Without a default, the value is
left as it is.

A number here is a whole number, optionally with a sign (`-5`), or a hexadecimal number starting with `$`.

## Example

```euo
menu GetNum delay 20
set %delay #MenuRes      ; 20 when the field is empty or not a number
```

## 1.5 and 1.6

- **1.6:** also reads [radio buttons](/commands/menu/radio/), as [`menu Get`](/commands/menu/get/) does.
