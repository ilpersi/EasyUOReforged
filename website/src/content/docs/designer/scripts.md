---
title: Using the file in a script
description: "Running a MENU Designer file as it is, and building its windows from your own script with gosub."
sidebar:
  order: 7
---

## As it is

A saved file runs as it is. Its header builds every form, waits for a click or for a window to be closed,
and stops:

```euo
menu reforge mode 1.6
gosub menu_form0
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
halt

sub menu_form0
  menu delete ok
  menu window title Ready
  menu window size 160 50
  menu window color BtnFace
  menu setdef parent form0
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu button ok 40 12 80 25 OK
  menu show 100 100
return
```

## In your own script

Copy the subs, from the first `sub menu_` to the last `return`, to the end of your script, and:

1. **Put `menu reforge mode 1.6` at the top of your script.** It chooses the 1.6 MENU system for the whole
   run, and it works only in the main script: the one you press Play on, not one it calls. See
   [`menu Reforge Mode`](/commands/menu/reforge/mode/). (A script that already uses `menu Form`,
   `menu SetProp` or another 1.6-only sub-command gets 1.6 without it, but the line makes it certain.)
2. **`gosub` the subs** where the windows are needed. Calling one again rebuilds its form.
3. **Read what the user did** with [`#MenuButton`](/variables/menubutton/) (the name of the button clicked,
   or of the form closed, `CLOSED` for `form0`), and the controls with [`menu Get`](/commands/menu/get/).

```euo
menu reforge mode 1.6
gosub menu_form0
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
if #MenuButton = ok
{
  menu Get loot
  display ok Loot corpses: #MenuRes
}
halt

sub menu_form0
  menu delete loot
  menu delete ok
  menu window title Loot
  menu window size 180 70
  menu window color BtnFace
  menu setdef parent form0
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu check loot 10 10 160 20 #true Loot corpses
  menu button ok 50 38 80 25 OK
  menu show 100 100
return
```

To edit the windows later, open your script in the designer: it reads the `menu` lines and ignores the
rest. Save the result under another name and copy the subs back, because saving over your script would
replace it with the windows alone (the designer warns you; see [Saving over a script](/designer/files/#saving-over-a-script)).
