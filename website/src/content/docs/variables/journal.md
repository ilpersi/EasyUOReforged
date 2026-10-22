---
title: "#Journal"
description: "Journal line read by the last scanjournal."
kind: variable
category: extended
access: ro
type: string
needsClient: true
related: ["ScanJournal", "#JIndex", "#JColor", "#SysMsg"]
aliases: ["journal line", "chat"]
source: wiki
---

`#Journal` is the journal line read by the last [`scanjournal`](/commands/scanjournal/); its colour is in
[`#JColor`](/variables/jcolor/). Spaces read as `_`, so search it with `in`, writing `_` for spaces.

It reads `N/A` when the line does not exist, is too old, or was hidden by
[`deletejournal`](/commands/deletejournal/).

## Example

```euo
scanjournal 1
if is_attacking_you in #Journal
  event macro 1 0 Guards!
```

See [`scanjournal`](/commands/scanjournal/) for a loop that never misses a line.
