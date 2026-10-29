---
title: "sql Load"
description: "Restores % and ! variables saved with sql save."
kind: subcommand
category: data
syntax: "sql load {%var|!var} [...]"
origin: reforged
sets: ["#SqlRes", "#SqlChanges"]
related: ["sql save", "sql delete"]
---

`sql load` sets the listed variables to the values saved with [`sql save`](/commands/sql/save/). A variable
that was never saved is left as it is. [`#SqlChanges`](/variables/sqlchanges/) is the number found.

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
sql load %runs !lastloot         ; what was saved last time
set %runs %runs + 1
display ok Run %runs - last loot: !lastloot
set !lastloot gold
sql save %runs !lastloot         ; save for next time
halt
```
