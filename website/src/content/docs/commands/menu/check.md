---
title: "menu Check"
description: "Creates a checkbox at position x/y with specified size on the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Check {name} {x} {y} {width} {height} {checked} {text}"
source: wiki
---

The **menu Check** command creates a checkbox on the EasyUO menu.

Name can be any valid EasyUO Name.

X, Y, width, and height are given in pixels.

Checked is either #true or #false.

Text is any descriptive text that will be placed in a label to the right of the actual text box.

## Example

```euo
; Creates a check box at 75 75, with a size of 60 10.
; The #false sets it to unchecked and Loot? is the label.

menu check Lootchk 75 75 60 10 #false Loot?

; To find if its checked or not

menu get Lootchk
set %loot #menures

; This sets %loot to #false if unchecked
; or #true if checked.
```
