---
title: "#JFound"
description: "Running number of the journal line the last findjournal found, or 0 if it found none."
kind: variable
category: journal
access: ro
type: number
needsClient: true
origin: reforged
related: ["FindJournal", "#JIndex", "#Journal", "#JColor"]
aliases: ["journal match", "found journal line"]
---

`#JFound` says what the last [`findjournal`](/commands/findjournal/) found:

| Value | Meaning |
|---|---|
| a number above 0 | The running number of the line, the same numbering as [`#JIndex`](/variables/jindex/). |
| `0` | No line matched, or the time ran out. |
| `N/A` | No `findjournal` has finished yet in this run. |

Pressing Stop during a `findjournal` leaves it as it was.

Write `if #JFound > 0`. `if #JFound` alone is never true, because only `-1` counts as true.

The line itself is in [`#Journal`](/variables/journal/) and its colour in [`#JColor`](/variables/jcolor/). Setting your
bookmark to `#JFound` continues the search after this line, and [`scanjournal #JFound`](/commands/scanjournal/) reads the
same line again.

## Example

```euo
set %j #JIndex
msg hello there$
findjournal %j * 3s hello_there
if #JFound > 0
{
  set %j #JFound
  event sysmessage Found line #JFound
}
halt
```
