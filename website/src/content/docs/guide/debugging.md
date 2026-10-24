---
title: Editing and debugging
description: "Breakpoints, conditional breakpoints, stepping, run to cursor, the call stack, VarDump and the editor's autocomplete, code folding and Format Script."
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
  your script already uses.
- **Ctrl+F** finds and replaces text.
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

Next: [troubleshooting](/guide/troubleshooting/).
