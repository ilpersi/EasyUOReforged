---
title: "logfile Open"
description: "Opens a file as a log target with a name of your choice, appending to it or starting it empty."
kind: subcommand
category: logging
syntax: "logfile open {name} {file} [append|new]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile write", "logfile close", "logfile set", "#CurPath"]
---

`logfile open` makes a file a **target** of the script: [`logfile write`](/commands/logfile/write/) writes to
it by its name, and the levels ([`logfile info`](/commands/logfile/info/) and the others) write to it with
every other target. The file is created if it does not exist, with its folders.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | Any word: what `write`, `close` and `set` call this target. Not `output`, which is the Output panel. |
| `file` | The file. A relative name starts from [`#CurPath`](/variables/curpath/) (the folder of `EasyUOReforged.exe`), the same rule as [`call`](/commands/call/). A name with spaces is glued: `C:\My , #Spc , Logs\run.log`. |
| `append` | The default: lines are added at the end of what the file holds. |
| `new` | The file is emptied first, as `>` did in the command prompt. |

Opening a name that is already open closes its file first. Several targets, in this script or in other
tabs, can open the same file: they share it, and their lines never mix.

A new file target writes every level, in the format `date time level script line`. Change that with
[`logfile set`](/commands/logfile/set/).

## Example

```euo
logfile open run logs\mining.log
if #LogRes <> OK
  display ok Can't write the log: #LogRes
logfile info Started
halt
```

[`#LogRes`](/variables/logres/) says why a file can't be opened: a folder that can't be made, a read-only
file, no right to write there, or, under [`EUOCli run`](/guide/euocli/#run-a-script), a name outside its
folder.
