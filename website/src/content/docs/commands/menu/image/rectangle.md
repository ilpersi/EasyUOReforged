---
title: "menu Image Rectangle"
description: "Draws a rectangle within a specified image."
kind: subcommand
category: menu
syntax: "menu Image Rectangle {name} {x1} {y1} {x2} {y2} {color} {fill} [width]"
source: wiki
---

The *menu Image Rectangle* command draws a rectangle between x1/y1 and x2/y2 within the specified image. If fill is #false then only the outer line is drawn, otherwise the rectangle is filled.

For the color parameter, you can use names like "red", "yellow" or "windowtext" or use a hexadecimal number like $AABBCC (BBGGRR encoded). $FEEEED is used for transparency. If you do not fill the rectangle, you may also specify a line width (default is 1).
