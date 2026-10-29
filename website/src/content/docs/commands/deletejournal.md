---
title: "DeleteJournal"
description: "Hides the journal lines read so far from later scanjournal calls."
kind: command
category: client
syntax: "deletejournal"
needsClient: true
related: ["ScanJournal", "#JIndex", "#Journal"]
aliases: ["clear journal"]
source: wiki
---

`deletejournal` hides the line last read by [`scanjournal`](/commands/scanjournal/), and every older line,
from later `scanjournal` calls: they then read `N/A`. It marks text you have already handled, so it is not
handled twice.

:::tip
Following [`#JIndex`](/variables/jindex/) is simpler and never skips or repeats a line. `deletejournal` is
kept for older scripts.
:::

`deletejournal` takes no line number on purpose. If new lines arrive between `scanjournal` and
`deletejournal`, every line moves up, and a number would point at the wrong one. `deletejournal` remembers
which line `scanjournal` last read instead.

## Example

Check the last 10 lines, oldest first, and answer each "hail" once:

```euo
for %i 10 1
{
  scanjournal %i
  if hail in #Journal
  {
    msg Farewell$
    deletejournal
  }
}
halt
```
