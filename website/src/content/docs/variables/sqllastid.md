---
title: "#SqlLastID"
description: "Rowid of the last row inserted on this connection."
kind: variable
category: sql
access: ro
type: number
origin: reforged
related: ["sql exec", "#SqlChanges"]
aliases: ["sql last id", "rowid"]
---

`#SqlLastID` is the rowid of the last row inserted through the script tab's database connection. Use it to
link a new row to others, for example in a second table.

## Example

```euo
sql exec INSERT INTO trips(started) VALUES(#SysTime)
set %trip #SqlLastID
sql exec INSERT INTO loot(trip, item) VALUES(%trip, %item)
```
