---
title: "#Journal"
description: "Returns the journal line selected using the scanJournal command."
kind: variable
category: extended
access: ro
type: string
source: wiki
---

The #journal system variable determines the journal line selected using the [scanJournal](/commands/scanjournal/) command.

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
while true
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
