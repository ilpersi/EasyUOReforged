---
title: "sql Delete"
description: "Removes saved variables from the database."
kind: subcommand
category: data
syntax: "sql delete {%var|!var} [...]"
origin: reforged
sets: ["#SqlRes", "#SqlChanges"]
related: ["sql save", "sql load"]
---

`sql delete` removes the listed variables from the `euo_vars` table. The variables themselves keep their
values. [`#SqlChanges`](/variables/sqlchanges/) is the number removed.

`sql save`, `sql load` and `sql delete` keep variables in a table called `euo_vars`, created when first
needed. It works like the `*` variables, but in a file of your choice instead of the registry.

- Write the variables as you normally would (`%runs`, not its value). Only `%` and `!` variables can be
  used.
- Names do not depend on case. A `!` variable is saved under its plain name: `!x` saved in one namespace
  loads into `!x` of whatever namespace is current.
- `euo_vars` is an ordinary table: `sql query SELECT name, value FROM euo_vars` lists it.

## Example

```euo
sql open mychar.db
set %lastloot gold
sql save %lastloot
sql delete %lastloot
display ok Removed #SqlChanges saved variable
halt
```
