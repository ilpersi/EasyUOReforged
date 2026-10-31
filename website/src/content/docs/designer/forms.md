---
title: Several forms
description: "Designing several menu windows in one MENU Designer file, and the subs they become."
sidebar:
  order: 5
---

One file can hold several windows: `form0`, the main window, and any number of
[forms](/commands/menu/form/), each on its own tab.

## Forms

- *Form → New form* adds one. It starts hidden, as every form does in EasyUO 1.6; set **Shown** to `yes`
  in the inspector for the script to show it.
- *Form → Move left / Move right* changes its place among the tabs, which is the order of the subs in the
  file. `form0` stays first.
- *Form → Delete form* deletes it with everything in it. `form0` cannot be deleted.

## Names

Every name is one word, and unique across **all** the forms: EasyUO 1.6 keeps one list of names for every
window, and a control whose name is taken cannot be reached. The designer refuses a name that is already
used, in this form or another. Names are kept in lower case, as 1.6 keeps them, and as
[`#MenuButton`](/variables/menubutton/) reports them.

## The subs

Each form is built by its own sub, `menu_` and the form's name: `menu_form0`, `menu_options`. A sub stands
on its own, so it builds the same form whichever subs ran before it:

- it first deletes what it is about to build, so calling it again rebuilds the form;
- it sets every default it uses (font, colours, alignment, parent) instead of relying on the last sub's;
- it never uses [`menu Clear`](/commands/menu/clear/), which would delete the other forms.

```euo
menu reforge mode 1.6
gosub menu_form0
gosub menu_opts
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
halt

sub menu_form0
  menu delete more
  menu window title Main
  menu window size 160 50
  menu window color BtnFace
  menu setdef parent form0
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu button more 40 12 80 25 Options
  menu show 100 100
return

sub menu_opts
  menu delete opts
  menu form opts 300 100 160 60 Options
  menu setprop opts width 160
  menu setprop opts height 60
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu check loot 10 20 140 20 #true Loot corpses
  menu setprop opts visible #true
return
```

## Sizes

A form's **Width** and **Height** are the size of its inside, as the script produces it. EasyUO 1.6 makes a
form 10 pixels larger than [`menu Form`](/commands/menu/form/) asks, so the sub sets the exact size with
`menu SetProp`, which is right on any Windows. Windows has a smallest size for a window with a title bar,
and the canvas shows a form asked to be smaller at that size.
