---
title: "Menu"
description: "Builds a window of buttons, text, fields, lists and images that a script can show and read."
kind: command
category: menu
menuLogic: ['1.5', '1.6']
menuDiffers: true
credits: ['scriptuo']
syntax: "menu {element} [parameters...]"
related: ["#MenuButton", "#MenuRes", "#LPC"]
aliases: ["gui", "window", "dialog", "form"]
source: wiki
---

`menu` builds a small window of your own, the *menu window*, with text, buttons, edit fields, check boxes,
lists and images. The script shows it, reacts to clicks, and reads what the user typed or chose.

:::note[Two MENU systems]
EasyUO 1.5 and EasyUO 1.6 have different `menu` systems, and Reforged runs both: each script runs under one
of them, picked from what the script uses, or set with [`menu Reforge Mode`](/commands/menu/reforge/mode/).
This page describes what they share; every sub-command page says which has it. See
[MENU: EasyUO 1.5 and 1.6](/commands/menu/versions/).
:::

```euo
menu Clear
menu Window Title Loot settings
menu Window Size 220 110
menu Text lbl 10 12 Minimum gold:
menu Edit gold 110 10 90 100
menu Check bags 10 40 200 20 #true Also open bags
menu Button ok 70 75 80 25 Start
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
menu GetNum gold 100
set %mingold #MenuRes
menu Get bags
set %openbags #MenuRes
menu Hide
display ok Minimum gold %mingold open bags %openbags
halt
```

## How it works

- **Every control has a name**, chosen when you create it. Names are not case-sensitive. Use a different name
  for each control: [`menu Get`](/commands/menu/get/) reads only the first one with a name.
- **Clicks** put the button's name in [`#MenuButton`](/variables/menubutton/). Closing the window, with its
  × or with [`menu Hide`](/commands/menu/hide/), puts `CLOSED` there.
- **Values** are read with [`menu Get`](/commands/menu/get/) and [`menu GetNum`](/commands/menu/getnum/) into
  [`#MenuRes`](/variables/menures/), and changed with [`menu Set`](/commands/menu/set/).
- **Positions and sizes** are in pixels, from the top-left corner of the window's inside.
- The window stays open when the script stops. Start a script with [`menu Clear`](/commands/menu/clear/) so
  it doesn't add to an old menu.

### Fonts

[`menu Font …`](/commands/menu/font/name/) commands set the font, size, colours, style and alignment of the
controls created **after** them; controls that already exist keep theirs. [`menu Clear`](/commands/menu/clear/)
puts every font setting back to its default: Arial 10, black on the standard button colour, left-aligned,
plain, not transparent.

### Colours

Wherever a colour is asked for, give either:

- a **name**: `black`, `white`, `red`, `green`, `blue`, `yellow`, `navy`, `gray`, `silver`, … or a system
  colour such as `btnface` or `windowtext`;
- a **number** in Windows' order, `$BBGGRR`: blue first, red last. `$0000FF` is red, `$FF0000` is blue. A
  web colour `#0099FF` becomes `$FF9900`.

### Building big menus quickly

A script runs [`#LPC`](/variables/lpc/) lines (10 by default) and then pauses 50 ms, so a menu with a
hundred controls takes about half a second to appear. Put `set #LPC 1000` before building it.

## Commands

| Window | |
|---|---|
| [menu Show](/commands/menu/show/) / [menu Hide](/commands/menu/hide/) | Shows or hides the menu window. |
| [menu HideEUO](/commands/menu/hideeuo/) | Minimises EasyUO, leaving only the menu window. |
| [menu Window Size](/commands/menu/window/size/), [Title](/commands/menu/window/title/), [Color](/commands/menu/window/color/), [Transparent](/commands/menu/window/transparent/) | The window's size, title, colour and opacity. |
| [menu Clear](/commands/menu/clear/) / [menu Delete](/commands/menu/delete/) | Removes all controls, or one. |

| Controls | |
|---|---|
| [menu Text](/commands/menu/text/) | A label. |
| [menu Button](/commands/menu/button/) | A button. |
| [menu Edit](/commands/menu/edit/) / [menu Memo](/commands/menu/memo/) | A one-line / multi-line text field. |
| [menu Check](/commands/menu/check/) | A check box. |
| [menu Combo](/commands/menu/combo/) / [menu List](/commands/menu/list/) | A drop-down list / a list box. |
| [menu Shape](/commands/menu/shape/) | A rectangle, circle or other shape. |
| [menu Image Create](/commands/menu/image/create/) | An image to draw in or load a picture into: see the other `menu Image` commands. |

| Reading and changing | |
|---|---|
| [menu Get](/commands/menu/get/) / [menu GetNum](/commands/menu/getnum/) | Reads a control's value into `#MenuRes`. |
| [menu Set](/commands/menu/set/) | Changes a control's text or state. |
| [menu Activate](/commands/menu/activate/) | Gives a control the keyboard focus. |

| EasyUO 1.6 only | |
|---|---|
| [menu Form](/commands/menu/form/) | Another window. |
| [menu Panel](/commands/menu/panel/) | An area that holds controls. |
| [menu Radio](/commands/menu/radio/) | A radio button. |
| [menu GetProp](/commands/menu/getprop/) / [menu SetProp](/commands/menu/setprop/) | Reads or changes any property of a control or window. |
| [menu GetDef](/commands/menu/getdef/) / [menu SetDef](/commands/menu/setdef/) | Reads or changes what new controls are created with, and where they go. |
| [menu PushDef](/commands/menu/pushdef/) / [menu PopDef](/commands/menu/popdef/) | Saves and brings back those defaults. |

| Reforged settings | |
|---|---|
| [menu Reforge Mode](/commands/menu/reforge/mode/) | Chooses the 1.5 or the 1.6 MENU system for the script. |
| [menu Reforge IncludeCall](/commands/menu/reforge/includecall/) | Makes the automatic choice read called files too. |

## 1.5 and 1.6

What this page describes holds for both MENU systems, except where it speaks of names, `CLOSED` and the
start of a script, which follow the 1.5 rules. In the 1.6 logic a name belongs to one control, a click gives
the button's name in lower case, [`menu Hide`](/commands/menu/hide/) does not set `CLOSED`, and starting a
script destroys every menu window and creates a new, hidden one. The details, and a table of which
sub-command each system has, are on [MENU: EasyUO 1.5 and 1.6](/commands/menu/versions/).
