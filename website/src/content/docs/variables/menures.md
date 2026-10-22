---
title: "#MenuRes"
description: "Returns the result of the last menu Get or menu GetNum command."
kind: variable
category: result
access: rw
type: string
source: wiki
---

Holds the value from the last [menu Get](/commands/menu/get/) or [Menu GetNum](/commands/menu/getnum/) statement executed.

## Example

```euo
menu Clear
menu Window Title Example
menu Window Color BtnFace
menu Window Size 117 95
menu Font Transparent #true
menu Font Align Right
menu Font Name Default
menu Font Size 8
menu Font Style
menu Font Color Black
menu Font Align Left
menu Check CheckBox1 8 8 97 17 #false Check Box 1 ;<-- CheckBox not ticked = #False
menu Check CheckBox2 8 32 97 17 #true Check Box 2 ;<-- CheckBox ticked = #True
menu Font Name MS Sans Serif
menu Font Color WindowText
menu Button OKButton 40 64 35 25 OK
menu Show 421 270

MenuLoop:
Wait 1

If #MenuButton <> OKButton ;<-- Check to see if OK button has been pressed.
    Goto MenuLoop

Menu Get CheckBox1 ;<-- Gets the value from CheckBox1 menu item
If #MenuRes = #True ;<-- If #MenuRes is true the checkbox has been ticked
    Set %CheckBox1 #True
Else
    Set %CheckBox1 #False

Menu Get CheckBox2
If #MenuRes = #True
    Set %CheckBox2 #True
Else
    Set %CheckBox2 #False

Halt
```
