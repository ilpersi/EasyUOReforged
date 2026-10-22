---
title: "menu Get"
description: "Returns the value associated with a control in the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Get {name}"
source: wiki
---

The [menu Get](/commands/menu/get/) command returns value associated with a control in the EasyUO menu window in the [#menuRes](/variables/menures/) system variable.

Usage with a combo box returns the index of the item selected within the combo box, starting with 0, for nothing selected.

Usage with a check box returns #true if the checkbox is checked, #false if it is not.

:::note
Clicking menu button's (including the window's close button) set's [#menuButton](/variables/menubutton/) without the need to use menu Get.
:::

## Example

```euo
; This will save the text in the edit field named edit_1 into the
; variable #menuRes. This will only work for edit field items.
; #menuRes will return as a string.
menu Get edit_1
```

## Example w/ ComboBox

```euo
menu show
menu combo create test 0 0 100
menu combo add test One
menu combo add test Two
menu combo add test Three
pause
menu get test
display ok #menures
```
