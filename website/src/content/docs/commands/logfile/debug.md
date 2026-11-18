---
title: "logfile Debug"
description: "Writes a message at the debug level to every target whose level lets it through."
kind: subcommand
category: logging
syntax: "logfile debug [text]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile level", "logfile set", "Log"]
---

`logfile debug` writes a message at the **debug** level. Details you want while writing or fixing a script. The four levels, from the lowest, are
`debug`, `info`, `warning` and `error`; the others are [`logfile info`](/commands/logfile/info/), [`logfile warning`](/commands/logfile/warning/), [`logfile error`](/commands/logfile/error/).

The message goes to every target, the Output panel and each file opened with
[`logfile open`](/commands/logfile/open/), as long as its level is at least the script's minimum
([`logfile level`](/commands/logfile/level/)) and that target's ([`logfile set`](/commands/logfile/set/)).
Each target writes it in its own format: `[Debug] text` in the Output panel, with the date, time, script
and line in a file.

## Parameters

| Parameter | Meaning |
|---|---|
| `text` | Optional. Everything after `debug`, with variables replaced by their values and the words joined by one space, as [`log`](/commands/log/) reads them. |

## Example

```euo
logfile open run run.log
logfile debug Hits are #Hits of #MaxHits
halt
```
