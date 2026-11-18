---
title: "#LogRes"
description: "How the last logfile line went: OK, or what went wrong."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["LogFile", "logfile open", "#Result"]
aliases: ["logfile result", "file error", "could not write"]
---

`#LogRes` says how the last [`logfile`](/commands/logfile/) line went: `OK`, or what went wrong, in words.
`N/A` until the script's first `logfile` line, and again when it is started over.

| Value | When |
|---|---|
| `OK` | It worked. A message below the levels counts: it was rightly left out. |
| `cannot open {file}: …` | The file can't be written: read-only, no right to write there, or held by a program that shares nothing. Windows says why. |
| `cannot create the folder {folder}` | The file's folder doesn't exist and can't be made. |
| `outside the program folder: {file}` | Under [`EUOCli run`](/guide/euocli/#run-a-script), a file target is a relative name inside its folder. |
| `no target {name}` | No target has that name: open it first. |
| `write failed on {file}: …` | The disk is full, or the file went away. |
| `cannot rotate {file}: …` | A rename for [rotation](/commands/logfile/set/#rotation) failed; the line went to the current file. |
| anything else | A word the sub-command doesn't take, such as `unknown level loud: …`. |

When a message goes to several targets and one of them fails, `#LogRes` names that one, and the others
still get the line. A `logfile` line never stops the script.

`#LogRes` has its own variable so that a `logfile` line doesn't overwrite [`#Result`](/variables/result/),
which holds what a sub returned.

## Example

```euo
logfile open cfg settings.txt new
if #LogRes <> OK
{
  display ok The settings can't be saved: #LogRes
  halt
}
logfile write cfg set % , runs 1
logfile close cfg
halt
```

## Reforged notes

`#LogRes` is new in EasyUO Reforged, with [`logfile`](/commands/logfile/).
