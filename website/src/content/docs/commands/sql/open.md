---
title: "sql Open"
description: "Opens an SQLite database file, creating it if needed."
kind: subcommand
category: data
syntax: "sql open {file|:memory:}"
origin: reforged
sets: ["#SqlRes", "#SqlCnt"]
related: ["sql close", "#CurPath"]
---

`sql open` opens the database file for this script tab, creating it if it does not exist. An already open
database is closed first.

## Parameters

| Parameter | Meaning |
|---|---|
| `file` | Path of the database file. A relative path starts from [`#CurPath`](/variables/curpath/) (the folder of `EasyUOReforged.exe`), the same rule as [`call`](/commands/call/). |
| `:memory:` | A throw-away database that lives only until it is closed. |

## Example

```euo
sql open C:\EasyUO\mychar.db
if #SqlRes <> OK
  display ok Could not open the database: #SqlRes
```

To use several files at once, attach them: `sql exec ATTACH 'C:\data\other.db' AS other`, then write
`other.table`. `ATTACH` paths are relative to the working directory of EasyUO Reforged, not to `#CurPath`,
so give a full path.

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out.
