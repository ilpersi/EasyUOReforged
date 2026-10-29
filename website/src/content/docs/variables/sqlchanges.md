---
title: "#SqlChanges"
description: "Rows changed by the last sql exec or query, or variables handled by save / load / delete."
kind: variable
category: sql
access: ro
type: number
origin: reforged
related: ["sql exec", "#SqlRes", "#SqlLastID"]
aliases: ["sql changes"]
---

`#SqlChanges` is the number of rows inserted, updated or deleted by the last
[`sql exec`](/commands/sql/exec/) or [`sql query`](/commands/sql/query/).

After [`sql save`](/commands/sql/save/), [`sql load`](/commands/sql/load/) or
[`sql delete`](/commands/sql/delete/) it is the number of variables saved, found or removed.

## Example

```euo
sql open :memory:
sql exec CREATE TABLE loot(item TEXT, at INTEGER)
sql exec INSERT INTO loot VALUES('gold', 100), ('gem', 200), ('arrow', 300)
set %cutoff 250
sql exec DELETE FROM loot WHERE at < %cutoff
display ok Removed #SqlChanges old entries.
halt
```
