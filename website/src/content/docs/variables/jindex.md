---
title: "#JIndex"
description: "Running number of the newest journal line; follow it to read every new line once."
kind: variable
category: extended
access: ro
type: number
needsClient: true
related: ["ScanJournal", "#Journal"]
aliases: ["journal index"]
source: wiki
---

`#JIndex` is the running number of the newest journal line: every new line gets the next number. Give such a
number to [`scanjournal`](/commands/scanjournal/) to read exactly that line. Remembering `#JIndex` and reading
every number up to the current one handles each new line exactly once, however many arrive at once.

## Example

```euo
set %from #JIndex + 1
msg #smc TestA$
msg #smc TestB$
wait 1s
for %n %from #JIndex
{
  scanjournal %n
  if TestB in #Journal
    event SysMessage Found it.
}
```
