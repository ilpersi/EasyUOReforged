---
title: "menu Image Create"
description: "Creates a new image control in the menu."
kind: subcommand
category: menu
syntax: "menu Image Create {name} {x} {y} {width} {height}"
source: wiki
---

The **menu Image Create** command creates a new image control with the specified name at the given positions and dimensions.

name is any valid EUO name. It is used to reference the created container.

The X and Y parameters place the control at the specified position on the menu. These parameter's are in pixels, with 0,0 being the top left of the menu.

width and height are the size of the image container, in pixels.

:::note
- This command is only available from EUO 1.5.''
- The image is completely transparent at the beginning. For a different background, simply use [Menu Image Rectangle](/commands/menu/image/rectangle/)
:::
