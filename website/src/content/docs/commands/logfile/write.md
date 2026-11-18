---
title: "logfile Write"
description: "Writes a line exactly as given to one target: plain file writing."
kind: subcommand
category: logging
syntax: "logfile write {name} [text]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile open", "Call", "Log"]
aliases: ["write line", "append line"]
---

`logfile write` puts one line into the target with that name, exactly as written: no time, no level, and
whatever the levels are. It is how a script writes a plain text file, such as settings it reads back with
[`call`](/commands/call/). `logfile write output text` writes to the Output panel, as `log text` does.

## Parameters

| Parameter | Meaning |
|---|---|
| `name` | A target opened with [`logfile open`](/commands/logfile/open/), or `output`. |
| `text` | Optional. Everything after the name, with variables replaced by their values and the words joined by one space, as [`log`](/commands/log/) reads them. Without it, an empty line. |

## Example

A configuration of `set` lines, saved and loaded back:

```euo
set %bandages 50
set %home Britain_Bank
logfile open cfg medic , #CharID , .txt new
logfile write cfg #smc , Settings of #CharName
logfile write cfg set % , bandages %bandages
logfile write cfg set % , home %home
logfile close cfg
call medic , #CharID , .txt                  ; sets %bandages and %home again
halt
```

## Details

- `% , bandages` glues `%` and `bandages` after the variables are replaced, so the file gets the name
  `%bandages`; the next `%bandages` gets its value. Numbered names work the same way:
  `set % , x , %i , #spc , %x . %i` writes `set %x3 1234`.
- A word starting with `;` ends the script line, so a comment line is written with
  [`#Smc`](/variables/smc/): `#smc , text`.
- `$`, `>`, `|`, `&`, `^` and `%` are written as they are.
- In a settings file, a value must be one word: `call` reads `set %name Dr Who` as `Dr`.
  [Keeping data between runs](/guides/persistence/) compares settings files with `*` variables and `SQL`.
