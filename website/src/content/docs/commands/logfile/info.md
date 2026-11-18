---
title: "logfile Info"
description: "Writes a message at the info level to every target whose level lets it through."
kind: subcommand
category: logging
syntax: "logfile info [text]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile level", "logfile set", "Log"]
---

`logfile info` writes a message at the **info** level. What the script is doing: started, arrived, finished. The four levels, from the lowest, are
`debug`, `info`, `warning` and `error`; the others are [`logfile debug`](/commands/logfile/debug/), [`logfile warning`](/commands/logfile/warning/), [`logfile error`](/commands/logfile/error/).

The message goes to every target, the Output panel and each file opened with
[`logfile open`](/commands/logfile/open/), as long as its level is at least the script's minimum
([`logfile level`](/commands/logfile/level/)) and that target's ([`logfile set`](/commands/logfile/set/)).
Each target writes it in its own format: `[Info] text` in the Output panel, with the date, time, script
and line in a file.

## Parameters

| Parameter | Meaning |
|---|---|
| `text` | Optional. Everything after `info`, with variables replaced by their values and the words joined by one space, as [`log`](/commands/log/) reads them. |

## Example

```euo
logfile open run run.log
logfile info Hits are #Hits of #MaxHits
halt
```
