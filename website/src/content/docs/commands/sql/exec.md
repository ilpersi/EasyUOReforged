---
title: "sql Exec"
description: "Runs one SQL statement and discards any rows it returns."
kind: subcommand
category: data
syntax: "sql exec {statement}"
origin: reforged
sets: ["#SqlRes", "#SqlChanges", "#SqlLastID"]
related: ["sql query", "#SqlChanges"]
---

`sql exec` runs one statement: `CREATE`, `INSERT`, `UPDATE`, `DELETE`, `BEGIN`, `COMMIT`, `PRAGMA`, …
Rows it returns are discarded, and the rows of the last [`sql query`](/commands/sql/query/) are kept, so
you can run `sql exec` inside a loop over a query's rows.

The statement is everything after `sql exec`, exactly as written. `%x`, `!x`, `#x` and `*x` where a value
goes are passed to SQLite as values, never pasted into the text.

## Example

```euo
sql open mychar.db
sql exec CREATE TABLE IF NOT EXISTS kills(mob TEXT, at INTEGER)
set %mob orc
sql exec INSERT INTO kills(mob, at) VALUES(%mob, #SysTime)
display ok Row #SqlLastID added
halt
```

Each `sql exec` that changes data is its own transaction, which is slow for many rows. Wrap a batch in
`sql exec BEGIN` … `sql exec COMMIT`.

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out.
