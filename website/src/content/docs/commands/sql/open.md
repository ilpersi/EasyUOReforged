---
title: "sql Open"
description: "Opens an SQLite database file, found as call finds a script, or creates it if it doesn't exist."
kind: subcommand
category: data
syntax: "sql open {file|:memory:}"
origin: reforged
sets: ["#SqlRes", "#SqlCnt"]
related: ["sql close", "#CurPath", "call"]
aliases: ["search folders", "EUOPATH"]
---

`sql open` opens the database file for this script tab, creating it if it does not exist. An already open
database is closed first.

## Parameters

| Parameter | Meaning |
|---|---|
| `file` | The database file: a full path, or a name that is looked for in [`#CurPath`](/variables/curpath/) (the folder of `EasyUOReforged.exe`) and then in the search folders. When a file isn't found as written, `.db` and then `.sqlite` are added. See [Where sql open looks for the file](#where-sql-open-looks-for-the-file). |
| `:memory:` | A throw-away database that lives only until it is closed. |

## Where sql open looks for the file

`sql open` looks for an existing file in the places [`call`](/commands/call/) looks for a script, in the same
order, and takes the first it finds:

1. **A full path** (it starts with a drive, `C:\…`, or a backslash, `\…` or `\\server\…`) is used as written.
   No folder is searched.
2. **[`#CurPath`](/variables/curpath/)**, the folder of `EasyUOReforged.exe`.
3. **The folders of *Tools → Search Folders***, from the top of the list down.
4. **The folders of the `EUOPATH` environment variable**, from left to right.
5. **Only under [`EUOCli`](/guide/euocli/):** the folders given with `--euopath`, then those of the `euopath`
   argument of an MCP tool.
6. **Nothing found:** a new, empty database is made at the full path, or in `#CurPath` for a name. This is
   where `sql open` has always made it.

In each place `sql open` tries the name as written, then with `.db`, then with `.sqlite`, before it moves on
to the next one. So `sql open mychar` opens `mychar.db` in `#CurPath` before it looks in a search folder, and
a new file gets exactly the name you wrote. `/` is read as `\`.

The search folders, and how to set them, are described on the [`call` page](/commands/call/#the-search-folders-list-reforged).

## Example

```euo
sql open C:\EasyUO\mychar.db
if #SqlRes <> OK
  display ok Could not open the database: #SqlRes
halt
```

To keep one database for all your scripts, put it in a folder of *Tools → Search Folders*, for example
`C:\UO\Data\loot.db`. Every script then opens it by name, wherever the script is saved:

```euo
sql open loot
halt
```

To use several files at once, attach them: `sql exec ATTACH 'C:\data\other.db' AS other`, then write
`other.table`. `ATTACH` paths are relative to the working directory of EasyUO Reforged, not to `#CurPath`,
and the search folders are not searched, so give a full path.

See [Using SQL](/guides/sql/) for how statements are written and how variables go in and out.

## Changes in Reforged

- `sql open` used to look for a name in `#CurPath` only, as written. It now also finds an existing file in
  the search folders, and tries `.db` and `.sqlite`. `#CurPath` is still searched first, and a database that
  is found nowhere is made where it was made before.
