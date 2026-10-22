---
title: "#JIndex"
description: "Returns the index of the current journal entry."
kind: variable
category: extended
access: ro
type: number
source: wiki
---

The #jIndex system variable determines the index of the current journal entry. By calling [scanJournal](/commands/scanjournal/) with #jIndex as the parameter you will get the last line in the journal. By saving the value of #jIndex at appropriate times you can scan a section of the journal without ever losing a string.

## Example

```euo
set %success #false
; remember the journal position before something happened
set %jstart #jIndex + 1
; do something what we want to watch
msg #smc TestA$
msg #smc TestB$
msg #smc TestC$
wait 1s
; remember the journal position after something has happened
set %jend #jIndex
; loop through the journal checking each line between %jstart and %jend
for %ji %jstart %jend
{
    scanJournal %ji
    if TestB in #journal
        set %success #true ; found it
    msg #smc Interference$ ; new messages don't disturb the scan
}
; examine the result and act as required
if %success = #true
    display Ok Success
else
    display Ok Failure
halt

; Here is a little snippet to explaine the usage of this variable, its scans for the
; phrase "your char has been inactive" and makes a party message.

set %_jindex #jindex
scanloop:
   if #jindex >= %_jindex
   {
      scanjournal %_jindex
      if your_char_has_been_inactive in #journal
         msg /party stay active $
      set %_jindex %_jindex + 1
   }
wait 0
goto scanloop
```
