---
title: "Log"
description: "Writes a line to the editor's Output panel, or to EUOCli's output, without stopping the script."
kind: command
category: misc
syntax: "log [text]"
origin: reforged
related: ["Display", "event SysMessage"]
aliases: ["print", "echo", "output", "debug", "trace", "write line"]
---

`log` writes a line of text for whoever is running the script. In the editor it appears in the **Output**
panel, with the time. Under [`EUOCli run`](/guide/euocli/#run-a-script) it is printed as the script goes.

It is the way to see what a script is doing while it runs:

- [`display`](/commands/display/) stops the script until you click, so it can't go in a loop.
- [`event sysmessage`](/commands/event/sysmessage/) needs a client, and the line scrolls away in the game.
- `log` never waits, needs no client, and the lines stay in the panel.

```euo
set %sum 0
for %i 1 5
{
  set %sum %sum + %i
  log After %i the sum is %sum
}
log Done.
halt
```

The Output panel then shows:

```text
14:03:09  After 1 the sum is 1
14:03:09  After 2 the sum is 3
14:03:09  After 3 the sum is 6
14:03:09  After 4 the sum is 10
14:03:09  After 5 the sum is 15
14:03:09  Done.
```

## Parameters

| Parameter | Meaning |
|---|---|
| `text` | Optional. Everything after `log`, with variables replaced by their values and the words joined by single spaces. Without it, an empty line. |

## Details

- **The text is not changed.** A `$` stays a `$` (in `display` it starts a new line), so you can log
  [`#Property`](/variables/property/) or a journal line exactly as the script reads it.
- **Words are joined by one space.** Several spaces in a row become one. Glue words with `,` as anywhere
  else: `log Position: , #CharPosX , / , #CharPosY`.
- **It sets no variable** and changes nothing a script can read.
- A [sub](/commands/sub/) or label called `log` keeps working: `gosub log` and `goto log` are not this command.

## The Output panel

The panel opens by itself, under the script, when a script logs its first line. *Control → Show Output*
shows or hides it, and *Control → Clear Output* empties it.

- There is one panel for all tabs. When more than one tab is open, each line also names its tab.
- It keeps the newest 5000 lines.
- Select text in it and press Ctrl+C to copy.

## Logging while you debug

```euo
finditem POF G_3
log finditem found #FindCnt stacks, the first is #FindID
if #FindCnt > 0
{
  event Property #FindID
  log Its tooltip: #Property
}
halt
```

## Reforged notes

`log` is new in EasyUO Reforged. No existing command changes because of it. It's the only change for old
scripts: a line starting with the word `log` used to be ignored and is now this command.

`uo.dll` has no equivalent: a program using it writes its own output.
