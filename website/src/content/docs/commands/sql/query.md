---
title: "sql Query"
description: "Runs one SQL statement, keeps its rows and loads row 1 into variables."
kind: subcommand
category: data
syntax: "sql query {statement}"
origin: reforged
sets: ["#SqlRes", "#SqlCnt", "#SqlChanges"]
related: ["sql row", "sql exec", "#SqlCnt"]
---

`sql query` runs one statement and keeps the rows it returns. [`#SqlCnt`](/variables/sqlcnt/) is the
number of rows, and row 1 is loaded straight away: each column goes into a `%` variable named after it.
Load the other rows with [`sql row`](/commands/sql/row/).

- `SELECT name, hp FROM pets` sets `%name` and `%hp`. Use `AS` to choose the variable name:
  `SELECT count(*) AS n …` sets `%n`.
- SQL `NULL` reads back as `N/A`, like an unset variable.
- All rows stay in memory until the next `sql query`. Add a `LIMIT` when a table can be large.

## Example

```euo
sql open :memory:
sql exec CREATE TABLE pets(name TEXT, hp INTEGER)
sql exec INSERT INTO pets VALUES('Rex', 80), ('Buttercup', 45), ('Fluffy', 20)
set %limit 50
sql query SELECT name, hp FROM pets WHERE hp < %limit ORDER BY hp
for %i 1 #SqlCnt
{
  sql row %i
  display ok %name has %hp hp
}
halt
```

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out.
