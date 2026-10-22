---
title: "menu Image File"
description: "Loads an external image file."
kind: subcommand
category: menu
syntax: "menu Image File {name} {x} {y} {filename}"
source: wiki
---

The **menu Image File** command loads an external image file at position x/y within the specified image.

name is a valid EUO name. it should match the name used with the [menu Image Create](/commands/menu/image/create/) command.

The X and Y values provided to this command are relative to within the Image created with the [menu Image Create](/commands/menu/image/create/) command, not the window itself. Therefore, menu Image File Test 0 0 test.bmp will place the image at the top right of the image container, not the top right of the window.

filename must be a valid path to an existing file.

:::note
- This command is only available from EUO 1.5.
- The number of supported formats may depend on your OS, but BMP, GIF and JPG should always be suppored. File types that support transparency should also appear transparent in the image.
:::
