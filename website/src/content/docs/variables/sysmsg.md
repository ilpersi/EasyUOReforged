---
title: "#SysMsg"
description: "The last system message the client showed."
kind: variable
category: journal
access: ro
type: string
needsClient: true
related: ["#Journal", "ScanJournal"]
aliases: ["system message"]
dll: SysMsg
changed: true
source: wiki
---

`#SysMsg` is the last system message the client showed, the text at the bottom left of the game window. Spaces
read as `_`. For a full history, use the journal with [`scanjournal`](/commands/scanjournal/).

## Example

```euo
if too_far_away in #SysMsg
  display ok Move closer.
halt
```

## Reforged notes

- Its text is UTF-8, as all of a script's text in Reforged: a letter with an accent matches the same letter written
  in the script, and [`str`](/commands/str/) counts it as one letter, as in EasyUO 1.5. See
  [Letters with accents](/language/variables/#letters-with-accents).
