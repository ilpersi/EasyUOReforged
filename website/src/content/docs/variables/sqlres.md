---
title: "#SqlRes"
description: "OK after a successful sql command, otherwise the error text."
kind: variable
category: sql
access: ro
type: string
origin: reforged
related: ["SQL", "#SqlCnt", "#SqlChanges"]
aliases: ["sql result", "sql error"]
---

`#SqlRes` is `OK` after a successful [`sql`](/commands/sql/) command. Otherwise it holds the error:
`no database open`, `SQLite library not available`, `interrupted` (the script was stopped during a query),
`database is locked`, or SQLite's own message such as `no such table: pets`.

It reads `N/A` until the script runs its first `sql` command.

An `sql` line never stops the script. When something goes wrong, `#SqlRes` says what, and the script goes
on with the next line, so check it after any command that matters.

## Example

```euo
sql open mychar.db
sql exec CREATE TABLE IF NOT EXISTS pets(id TEXT PRIMARY KEY, name TEXT)
if #SqlRes <> OK
  display ok SQL error: #SqlRes
halt
```
