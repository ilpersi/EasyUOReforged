---
title: "logfile Error"
description: "Writes a message at the error level to every target whose level lets it through."
kind: subcommand
category: logging
syntax: "logfile error [text]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile level", "logfile set", "Log"]
---

`logfile error` writes a message at the **error** level. Something that went wrong. The four levels, from the lowest, are
`debug`, `info`, `warning` and `error`; the others are [`logfile debug`](/commands/logfile/debug/), [`logfile info`](/commands/logfile/info/), [`logfile warning`](/commands/logfile/warning/).

The message goes to every target, the Output panel and each file opened with
[`logfile open`](/commands/logfile/open/), as long as its level is at least the script's minimum
([`logfile level`](/commands/logfile/level/)) and that target's ([`logfile set`](/commands/logfile/set/)).
Each target writes it in its own format: `[Error] text` in the Output panel, with the date, time, script
and line in a file.

## Parameters

| Parameter | Meaning |
|---|---|
| `text` | Optional. Everything after `error`, with variables replaced by their values and the words joined by one space, as [`log`](/commands/log/) reads them. |

## Example

```euo
logfile open run run.log
logfile error Hits are #Hits of #MaxHits
halt
```
