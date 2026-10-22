---
title: "menu Delete"
description: "Removes one control from the menu window."
kind: subcommand
category: menu
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
menu Delete button_1
```
