---
title: "SQL"
description: "Keeps data in an SQLite database file: raw SQL, or a quick save and load of variables."
kind: command
category: data
syntax: "sql {open|close|exec|query|row|save|load|delete} [arguments...]"
origin: reforged
sets: ["#SqlRes", "#SqlCnt", "#SqlChanges", "#SqlLastID"]
related: ["sql query", "#SqlRes"]
aliases: ["sqlite", "database"]
---

`SQL` lets a script keep data in an [SQLite](https://sqlite.org) database file: anything from a few
variables that survive a restart to real tables you can query. Nothing is installed: EasyUO Reforged uses
the SQLite that ships with Windows.

```euo
sql open mychar.db
sql exec CREATE TABLE IF NOT EXISTS pets(id TEXT PRIMARY KEY, name TEXT, hp INTEGER)
set %petid ABCDEFG
set %petname Buttercup
set %pethp 45
sql exec INSERT OR REPLACE INTO pets VALUES(%petid, %petname, %pethp)
set %limit 50
sql query SELECT name, hp FROM pets WHERE hp < %limit ORDER BY hp
for %i 1 #SqlCnt
{
  sql row %i                    ; sets %name and %hp
  display ok %name has %hp hp
}
if #SqlRes <> OK
  display ok SQL error: #SqlRes

sql load %runs                  ; restore last session's value
set %runs %runs + 1
display ok Run number %runs
sql save %runs                  ; and keep it for the next one
halt
```

## Sub-commands

| Command | What it does |
|---|---|
| [`sql open`](/commands/sql/open/) | Opens (or creates) the database file. |
| [`sql close`](/commands/sql/close/) | Closes it. |
| [`sql exec`](/commands/sql/exec/) | Runs one statement and discards any rows it returns. |
| [`sql query`](/commands/sql/query/) | Runs one statement and keeps its rows; row 1 is loaded into variables. |
| [`sql row`](/commands/sql/row/) | Loads another row of the last query into variables. |
| [`sql save`](/commands/sql/save/) | Stores variables in the database. |
| [`sql load`](/commands/sql/load/) | Restores them. |
| [`sql delete`](/commands/sql/delete/) | Removes saved variables. |

An `sql` line never stops the script. When something goes wrong, [`#SqlRes`](/variables/sqlres/) says
what, and the script goes on with the next line.

Each script tab has **one** database connection, shared with scripts started by `call`. It is closed when
you press Play on a stopped script, when a script is loaded into the tab, when the tab is closed, and by
`sql open` / `sql close`.

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out, and
[SQL or * variables?](/guides/sql-or-persistent-variables/) for when to use `SQL` instead of `*` variables.

## Reforged notes

`SQL` and the `#Sql…` variables are new in EasyUO Reforged. `SQL` is the only new command word; nothing
else in the language changes because of it, and the SQLite library is only loaded when a script runs its
first `sql` line.
