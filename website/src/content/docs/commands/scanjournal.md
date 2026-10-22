---
title: "ScanJournal"
description: "Scans the users journal and stores the string for examination."
kind: command
category: client
syntax: "scanJournal {index}"
needsClient: true
related: ["deletejournal"]
source: wiki
---

The scanJournal command scans the users journal and puts the matching string into the [#journal](/variables/journal/) system variable. The system variable [#jColor](/variables/jcolor/) is updated with the line's color.

The *index* specifies which line in the journal to use. 1 is the bottom line, 2 is the second to the last line and so on. If the index is 1000 or over it is considered a [#jIndex](/variables/jindex/) value.

## Example

```euo
; example 1 (old way)

waitForAttack:
scanjournal 1
if is_attacking_you in #journal
  msg guards $
goto waitForAttack

; example 2 (new way) (won't skip lines like the old way will)

set %jrnl #jindex
while #true
   {
   if #jindex > %jrnl
      {
      set %jrnl %jrnl + 1
      scanjournal %jrnl
      if is_attacking_you in #journal
         event macro 1 0 Guards
      }
   }
```
