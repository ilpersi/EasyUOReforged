---
title: "sql Save"
description: "Stores the values of % and ! variables in the database."
kind: subcommand
category: data
syntax: "sql save {%var|!var} [...]"
origin: reforged
sets: ["#SqlRes", "#SqlChanges"]
related: ["sql load", "sql delete"]
---

`sql save` stores the current values of the listed variables in the database. It writes all of them or none
of them. [`#SqlChanges`](/variables/sqlchanges/) is the number saved.

`sql save`, `sql load` and `sql delete` keep variables in a table called `euo_vars`, created when first
needed. It works like the `*` variables, but in a file of your choice instead of the registry.

- Write the variables as you normally would (`%kills`, not its value). Only `%` and `!` variables can be
  used.
- Names do not depend on case. A `!` variable is saved under its plain name: `!x` saved in one namespace
  loads into `!x` of whatever namespace is current.
- `euo_vars` is an ordinary table: `sql query SELECT name, value FROM euo_vars` lists it.

## Example

```euo
sql open mychar.db
sql load %kills %lastloot !settings      ; what was saved last time
...
sql save %kills %lastloot !settings      ; save for next time
```
