---
title: "Execute"
description: "Opens a program, file or web address, as if you had double-clicked it."
kind: command
category: misc
syntax: "execute {file} [arguments...]"
related: ["Call", "Send", "Shutdown"]
aliases: ["run program", "open file", "start"]
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
```

Append a line to a text file with the command prompt:

```euo
execute cmd.exe /c echo %task #CharPosX #CharPosY >> C:\EasyUO\log.txt
```
