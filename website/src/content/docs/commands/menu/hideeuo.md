---
title: "menu HideEUO"
description: "Minimises the EasyUO Reforged window and shows only the menu window."
kind: subcommand
category: menu
menuLogic: ['1.5']
credits: ['scriptuo']
syntax: "menu HideEUO"
related: ["menu Hide", "menu Show"]
source: wiki
---

`menu HideEUO` minimises the main EasyUO Reforged window and shows the menu window, so the user only sees
your menu. Closing the menu window, or [`menu Hide`](/commands/menu/hide/), brings the main window back.

## Example

```euo
menu Clear
menu Window Size 180 45
menu Button back 10 10 160 25 Bring EasyUO back
menu HideEUO
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Hide
halt
```

## 1.5 and 1.6

EasyUO 1.6 dropped `menu HideEUO`: under the 1.6 logic the line does nothing.
