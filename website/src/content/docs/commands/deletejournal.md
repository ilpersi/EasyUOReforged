---
title: "DeleteJournal"
description: "Forgets the contents of the journal buffer."
kind: command
category: client
syntax: "deleteJournal"
needsClient: true
related: ["scanjournal"]
source: wiki
---

deleteJournal is considered obsolete and is only kept for backwards compatibility. Please see the documentation for the system variable [JIndex](/variables/jindex/) for example snippets.

The deleteJournal command forgets the contents of the journal from the last read line (inclusive) and everything above so that it cannot be found using scanJournal.

Here is how the example works: Since it happens quite often that several entries get written into the journal between two checks you should scan more than just the first line of the journal. 10 lines is a very good value to make sure you don't miss any new journal text. You must use deleteJournal to mark the text you have already processed so that it does not get interpreted multiple times.

Imagine you manage to say "Hail" three times in a very short time. The example script finds the first "Hail" on line 3, says "Farewell" and forgets line 3 and everything above (because line 3 was the last line read by scanJournal). As the For loop proceeds it will find the other two "Hails" and react as intended.

The very perceptive reader might be asking himself/herself why you cannot just specify the line number as a parameter of deleteJournal. To answer that question, imagine that the journal gets two new entries right when script execution is between scanJournal and deleteJournal. So when the script recognizes the first "Hail" on line 3 and says the "Farewell", line 1 and 2 get moved up by two lines (because of those two new journal entries) and are now on line 3 and 4 which would then be ignored by "deleteJournal 3". That is why deleteJournal determines itself which line is to be ignored.

## Example

```euo
for %i 10 1
{
 scanJournal %i
 if hail in #journal
 {
   msg Farewell$
   deleteJournal
 }
}
```
