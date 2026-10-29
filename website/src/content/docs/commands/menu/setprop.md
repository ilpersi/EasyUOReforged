---
title: "menu SetProp"
description: "Changes a property of a menu control or window: show or hide it, move it, recolour it, give it a tooltip."
kind: subcommand
category: menu
syntax: "menu SetProp {name} {property} {value...}"
menuLogic: ['1.6']
related: ["menu GetProp", "menu SetDef", "menu Set", "menu Form"]
aliases: ["property", "change property", "tooltip"]
credits: ['scriptuo']
---

`menu SetProp` changes one property of a control, or of a window made by [`menu Form`](/commands/menu/form/)
(the main window is `form0`). The properties are listed on [`menu GetProp`](/commands/menu/getprop/).

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The control or window. |
| `property` | Which property; not case-sensitive. |
| `value` | The new value; for text properties, the rest of the line. |

## Description

- **Text** properties (`text`, `tooltip`, `fontname`) take the rest of the line.
- **Numbers** must be written as numbers. A colour name such as `red` counts as 0, which is black: use
  `$0000FF` for red.
- **Yes/no** properties: `#true`, or any number other than 0, is yes.
- **`parent`** moves the control into another window or panel by its name, keeping its `left` and `top`.
  A label or an image cannot hold controls; neither can the control itself.
- **`width` and `height` of a form** set the size of its inside, exactly.

## Example

```euo
menu Form opts 300 200 200 100 Options
menu Button ok 60 60 80 25 OK
menu SetProp ok tooltip Saves the options and closes the window
menu SetProp ok fontstyle 1
menu SetProp opts color $C0FFC0
menu SetProp opts visible #true
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu SetProp opts visible #false
halt
```
