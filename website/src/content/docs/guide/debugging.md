---
title: Editing and debugging
description: "Breakpoints, conditional breakpoints, stepping, run to cursor, the call stack, watches and the values a step changed, VarDump and the editor's autocomplete, code folding, Format Script, Ctrl+click to a sub or label, the outline and Find and Replace."
sidebar:
  order: 3
---

EasyUO Reforged adds IDE-style debugging to the classic Start / Pause / Stop controls. The shortcuts follow
the Delphi and Lazarus conventions.

## Breakpoints and stepping

| Key or menu | Action |
|---|---|
| **F5** | Toggle a breakpoint on the current line. |
| **F4** | Run to the cursor. |
| **F7** / **F8** / **F6** | Step into / step over / step out. |
| *Control → Breakpoint Condition…* | Make the breakpoint conditional. |
| *Control → Clear All Breakpoints* | Remove every breakpoint. |
| *Control → Show Call Stack* | A live panel of the nested [`gosub`](/commands/gosub/) calls. |
| **Ctrl+F5** | Add the variable under the cursor to the [watches](#watches). |

A **conditional breakpoint** only stops when its condition is true. The condition is a single comparison,
`<variable> <operator> <value>`, for example `%i > 10` or `#FindCnt = 0`:

- The variable can be any kind: `%`, `!`, `*` or `#`.
- The operator is one of `=`, `<>`, `>`, `<`, `>=`, `<=`.
- When both sides are whole numbers they are compared as numbers; otherwise as text, ignoring case. Put the
  value in double quotes to force a text comparison: `%code = "007"`.

It is not a full EasyUO expression: there is no `&&`, `||` or arithmetic.

## Looking at variables

While the script is paused, the variable inspector shows the live values. *Tools → VarDump* writes every
variable to a text window you can copy, which is handy for bug reports.

## Watches

The Watches panel, at the bottom of the window, follows the variables of the script in the current tab. It is
shown when the editor starts; *Control → Show Watches* hides it or shows it again, and the editor remembers
which. It has two parts, and a third while the script has lists:

- **Watches**: the variables you chose, in the order you added them.
- **Script variables**: every variable the script uses, found by itself. They are the `%`, `!`, `*` and `#`
  variables written in the script (outside comments), plus the ones the run made without their name written
  anywhere, such as `%list3` from `set %list . %i x`. They are listed `%` first, then `!`, `*` and `#`, each in
  A-Z order. `#true`, `#false`, `#spc`, `#smc` and `#dot` never change and are left out.
- **Lists**: each [list](/commands/list/) of the run, with its count and values: `3: iron | gold | agapite`.
  A double-click, **Enter** or *Edit Values…* on its right-click menu opens its values, one per line; change,
  add or remove lines and press OK, and the script goes on with the new values. It works while the script
  runs or is paused. Empty lines at the end are dropped, and no lines at all forgets the list.

**Adding a watch:**

- Put the cursor on a variable in the script, or select one, and press **Ctrl+F5** (*Control → Add Watch*, or
  *Add Watch* on the script's right-click menu). With no variable there, it asks for the name.
- In the panel, right-click a script variable and choose *Watch*, or choose *Add Watch…* to type a name.
- In the variable inspector, click a variable and choose *Add Watch*.

A watch is one variable name: `%name`, `!name`, `*name` or `#name`. Adding one opens the panel.

**While you step**, each time the script pauses (a step, a breakpoint or the [`pause`](/commands/pause/)
command), the variables whose value changed since the previous pause turn **red**, name and value. Hover over
one to see what it was. A
variable that had no value before was `N/A`. Nothing is red at the first pause of a run, and the red goes when
the script plays on or stops. Variables that change on their own, such as `#time`, `#scnt` or `#random`, turn
red at every step.

```euo
set %a 1
set %a 2       ; step here: %a and its value turn red, and its hint says it was 1
set %list . 3 x
halt
```

Right-click a row for *Remove Watch* (or **Delete**), *Clear Watches*, *Copy Name*, *Copy Value* and *Set
Value…* (or a double-click, or **Enter**). A value you set while paused does not count as a change at the next
step.

Each script file keeps its own watches: they come back when you open the file again. A new script keeps them
from its first *Save As*.

The call stack, the Watches panel and the Output panel share the bottom of the window, under the outline,
the script and the variable inspector, in that order from left to right. Each one shown gets an equal part of
the width; drag the bars between them to give one more room, and the bar above them to make them taller.
Which of them are shown, their height and the parts you dragged them to come back the next time you start
the app.

## The Output panel

[`log`](/commands/log/) writes a line to the Output panel without stopping the script: put it where you want
to know what the script saw.

```euo
finditem POF G_3
log finditem found #FindCnt stacks
halt
```

The panel opens by itself, at the bottom of the window, at the first line a script logs. Each line has the time, and
the tab's name when more than one tab is open. *Control → Show Output* shows or hides it and *Control → Clear
Output* empties it. It keeps the newest 5000 lines. When it is open as you close the app, it is open again
the next time, empty.

When the call stack or the [Watches panel](#watches) is shown too, they share the bottom of the window: the
call stack on the left, then the watches, then the Output panel. Drag the bars between them to give one more
room.

## Logging to a file

[`log`](/commands/log/) lines stay in the Output panel. To keep them, or to sort them by importance, use
[`logfile`](/commands/logfile/): its messages have a level (`debug`, `info`, `warning`, `error`), go to the
Output panel and to the files the script opens, each with its own level, and say the time, the script and the
line they come from.

```euo
logfile open dbg debug.log new            ; a fresh file for this run
logfile set output level warning          ; only problems in the panel
logfile debug Start: #CharPosX #CharPosY  ; in the file only
logfile warning Out of bandages           ; in both
halt
```

A script that runs for days can start a new file each day: `logfile set dbg daily`.

## Editor features

- **Ctrl+Space** opens autocomplete with the script commands, the built-in `#variables` and the variables
  your script already uses. After a command that takes a sub-command, it lists only those: after `menu`
  it offers `BUTTON`, `WINDOW`, `FONT`…, after `menu font` it offers `NAME`, `SIZE`, `ALIGN`…, and the same
  for `sql`, `event`, `exevent`, `namespace`, `str`, `tile`, `display`, `uoxl`, `ignoreitem` and
  `ignorecont`. Where only one word can go (`tile init` → `NOOVERRIDES`, `ignoreitem` → `RESET`), it is
  filled in straight away. To get a variable there instead, type its first character (`%`, `#`, …) before
  pressing **Ctrl+Space**.
- **Ctrl+F** / **Ctrl+H** open the Find and Replace window, described [below](#find-and-replace).
- **Ctrl+Shift+R** / **Ctrl+Shift+P** record and play back a keystroke macro in the editor. It repeats
  typing, not game actions.
- **Code folding**: click the **−** in the gutter to collapse a block, **+** to open it again. A `sub`
  folds from its `sub` line through its `return`, a `repeat` through its `until`, and a `{ }` block from
  its `{` line (the `if`, `else`, `for` or `while` line above it stays visible). *Edit → Fold All*
  (**Alt+Shift+1**) collapses everything, *Edit → Unfold All* (**Alt+Shift+0**) opens everything.
- **Format Script** (*Edit* menu, toolbar or **Ctrl+Shift+F**) re-indents the whole script: two spaces
  per level, braces lined up with the line that owns them, `sub` and `return` at the left with the body
  indented, and the one line under a brace-less `if` indented. It only changes the spaces at the start
  and end of lines, so the script runs exactly as before, and one **Ctrl+Z** undoes it. It is not
  available while a script runs.
- **Go to a sub or label**: hold **Ctrl** over the name after `gosub` or `goto`. When the script has
  that `sub` or label, the name is underlined; click it to jump there. *Edit → Go Back* (**Alt+Left**)
  returns to where you clicked, and pressed again goes further back. The jump goes where the script would
  go: to the last `sub` of that name when there are two, and to the nearest label, the one below first
  when two are as close. A name the script only knows when it runs, such as `gosub %next`, is not a link.

## The outline

The outline, the list left of the script, is an index of the script: its subs, its labels and the lines
that build [`menu`](/commands/menu/) windows. Click an entry to jump there, or select it and press
**Enter**. *Edit → Go Back* (**Alt+Left**) returns, as after a Ctrl+click.

| Entry | What it is |
|---|---|
| `sub Name` | A [`sub`](/commands/sub/). |
| `Name:` | A [label](/commands/label/). A label between a sub's `sub` line and its `return` is listed under the sub: click the **+** in front of the sub to see it. |
| `menu Title` | A [`menu Window Title`](/commands/menu/window/title/) line, where a script builds its menu window. |
| `menu form name` | A [`menu Form`](/commands/menu/form/) line, which makes another window. |

- **It follows the cursor**: the entry the cursor is in is selected. When that is a label in a closed sub,
  the sub is.
- **The filter box** above the list keeps the entries whose text matches, and the subs they are in, with
  every sub open. It works like the variable inspector's filter: a regular expression that ignores case,
  so plain text finds itself. A pattern with a mistake turns the box red and leaves the list as it was.
  **Esc** empties the box, **Enter** jumps to the selected entry (or the first), **Down** goes to the list.
- **A-Z**, next to the filter box, lists the entries by name instead of in script order, and the labels
  under each sub too.
- **A grey sub** is one no `gosub` reaches: no `gosub` in the script names it, or a later sub has the same
  name (`gosub` runs the last one). It is only a hint. A sub run with a name the script builds when it runs,
  such as `gosub %next`, or from another script with [`call`](/commands/call/), is grey too.
- *Control → Show Outline* hides it or shows it again. Drag the bar between it and the script to change its
  width. Whether it is shown, its width and its order are kept for the next time.

## Find and replace

*Edit → Find…* (**Ctrl+F**), *Edit → Replace…* (**Ctrl+H**) and the *Find/Replace* toolbar button open one
window for both; Ctrl+H puts the cursor in the *Replace* box. It starts with
the selected text, or the word under the cursor, already filled in (`#FindID`, `%item`: the `#` or `%` is
included).

| Key | Action |
|---|---|
| **Enter** / **F3** | Find the next match. |
| **Shift+Enter** / **Shift+F3** | Find the previous match. |
| **Esc** | Close the window. |

**F3** and **Shift+F3** also work in the editor with the window closed, with the last search.

- **Match case**, **Whole word**: the usual. `#` and `%` don't count as letters, so a whole-word
  search for `findid` matches inside `#findid`.
- **Regular expression**: a pattern such as `set (%\w+)`. In the Replace text, `$1`, `$2`… put back
  what the parentheses matched, so the pattern above with `var $1` turns `set %hp 10` into
  `var %hp 10`.
- **Wrap around** (on by default): carry on from the top after the last match. The status line says
  when it did.
- **Prompt on replace**: *Replace All* asks about each match: *Yes*, *No*, *Yes to All* or *Cancel*.
- **Scope**: the *current script*, the *selection* (selecting several lines before **Ctrl+F**
  picks it), or *all open scripts*, where Find Next moves on from tab to tab and Replace All
  replaces in every one.

While the window is open, every match in the script is highlighted and the status line counts them
(**3 of 12 matches**). *Replace* replaces the selected match and finds the next one; *Replace All*
replaces every match in the scope, and one **Ctrl+Z** undoes it in each script. A script that is
running can't be changed: *Replace All* skips it.

The last 20 searches and replacements are kept in each box's drop-down list, and the options are
remembered, both between sessions.

Next: [troubleshooting](/guide/troubleshooting/).
