---
title: "menu GetNum"
description: "Returns the number in an edit field in the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu GetNum {name} {default}"
source: wiki
---

The [menu GetNum](/commands/menu/getnum/) command returns the number in an edit field in the EasyUO menu window in the [#menuRes](/variables/menures/) system variable. If the edit field does not hold a number, the default value is returned.

## Example

```euo
; This will save the text in the edit field named edit_1 into the
; variable #menuRes. If the field is blank it will save 144 into
; the variable #menuRes. This will only work for edit field items.
; #menuRes will return as a number.
menu GetNum edit_1 144
```
