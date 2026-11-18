---
title: "LogFile"
description: "Writes log lines at a level (debug, info, warning, error) to the Output panel and to files, and writes plain text files."
kind: command
category: logging
syntax: "logfile {open|close|write|debug|info|warning|error|level|set} [arguments...]"
origin: reforged
sets: ["#LogRes"]
related: ["Log", "Call", "Execute", "#LogRes"]
aliases: ["write file", "save to file", "text file", "file output", "logging", "log level", "log to file", "echo to file", "append to file"]
---

`logfile` gives a script a logging system: messages at a level go to the **Output panel** and to **files**
the script opens, each with its own level and line format, and files can start again by size or every day.
The same command writes **plain text files**, for example a configuration of `set` lines that the script
loads back with [`call`](/commands/call/).

```euo
logfile open run mining.log          ; a log file, appended to
logfile set run daily                ; a new file each day
logfile info Started at #CharPosX #CharPosY
logfile set output level warning     ; only warnings and errors in the Output panel
logfile debug Ore count is %ore      ; in the file only
logfile warning Low on picks         ; in the file and in the Output panel
halt
```

The file then reads:

```text
2026-11-18 14:03:22.123 [Info] mining.euo:3 Started at 2471 115
2026-11-18 14:03:22.124 [Debug] mining.euo:5 Ore count is 12
2026-11-18 14:03:22.124 [Warning] mining.euo:6 Low on picks
```

## Sub-commands

| Command | What it does |
|---|---|
| [`logfile open`](/commands/logfile/open/) | Opens a file as a target with a name of your choice, appending or starting it empty. |
| [`logfile close`](/commands/logfile/close/) | Closes one file target, or all of them. |
| [`logfile write`](/commands/logfile/write/) | Writes a line exactly as given to one target: plain file writing. |
| [`logfile debug`](/commands/logfile/debug/), [`info`](/commands/logfile/info/), [`warning`](/commands/logfile/warning/), [`error`](/commands/logfile/error/) | A message at that level, to every target whose level lets it through. |
| [`logfile level`](/commands/logfile/level/) | The script's minimum level. |
| [`logfile set`](/commands/logfile/set/) | A target's level, line format, size rotation or daily rotation. |

## Targets

A **target** is where lines go. There is always one called `output`: the editor's
[Output panel](/commands/log/#the-output-panel), where [`log`](/commands/log/) writes too, and the output of
[`EUOCli run`](/guide/euocli/#run-a-script). [`logfile open`](/commands/logfile/open/) adds file targets,
as many as you like, each with a name you choose.

| | `output` | A file target |
|---|---|---|
| Level | `debug` (everything) | `debug` (everything) |
| Line format | `level`: `[Warning] Low on picks` | `date time level script line`: `2026-11-18 14:03:22.123 [Warning] mining.euo:6 Low on picks` |

[`logfile set`](/commands/logfile/set/) changes both. The level of a message is checked twice: against the
script's minimum ([`logfile level`](/commands/logfile/level/)), then against each target's.
[`logfile write`](/commands/logfile/write/) skips both checks and adds no fields.

## Plain text files

```euo
set %hp 50
logfile open cfg medic , #CharID , .txt new   ; one file per character, started empty
logfile write cfg #smc , Saved settings
logfile write cfg set % , hp %hp              ; writes: set %hp 50
logfile close cfg
call medic , #CharID , .txt                   ; sets %hp back
halt
```

This replaces the `execute cmd /c echo ... >> file` lines older scripts use, which wait two seconds each,
open a console window, break on `>`, `|`, `&` or `%` in the text, and say nothing when the file can't be
written. See [Save and load settings](/guides/patterns/#save-and-load-settings).

## Details

- **Words as `log` reads them.** The text is everything after the sub-command (after the target's name for
  `write`), with variables replaced by their values and the words joined by one space. A `$` stays a `$`. Glue
  words with `,` as anywhere else, and use [`#Spc`](/variables/spc/) for a real space.
- **A variable's name rather than its value**: glue it, `% , hp`, as in `set % , hp %hp`.
- **A line starting with `;`**: a word starting with `;` ends the script line, so write
  [`#Smc`](/variables/smc/) `, text`.
- **A comma on its own** can't be written: `a , b` is glued into `ab`. Inside a word, `a,b`, it stays.
- **Files are UTF-8, without a byte order mark, with Windows line ends**, so a file of `set` lines loads back
  with `call` exactly as written.
- **Nothing waits.** Each line goes straight to Windows, with nothing kept in memory, so a line is in the
  file at once, even if EasyUO Reforged closes.
- **Several scripts can write one file.** Every tab that opens the same file shares it, and lines never
  mix. Other programs can read the file meanwhile.
- **Files are closed** by `logfile close`, when the script stops (halt, Stop or an error), when you press
  Play again and when its tab is closed. A pause keeps them open.
- Every `logfile` line sets [`#LogRes`](/variables/logres/) to `OK` or to what went wrong. It never stops the
  script.

## EUOCli

Under [`EUOCli run`](/guide/euocli/#run-a-script) and the agent tool `euo_run`, a file target must be a
relative name inside the folder of `EUOCli.exe`, where `call` starts one too. Other names are refused in
`#LogRes`. `--allow logfile`, or `"allow": ["logfile"]` for `euo_run_live`, lifts this. Lines for `output`
are printed as `log` lines are.

## Reforged notes

`logfile` and [`#LogRes`](/variables/logres/) are new in EasyUO Reforged. A line starting with the word
`logfile` used to be ignored and is now this command; a [sub](/commands/sub/) or label called `logfile`
keeps working. [`log`](/commands/log/) is unchanged: it still writes every word after it, so `log info x`
writes `info x`.

`uo.dll` has no equivalent: a program using it writes its own files.
