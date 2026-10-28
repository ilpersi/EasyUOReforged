---
title: "menu Form"
description: "Creates another menu window, hidden, that the controls created after it go into."
kind: subcommand
category: menu
syntax: "menu Form {name} {x} {y} {width} {height} [title...]"
menuLogic: ['1.6']
related: ["menu Panel", "menu SetProp", "menu SetDef", "menu Delete", "#MenuButton"]
aliases: ["window", "new window", "dialog"]
credits: ['scriptuo']
---

`menu Form` creates a new window besides the main menu window. It starts hidden: show it with
[`menu SetProp`](/commands/menu/setprop/) `{name} visible #true`.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | The window's name, for [`menu SetProp`](/commands/menu/setprop/), [`menu Delete`](/commands/menu/delete/), [`menu SetDef parent`](/commands/menu/setdef/). |
| `x`, `y` | Position of the window on the screen. |
| `width`, `height` | Size of the inside. It comes out 10 pixels larger each way, as in EasyUO 1.6; `menu SetProp {name} width` and `height` set the exact size. |
| `title` | The title bar text; the rest of the line. |

## Description

- **Controls created after it go into it**, until another `menu Form` or [`menu Panel`](/commands/menu/panel/),
  [`menu SetDef parent`](/commands/menu/setdef/), [`menu PopDef`](/commands/menu/popdef/) or
  [`menu Clear`](/commands/menu/clear/). `menu SetDef parent form0` goes back to the main window.
- **Closing it** with its × hides it and puts its name in [`#MenuButton`](/variables/menubutton/). The main
  window's × gives `CLOSED` instead.
- It has the main window's frame: a fixed size, no maximize button, always on top, its own taskbar button.
- [`menu Delete`](/commands/menu/delete/) `{name}` removes it with everything in it.
- With [`menu GetProp`](/commands/menu/getprop/) and `menu SetProp`: `left`, `top`, `width`, `height` (the
  inside), `text` (the title), `visible`, `color`, `enabled`, `tooltip`.

## Example

```euo
menu Form opts 400 200 200 90 Options
menu Check loot 10 10 150 20 #true Loot corpses
menu Button ok 60 50 80 25 OK
menu SetProp opts visible #true
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu Get loot
set %loot #MenuRes
menu SetProp opts visible #false
display ok Loot corpses: %loot
halt
```

## Notes

- **Use a name only once.** When the name is taken, EasyUO 1.6 still creates the window, hidden and
  unreachable, and the controls created next go into it. A sub that builds a pop-up with `menu Form` each
  time it runs shows it only the first time: delete it first, or create it once.
- Starting the script again destroys every window it made.
