---
title: "menu Edit"
description: "Creates a edit field at position x/y with specified width in the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Edit {name} {x} {y} {width} {text}"
source: wiki
---

The [menu Edit](/commands/menu/edit/) command creates an edit field at the specified postion and with the specified dimensions in the EasyUO window menu.

## Example

```euo
; This will create an editable field named edit_1 in position 10 20
; with a width of 50 and hight of 25. The text in the field
; will say Change me!
; Note that when refering to this field later in the script
; you will reference the NAME and not the displayed TEXT.
menu Edit edit_1 10 20 150 Change , #spc , me!
```
