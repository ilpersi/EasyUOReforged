---
title: "#Journal"
description: "Journal line read by the last scanjournal."
kind: variable
category: journal
access: ro
type: string
needsClient: true
related: ["ScanJournal", "FindJournal", "#JIndex", "#JColor", "#SysMsg"]
aliases: ["journal line", "chat"]
changed: true
source: wiki
---

`#Journal` is the journal line read by the last [`scanjournal`](/commands/scanjournal/) or found by the last
[`findjournal`](/commands/findjournal/); its colour is in [`#JColor`](/variables/jcolor/). Spaces read as `_`, so
search it with `in`, writing `_` for spaces.

It reads `N/A` when the line does not exist, is too old, or was hidden by
[`deletejournal`](/commands/deletejournal/).

## Example

```euo
scanjournal 1
if is_attacking_you in #Journal
  event macro 1 0 Guards!
halt
```

See [`scanjournal`](/commands/scanjournal/) for a loop that never misses a line.

## Reforged notes

- Its text is UTF-8, as all of a script's text in Reforged: a letter with an accent matches the same letter written
  in the script, and [`str`](/commands/str/) counts it as one letter, as in EasyUO 1.5. See
  [Letters with accents](/language/variables/#letters-with-accents).
