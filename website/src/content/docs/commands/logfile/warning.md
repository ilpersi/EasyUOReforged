---
title: "logfile Warning"
description: "Writes a message at the warning level to every target whose level lets it through."
kind: subcommand
category: logging
syntax: "logfile warning [text]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile level", "logfile set", "Log"]
---

`logfile warning` writes a message at the **warning** level. Something the script can go on with, but you should know about. The four levels, from the lowest, are
`debug`, `info`, `warning` and `error`; the others are [`logfile debug`](/commands/logfile/debug/), [`logfile info`](/commands/logfile/info/), [`logfile error`](/commands/logfile/error/).

The message goes to every target, the Output panel and each file opened with
[`logfile open`](/commands/logfile/open/), as long as its level is at least the script's minimum
([`logfile level`](/commands/logfile/level/)) and that target's ([`logfile set`](/commands/logfile/set/)).
Each target writes it in its own format: `[Warning] text` in the Output panel, with the date, time, script
and line in a file.

## Parameters

| Parameter | Meaning |
|---|---|
| `text` | Optional. Everything after `warning`, with variables replaced by their values and the words joined by one space, as [`log`](/commands/log/) reads them. |

## Example

```euo
logfile open run run.log
logfile warning Hits are #Hits of #MaxHits
halt
```
