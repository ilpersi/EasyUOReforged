---
title: "#SysMsg"
description: "The last system message the client showed."
kind: variable
category: extended
access: ro
type: string
needsClient: true
related: ["#Journal", "ScanJournal"]
aliases: ["system message"]
dll: SysMsg
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
