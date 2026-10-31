---
title: MENU Designer
description: "A program for laying out EasyUO menu windows on a canvas: it writes their script and reads such scripts back."
sidebar:
  order: 1
  label: Overview
---

The MENU Designer lets you lay out [`menu`](/commands/menu/) windows with the mouse instead of counting
pixels. Each window is shown exactly as the script will show it. The designer saves the script, a plain
`.euo` file, and opens such files again, including scripts it did not write.

It writes for the [EasyUO 1.6 MENU system](/commands/menu/versions/): forms, panels, radio buttons, the
properties of [`menu SetProp`](/commands/menu/setprop/). Every file it saves starts with
[`menu Reforge Mode 1.6`](/commands/menu/reforge/mode/). It does not write or read the 1.5 system's
single-window menus.

## Getting it

`EUOMenuDesigner.exe` is in the release zip, next to `EasyUOReforged.exe`
([Releases](https://github.com/ilpersi/EasyUOReforged/releases)). There is nothing to install, and it needs
no game client.

## The window

- **Palette** (top left): one button per kind of control, in alphabetical order. Click one, then click the
  form where it goes.
- **Structure** (left): every form, panel and control as a tree. Click one to select it; drag one onto a
  form or a panel to move it there.
- **Canvas** (centre): one tab per form. The form is built by the same MENU code that runs your scripts,
  so what you see is what the script shows.
- **Inspector** (right): the properties of the selected component. See [The inspector](/designer/inspector/).
- **Script** (bottom): the file the design saves as. You can edit it and press **Apply**. See
  [Saving, loading and pasting](/designer/files/).
- **Messages** (bottom right): what the designer had to change or leave out.

## A first form

1. Start `EUOMenuDesigner.exe`. The `form0` tab is the main menu window, the one
   [`menu Show`](/commands/menu/show/) shows.
2. In the inspector, set **Title** to `Hello`, **Width (inside)** to `200` and **Height (inside)** to `80`.
3. Click **text** in the palette, then click near the top left of the form. In the inspector, set its
   **Text** to `Ready when you are`.
4. Click **button**, then click below the text. Set its **Name** to `ok` and its **Text** to `OK`.
5. Press **F9** to preview the window; press it again to close it.
6. *File → Save* as `hello.euo`.

Open `hello.euo` in EasyUO Reforged and press Play: the window appears, and the script ends when you click
**OK** or close the window. The file looks like this:

```euo
; MENU windows made with the EasyUO Reforged MENU Designer
; Each form is built by its own sub, which can be called again to rebuild it.
menu reforge mode 1.6
gosub menu_form0
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
halt

sub menu_form0
  menu delete text1
  menu delete ok
  menu window title Hello
  menu window size 200 80
  menu window color BtnFace
  menu setdef parent form0
  menu font name Arial
  menu setdef fontsize 10
  menu setdef fontstyle 0
  menu font color Black
  menu font bgcolor BtnFace
  menu setdef alignment 0
  menu text text1 16 8 Ready when you are
  menu button ok 56 40 80 25 OK
  menu show 100 100
return
```

To build these windows in your own script, see [Using the file in a script](/designer/scripts/).

## Pages

- [The canvas](/designer/canvas/): adding, moving, resizing, aligning and snapping.
- [The inspector](/designer/inspector/): every property, and what it becomes in the script.
- [Components](/designer/components/): each kind of control, and what is special about it.
- [Several forms](/designer/forms/): more windows, and the subs they become.
- [Saving, loading and pasting](/designer/files/): what is read, the load report, the overwrite warning.
- [Using the file in a script](/designer/scripts/).
- [Limitations](/designer/limitations/).
