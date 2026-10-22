---
title: "sql Row"
description: "Loads one row of the last sql query into variables."
kind: subcommand
category: data
syntax: "sql row {n}"
origin: reforged
sets: ["#SqlRes"]
related: ["sql query", "#SqlCnt"]
---

`sql row` loads row `n` (from `1` to [`#SqlCnt`](/variables/sqlcnt/)) of the last
[`sql query`](/commands/sql/query/) into `%` variables named after the columns. A number out of range leaves
the variables alone and sets `#SqlRes` to `row … out of range`.

## Example

```euo
sql query SELECT item, price FROM wanted
for %i 1 #SqlCnt
{
  sql row %i
  gosub buy %item %price
}
```

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out.
