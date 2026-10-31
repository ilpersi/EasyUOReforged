---
title: Limitations
description: "What the MENU Designer cannot read or design, and what to watch for."
sidebar:
  order: 8
---

- **EasyUO 1.6's MENU only.** The designer writes and reads the [1.6 MENU system](/commands/menu/versions/).
  A script written for the 1.5 system loads as 1.6 (the load report says so), and its windows can differ.
- **What a script decides while it runs is not a design.** `menu` lines with variables, and what scripts
  read or change while running, are left out when a script is loaded: see
  [The load report](/designer/files/#the-load-report). A window a script builds in a loop, or from values it
  computes, loads as far as its plain `menu` lines go.
- **Saving writes the windows only**, not the rest of a script you opened: copy the subs into your script
  instead (see [Using the file in a script](/designer/scripts/)).
- **Controls that 1.6 cannot reach are not loaded:** a second control with a name already used, and controls
  left in no window. Controls moved into a button or another control that is not a form or a panel are not
  loaded either.
- **Texts are split into words** by the script, so some cannot be written as they are: two spaces in a row,
  words that read as variables or comments. The designer warns and writes what can be. See
  [Texts that cannot be written](/designer/inspector/#texts-that-cannot-be-written).
- **Sizes that come from fonts** (a text's size, an edit's and a combo box's height) are measured on your
  Windows, at your display scaling. On another machine they can differ by a few pixels.
- **A memo is Reforged only.** Real EasyUO 1.6 ignores [`menu Memo`](/commands/menu/memo/).
- **One component at a time in the inspector**, no copy and paste of components, no freehand drawing on an
  image: a drawing is a list of [`menu Image`](/commands/menu/image/line/) operations.
- **A picture file needs a name without spaces.** A name without a folder is looked for in the folder the
  program runs in; a name built with [`#CurPath`](/variables/curpath/) is a variable, and is not read.
