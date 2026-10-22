# The `SQL` command

`SQL` lets a script keep data in an [SQLite](https://sqlite.org) database file: anything from a few
variables that survive a restart to real tables you can query. It is an EasyUO Reforged addition. The
original EasyUO has no such command, and nothing else in the language changes because of it.

```
sql open mychar.db
sql exec CREATE TABLE IF NOT EXISTS pets(id TEXT PRIMARY KEY, name TEXT, hp INTEGER)
sql exec INSERT OR REPLACE INTO pets VALUES(%petid, %petname, %pethp)
sql query SELECT name, hp FROM pets WHERE hp < %limit ORDER BY hp
for %i 1 #SqlCnt
{
  sql row %i                    ; sets %name and %hp
  display ok %name has %hp hp
}
if #SqlRes <> OK
  display ok SQL error: #SqlRes

sql load %kills                 ; restore last session's value
...
sql save %kills                 ; and keep it for the next one
```

## Commands

| Command | What it does |
|---|---|
| `sql open <file>` | Opens the database, creating the file if needed. A relative path is relative to `#CurPath` (the folder of `EasyUOReforged.exe`), the same rule as `call`. `sql open :memory:` gives a throw-away database that lives only until it is closed. An already open database is closed first. |
| `sql close` | Closes the database. A transaction you left open is rolled back. |
| `sql exec <statement>` | Runs one statement (`CREATE`, `INSERT`, `UPDATE`, `DELETE`, `BEGIN`, `COMMIT`, `PRAGMA`, …). Rows it returns are discarded; the result of the last `sql query` is kept. |
| `sql query <statement>` | Runs one statement and keeps the rows it returns. Row 1 is loaded into variables straight away. |
| `sql row <n>` | Loads row `n` (1 … `#SqlCnt`) of the last `sql query` into variables. |
| `sql save %a [!b …]` | Stores the variables' values in the database's `euo_vars` table. |
| `sql load %a [!b …]` | Restores those variables. One that was never saved is left as it is. |
| `sql delete %a [!b …]` | Removes those entries from `euo_vars`. |

Each script tab has **one** database connection. Scripts started with `call` share it. To use several
files at once, `sql exec ATTACH 'C:\data\other.db' AS other` and write `other.table`. `ATTACH` paths are
relative to the working directory of EasyUO Reforged, not to `#CurPath`, so give a full path.

The connection is closed when you press Play on a stopped script, when a script is loaded into the tab,
when the tab is closed, and by `sql open` / `sql close`.

## Variables

| Variable | Meaning |
|---|---|
| `#SqlRes` | `OK` after a successful `sql` command, otherwise the error text (`no database open`, `SQLite library not available`, or SQLite's own message such as `no such table: pets`). `N/A` until the script runs its first `sql` command. |
| `#SqlCnt` | Rows kept by the last `sql query`. Only `sql query`, `sql open` and `sql close` change it, so you can run `sql exec` inside a loop over the rows. |
| `#SqlChanges` | Rows inserted, updated or deleted by the last `sql exec` / `sql query`. For `sql save` / `load` / `delete`, the number of variables saved, found or removed. |
| `#SqlLastID` | The rowid of the last row inserted on this connection. |

An `sql` line never stops the script. When something goes wrong, `#SqlRes` says what, and the script
goes on with the next line. Check it with `if #SqlRes <> OK`.

## Writing statements

The statement is **everything after the second word of the line, exactly as written**. Unlike other
commands, nothing in it is substituted, merged or squeezed: quotes, commas, `.` and runs of spaces all
stay as they are.

- **Long statements** can continue on lines that start with `+`, like any EasyUO line. The pieces are
  joined *without* a space, so write `+ FROM pets` (with a space after the `+`) where SQL needs one.
- **One statement per line.** Only the first statement runs; everything after its `;` is ignored. That
  is why a normal EasyUO comment at the end of the line works:
  `sql exec DELETE FROM log ; clear the log`.
- **Table and column names cannot come from variables.** SQLite only accepts variables where a *value*
  goes, so `SELECT * FROM %table` is an error.

### Variables in a statement

Write `%x`, `!x` (current namespace), `#x` or `*x` wherever a value goes. Each one is passed to SQLite
as a separate value, never pasted into the statement text. A value containing `'`, `,` or `;` is
therefore stored exactly as it is and cannot break the statement.

```
sql exec INSERT INTO kills(mob, at, who) VALUES(%mob, #SysTime, !owner)
sql query SELECT * FROM pets WHERE id = %petid AND hp < %limit
```

How the variables are found:

- **Inside quotes nothing is replaced.** `'…'`, `"…"`, `[…]`, `` `…` `` and comments (`-- …`,
  `/* … */`) are copied unchanged, so `LIKE '%dog%'` is a plain pattern. This matches the rest of
  EasyUO, where `'%a'` is not substituted either. To use a pattern from a variable, put the whole
  pattern in it: `set %pat %dog%` … `WHERE name LIKE %pat`.
- **A variable has to start a word.** It counts only when the character before `%`, `!`, `#` or `*` is
  not a letter, digit or `_`. So `a % b`, `a%b`, `price * qty`, `price*qty`, `SELECT *`, `count(*)` and
  `!=` are ordinary SQL operators. Only `a %b` or `a *b` (operator glued to the right-hand side) would be
  read as a variable, and that gives a syntax error in `#SqlRes`. Write `a % b`.
- **How values are passed:**
  - A whole number written the normal way (`42`, `-7`) goes in as a number, so comparisons and
    `ORDER BY` sort numerically. `007`, `1.5` or `$1A` go in as text.
  - `N/A`, which is what an unset variable reads, goes in as SQL `NULL`.
  - Anything else goes in as text.

### Results

`sql query` and `sql row` put each column of the row into a `%` variable named after the column:
`SELECT name, hp FROM pets` sets `%name` and `%hp`.

- Rename columns with `AS` to choose the variable name, or to avoid overwriting one you use for
  something else: `SELECT name AS petname …`.
- Characters a variable name cannot have become `_`: `count(*)` lands in `%count___`, so prefer
  `SELECT count(*) AS n`. When two columns have the same name, the last one wins.
- SQL `NULL` reads back as `N/A`, the same as an unset variable.
- Numbers come back as text the usual way: `42`, `3.5`.

A query keeps all its rows in memory until the next `sql query`. Add a `LIMIT` when a table can be
large.

## Saving and loading variables

`sql save` / `sql load` / `sql delete` keep variables in a table called `euo_vars` (it is created when
first needed). It works like the `*` variables, but in a file of your choice instead of the registry.

```
sql open C:\EasyUO\mychar.db
sql load %kills %lastloot !settings      ; what was saved last time
...
sql save %kills %lastloot !settings      ; save for next time
```

- Write the variables as you normally would (`%kills`, not its value). Only `%` and `!` variables can
  be saved.
- Names do not depend on case. A `!` variable is saved under its plain name: `!x` saved in one
  namespace loads into `!x` of whatever namespace is current.
- `sql save` writes all the listed variables or none of them.
- `euo_vars` is an ordinary table. `sql query SELECT name, value FROM euo_vars` lists it.

## Several scripts and speed

- Several tabs can use the same file. While one is writing, the others wait up to 5 seconds before
  giving up with `database is locked` in `#SqlRes`.
- **Stop** interrupts a running query or a wait at once (`#SqlRes` reads `interrupted`).
- Each `sql exec` that changes data is its own transaction, which is slow for many rows. Wrap a batch
  in `sql exec BEGIN` … `sql exec COMMIT`.
- `sql exec PRAGMA journal_mode=WAL` lets readers and a writer work at the same time. It is a
  property of the file, so it stays on. SQLite then keeps two extra files (`-wal`, `-shm`) next to it.

## Requirements

Nothing to install. EasyUO Reforged uses the SQLite that ships with Windows 10 and 11
(`System32\winsqlite3.dll`). To use another SQLite build, put a **64-bit** `sqlite3.dll` next to
`EasyUOReforged.exe`; it is preferred when present. The library is only loaded when a script runs its
first `sql` line. If neither DLL can be loaded, every `sql` command sets `#SqlRes` to
`SQLite library not available`.

Text is stored exactly as the script has it. The files are ordinary SQLite databases that any SQLite
tool can open.
