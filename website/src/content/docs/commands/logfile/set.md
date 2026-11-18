---
title: "logfile Set"
description: "Sets a target's level, its line format, rotation by size or a new file each day."
kind: subcommand
category: logging
syntax: "logfile set {name} {level|format|rotate|daily} [values...]"
origin: reforged
sets: ["#LogRes"]
related: ["logfile open", "logfile level"]
---

`logfile set` changes one target: `output` (the Output panel) or a file opened with
[`logfile open`](/commands/logfile/open/).

| Option | What it sets |
|---|---|
| `level {debug\|info\|warning\|error\|off}` | The lowest level this target writes. `off` writes no message. |
| `format raw` | Messages are their text only. |
| `format {fields...}` | Any of `date`, `time`, `level`, `script`, `line`, written before the text in that order. |
| `rotate {size} [keep]` | A file only: when a line would make it bigger than `size`, it is renamed and a new one started. `size` in bytes, or with `k` or `m`: `500k`, `5m`. `keep` numbered files are kept (3 if not given). `rotate 0` stops it. |
| `daily [keep\|off]` | A file only: a new file each day. `keep` days are kept (7 if not given). `daily off` stops it. |

## Formats

| Field | Example |
|---|---|
| `date` | `2026-11-18` |
| `time` | `14:03:22.123` |
| `level` | `[Warning]` |
| `script` | `mining.euo`: the script's file, or the file [`call`](/commands/call/) runs; `main` for a script that is not saved |
| `line` | `42`, the line in that file: `mining.euo:42` with `script` |

A file target starts with `date time level script line`, the `output` target with `level`.
[`logfile write`](/commands/logfile/write/) adds no field, whatever the format.

## Rotation

By size, `run.log` becomes `run.1.log`, the old `run.1.log` becomes `run.2.log`, and so on; the oldest
beyond `keep` is deleted.

Each day, before the first line of a new day, `run.log` is renamed after the day it holds,
`run.2026-11-18.log`, and a new `run.log` is started; days beyond `keep` are deleted. A file opened again
the next morning is renamed first, because its last line is from the day before. With both on, the numbered
files of the day are renamed with it (`run.2026-11-18.1.log`).

When another program holds the file, the rename can fail: the line still goes to the current file, and
[`#LogRes`](/variables/logres/) says why.

## Example

```euo
logfile open run logs\farm.log
logfile set run format time level line
logfile set run rotate 1m 5
logfile set run daily 14
logfile set output level warning
logfile info Started
halt
```
