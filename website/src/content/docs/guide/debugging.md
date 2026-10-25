---
title: Editing and debugging
description: "Breakpoints, conditional breakpoints, stepping, run to cursor, the call stack, VarDump and the editor's autocomplete, code folding, Format Script and Find and Replace."
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

## Find and replace

*Edit → Find…* (**Ctrl+F**) and *Edit → Replace…* (**Ctrl+H**) open one window for both. It starts with
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
