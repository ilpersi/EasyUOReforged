---
title: "menu Delete"
description: "Removes one control from the menu window."
kind: subcommand
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu Delete {name}"
related: ["menu Clear", "menu Set"]
source: wiki
---

`menu Delete` removes the control with that name from the menu window. If several controls share the name,
all of them are removed.

To change what a control shows, [`menu Set`](/commands/menu/set/) is lighter than deleting and creating it
again.

## Example

```euo
menu Clear
menu Window Size 220 60
menu Text keep 10 10 This line stays.
menu Text gone 10 30 This line goes in two seconds.
menu Show
wait 40
menu Delete gone
halt
```

## 1.5 and 1.6

- **1.5:** removes every control with that name.
- **1.6:** removes the one control the name belongs to. For a window ([`menu Form`](/commands/menu/form/)) or
  a [`menu Panel`](/commands/menu/panel/), everything in it goes too: what has a name is removed, what has
  none disappears. `menu Delete form0` removes the main window until the script is started again;
  [`menu Show`](/commands/menu/show/), [`menu Hide`](/commands/menu/hide/) and `menu Window` then do nothing.
