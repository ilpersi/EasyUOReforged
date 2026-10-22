---
title: "menu Hide"
description: "Hides the menu window, as if it had been closed."
kind: subcommand
category: menu
syntax: "menu Hide"
related: ["menu Show", "#MenuButton"]
source: wiki
---

`menu Hide` hides the menu window, the same way its × button does: [`#MenuButton`](/variables/menubutton/)
becomes `CLOSED`, and a main window hidden with [`menu HideEUO`](/commands/menu/hideeuo/) comes back. The
controls stay; [`menu Show`](/commands/menu/show/) shows the window again.

## Example

```euo
menu Hide
```
