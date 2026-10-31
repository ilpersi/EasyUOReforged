---
title: Saving, loading and pasting
description: "The MENU Designer's .euo files: what is saved, what is read when a script is loaded or pasted, the load report and the overwrite warning."
sidebar:
  order: 6
---

The designer has one file format: a plain `.euo` script, the one shown in the script pane.

## Saving

*File → Save* writes the script pane's file: a header that runs the windows (see
[Using the file in a script](/designer/scripts/)), then one sub per form. The file is written as EasyUO
Reforged's editor writes scripts (UTF-8, Windows line endings), so it opens there unchanged. The grid and
snap settings are not in it.

## Loading and pasting

*File → Open* reads any `.euo` or `.txt` script, whether the designer wrote it or not. *File → Paste script*
(**Ctrl+Shift+V**) reads the script on the clipboard the same way. Editing the script pane and pressing
**Apply** (**Ctrl+Enter**) does too.

Open, Paste script and *File → New design* start a new design: **Undo** does not go back to the one before.
Apply changes the design on show, so Undo takes it back.

- **Only `menu` lines are read.** Every other command is ignored: `sub`, `gosub`, `if`, loops, `set` and the
  rest.
- **In the order they are written**, whatever runs around them: a `menu` line inside a loop is read once,
  one in a sub that is never called is read all the same.
- **As EasyUO 1.6 would run them**, by the same MENU code: the default parent after a
  [`menu Form`](/commands/menu/form/) or [`menu Panel`](/commands/menu/panel/),
  [`menu PushDef`](/commands/menu/pushdef/) and [`menu PopDef`](/commands/menu/popdef/),
  [`menu Clear`](/commands/menu/clear/), [`menu Delete`](/commands/menu/delete/). The windows that come out
  are the design, so a script the designer did not write loads too.
- `#true`, `#false`, `#spc`, `#smc` and `#dot` are read as their values. Any other variable is only known
  when the script runs.

## The load report

Lines that cannot be part of a design are left out and listed in *Messages* with their line number.
Double-click one to find it: until the next change, the script pane shows the text as it was read.

- a line with a variable (`menu Text t 10 10 %name`);
- what a running script reads or does: [`menu Get`](/commands/menu/get/), `GetNum`,
  [`menu GetProp`](/commands/menu/getprop/), `GetDef`, [`menu Activate`](/commands/menu/activate/);
- what EasyUO 1.6 removed: [`menu HideEUO`](/commands/menu/hideeuo/),
  [`menu Font Transparent`](/commands/menu/font/transparent/), [`menu Image PixLine`](/commands/menu/image/pixline/);
- a line EasyUO 1.6 does nothing with (a value missing or out of range), and an unknown sub-command;
- a name used twice: 1.6 shows the second control but nothing can reach it;
- a control that ended up in no window, or inside something that is not a form or a panel;
- `menu Delete form0`.

When EasyUO Reforged would run the text under the [1.5 MENU system](/commands/menu/versions/) (it has none of
the 1.6-only sub-commands and no `menu Reforge Mode` line), the report says so: the designer reads it as
1.6, and the file it saves starts with `menu reforge mode 1.6`.

## Saving over a script

Saving writes the MENU windows only. When the file you opened held more than that, the designer asks
first, and lists what would be lost:

- every line that is not a `menu` line (other than blank lines, comments and the designer's own header and
  subs);
- the `menu` lines it could not read.

Choose **Save anyway** to replace the file, **Save as** to write a new one and keep the original, or
**Cancel**. A file the designer saved itself saves over without asking.
