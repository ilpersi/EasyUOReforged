---
title: "Execute"
description: "Opens a program, file or web address, as if you had double-clicked it."
kind: command
category: misc
syntax: "execute {file} [arguments...]"
related: ["Call", "Send", "Shutdown", "LogFile"]
aliases: ["run program", "open file", "start"]
changed: true
source: wiki
---

`execute` opens a program, a file or a web address, as Windows does when you double-click it: a program
runs, a document opens in its program, an address opens in the browser. The script then waits two seconds
and goes on; it does not wait for the program to finish.

## Parameters

| Parameter | Meaning |
|---|---|
| `file` | What to open. A path with spaces has to be glued together, as with [`call`](/commands/call/). |
| `arguments` | Optional. Passed to the program. |

:::caution[Only run scripts you trust]
There is no setting to turn this command off: any script you run can use it.
:::

## Examples

```euo
execute notepad.exe C:\EasyUO\notes.txt
execute https://github.com/ilpersi/EasyUOReforged
halt
```

Append a line to a text file with the command prompt:

```euo
set %task mining
execute cmd.exe /c echo %task #CharPosX #CharPosY >> C:\EasyUO\log.txt
halt
```

In EasyUO Reforged, [`logfile`](/commands/logfile/) writes the file itself: no two-second wait, no console
window, no trouble with `>`, `|`, `&` or `%` in the text, and [`#LogRes`](/variables/logres/) says when the
file can't be written:

```euo
set %task mining
logfile open notes C:\EasyUO\log.txt
logfile write notes %task #CharPosX #CharPosY
halt
```

## Reforged notes

- The program and its parameters go to Windows as Unicode, decoded from the script's UTF-8 text, so a path or a text
  with any letter works. EasyUO 1.5 passed them in the Windows code page. See
  [Letters with accents](/language/variables/#letters-with-accents).
