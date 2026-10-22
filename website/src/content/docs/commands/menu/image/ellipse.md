---
title: "menu Image Ellipse"
description: "Draws an ellipse/circle within a specified image."
kind: subcommand
category: menu
syntax: "menu Image Ellipse {name} {x1} {y1} {x2} {y2} {color} {fill} [width]"
source: wiki
---

The [menu Image Ellipse](/commands/menu/image/ellipse/) command draws an ellipse/circle within the specified image. x1/y1 and x2/y2 define the rectangle/square that encloses the ellipse. If fill is #false then only the outer line is drawn, otherwise the ellipse is filled.

For the color parameter, you can use names like "red", "yellow" or "windowtext" or use a hexadecimal number like $AABBCC (BBGGRR encoded). $FEEEED is used for transparency. If you do not fill the ellipse, you may also specify a line width (default is 1).
