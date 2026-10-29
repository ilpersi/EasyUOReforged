---
title: "menu Activate"
description: "Gives a control the keyboard focus."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Activate {name}"
related: ["menu Edit"]
aliases: ["focus"]
source: wiki
---

`menu Activate` gives the keyboard focus to a control: an edit field, memo, button, check box, drop-down list
or list box. What the user types then goes into it.

## Example

```euo
menu Clear
menu Window Size 180 75
menu Edit name 10 10 150 Bob
menu Edit search 10 40 150
menu Show
menu Activate search     ; the cursor goes to the second field
halt
```

## 1.5 and 1.6

- **1.5:** gives the keyboard focus to an edit field, memo, button, combo box, list or check box in the menu
  window. Other controls are ignored.
- **1.6:** works on any control, in any window: it brings the control's window to the front and gives the
  control the focus if it can take it. Naming a window ([`menu Form`](/commands/menu/form/), or `form0`)
  brings that window to the front.
