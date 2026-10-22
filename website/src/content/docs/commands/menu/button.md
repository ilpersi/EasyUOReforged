---
title: "menu Button"
description: "Creates a button at position x/y with specified size on the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Button {name} {x} {y} {width} {height} {text}"
source: wiki
---

The [menu Button](/commands/menu/button/) command creates a button on the EasyUO menu window at the specified postion with the specified size.

The #[MenuButton](/variables/menubutton/) system variable gives the name of the last button that was pressed.

## Example

```euo
; This will create a button named button_1 in position 10 20
; with a width of 50 and hight of 25. The text on the button
; will say Click me!
; Note that when refering to this button later in the script
; you will reference the NAME and not the displayed TEXT.
menu Button button_1 10 20 50 25 Click me!
```
