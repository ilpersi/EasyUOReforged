---
title: "ScanJournal"
description: "Reads one journal line into #Journal and #JColor."
kind: command
category: client
syntax: "scanjournal [line]"
needsClient: true
sets: ["#Journal", "#JColor"]
related: ["DeleteJournal", "#JIndex", "#Journal", "#SysMsg"]
aliases: ["journal", "read journal", "chat"]
dll: GetJournal
source: wiki
---

`scanjournal` reads one line of the client's journal into [`#Journal`](/variables/journal/), and its colour
into [`#JColor`](/variables/jcolor/).

## Parameters

| Parameter | Meaning |
|---|---|
| `line` | Optional. `1` (the default) is the newest line, `2` the one before, and so on, up to 100 lines back. A number above 500 is a [`#JIndex`](/variables/jindex/) value instead: the line with that running number. |

`#Journal` reads `N/A` when the line does not exist, is too old, or was hidden by
[`deletejournal`](/commands/deletejournal/). Like every string variable, its spaces read as `_`.

## Examples

Following `#JIndex` handles every new line exactly once, however many arrive between two checks:

```euo
set %next #JIndex + 1
loop:
  while %next <= #JIndex
  {
    scanjournal %next
    if is_attacking_you in #Journal
      event macro 1 0 Guards!
    set %next %next + 1
  }
  wait 5
goto loop
```

The older way only looks at the newest line, so it can miss lines that arrive together:

```euo
check:
  scanjournal 1
  if is_attacking_you in #Journal
    msg guards$
  wait 5
goto check
```
