---
title: "#SqlCnt"
description: "Number of rows the last sql query returned."
kind: variable
category: sql
access: ro
type: number
origin: reforged
related: ["sql query", "sql row", "#SqlRes"]
aliases: ["sql count", "sql rows"]
---

`#SqlCnt` is the number of rows kept by the last [`sql query`](/commands/sql/query/). Load any of them with
[`sql row`](/commands/sql/row/) `1` … `#SqlCnt`.

Only `sql query`, `sql open` and `sql close` change it, so you can run `sql exec` inside a loop over the rows.

## Example

```euo
sql query SELECT name, hp FROM pets ORDER BY hp
for %i 1 #SqlCnt
{
  sql row %i
  display ok %name has %hp hp
}
```
