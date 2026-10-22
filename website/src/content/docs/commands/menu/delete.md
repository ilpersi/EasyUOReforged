---
title: "menu Delete"
description: "Deletes a window element from the EasyUO menu window."
kind: subcommand
category: menu
syntax: "menu Delete {name}"
source: wiki
---

The *menu Delete* command deletes a window element (i.e. text, button, edit) from the EasyUO window menu.

## Example

```euo
; This will remove the menu item named button_1 from the current menu
; and from memory. Please use this command and do not just create
; new items over old ones. This is expecially important when using
; menu Text items, as they sometimes need to be updated regularly.
menu Delete button_1
```
