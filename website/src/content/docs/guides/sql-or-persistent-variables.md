---
title: "SQL or * variables?"
description: "Two ways to keep data between runs: when * variables are all you need, and when the SQL command is worth it, with examples."
sidebar:
  order: 5
---

A script has two ways to keep data after it stops: [`*` variables](/language/variables/#persistent-variables-), saved
in the Windows registry, and the [`SQL`](/commands/sql/) command, which keeps data in an SQLite database
file.

**`SQL` does not replace `*` variables.** They work exactly as before, and for a few values they are still
the simplest choice. Choose by the shape of the data:

- **A few named values** (a counter, a setting, an ID): `*` variables.
- **Rows of data**: a log, a list, several fields per entry, totals, or data that several scripts change at
  the same time. Use `SQL`.

## At a glance

| | `*` variables | `SQL` |
|---|---|---|
| Where the data is | The registry, under `HKCU\Software\EasyUO`. | A file you name in [`sql open`](/commands/sql/open/). |
| Setting up | Nothing: `set *runs 1`. | `sql open` in each script, and a `CREATE TABLE` for your own tables. |
| Shape | One value per name. | Tables with as many rows and columns as you need. |
| Listing, searching, removing | Not from a script: you have to know the name, and no command deletes one. | `SELECT … WHERE`, `DELETE`, [`sql delete`](/commands/sql/delete/). |
| Totals, sorting, "in the last hour" | By hand, in a loop over numbered names. | `SUM`, `COUNT`, `GROUP BY`, `ORDER BY`, `LIMIT`. |
| Two scripts changing one value | A change can be lost (see [below](#several-scripts-adding-to-one-counter)). | One statement is never interrupted by another. |
| Who sees it | Every script of your Windows user, in EasyUO Reforged and the original EasyUO. | Every script that opens the same file. |
| Original EasyUO | Works there too. | `SQL` is new in EasyUO Reforged. |
| Back up, move to another PC | `reg export` of the key (it holds EasyUO's own settings too). | Copy the file. |
| Looking at the data | `regedit`. | Any SQLite tool, such as DB Browser for SQLite, or Python. |
| Needs | Nothing. | The SQLite that ships with Windows 10 and 11 (see [Using SQL](/guides/sql/#requirements)). |

## When `*` variables are enough

- You keep a handful of values: a run counter, the ID of your loot bag, a chosen option.
- The script must also run in the original EasyUO.
- Older scripts already read or write the same `*` variables.

## When SQL is worth it

- The data grows over time: every kill, every pickup, every skill gain.
- An entry has several fields (an ID, a name, a place, a time) and you want to find entries by any of them.
- You want totals, averages, the five best, or only what happened in the last hour.
- Several scripts, or several clients, write the same data at once.
- You want to look at the data, back it up or clear it without opening the registry.

## Examples

### Counting runs

A counter is the classic `*` variable, and it needs nothing else:

```euo
set *runs *runs + 1              ; N/A counts as 0, so the first run gives 1
display ok This script has run *runs times.
halt
```

The same with `SQL` takes two more lines: [`sql open`](/commands/sql/open/), then
[`sql load`](/commands/sql/load/) and [`sql save`](/commands/sql/save/) around the change.

```euo
sql open mydata.db
sql load %runs                   ; the value saved last time
set %runs %runs + 1
sql save %runs                   ; keep it for next time
display ok This script has run %runs times.
halt
```

For a single value like this, `*` variables are fine. `SQL` only adds the choice of file.

### One setting per character

Several characters on one computer each need their own loot bag. With `*` variables, glue the character's
ID to the name with [`.`](/language/operators/#building-variable-names-with-):

```euo
set %bag *lootbag . #CharID      ; *lootbag followed by this character's ID
if %bag = N/A
{
  set %bag ABCDEFG               ; your loot bag's ID
  set *lootbag . #CharID %bag
}
display ok #CharName keeps loot in %bag
halt
```

That works, but every character leaves a registry entry behind, and no script can list them. With `SQL`,
the characters are rows of one table, so a script can list them all:

```euo
sql open mydata.db
sql exec CREATE TABLE IF NOT EXISTS chars(id TEXT PRIMARY KEY, name TEXT, lootbag TEXT)
sql query SELECT lootbag FROM chars WHERE id = #CharID
if #SqlCnt = 0
{
  set %lootbag ABCDEFG           ; your loot bag's ID
  sql exec INSERT INTO chars VALUES(#CharID, #CharName, %lootbag)
}
sql query SELECT name, lootbag FROM chars ORDER BY name
for %i 1 #SqlCnt
{
  sql row %i                     ; sets %name and %lootbag
  display ok %name keeps loot in %lootbag
}
halt
```

To forget a character, `sql exec DELETE FROM chars WHERE id = #CharID` removes its row.

### A loot log you can add up

Here `SQL` does something `*` variables can't do. Each pickup becomes a row with the time
([`#SysTime`](/variables/systime/)), and one query adds up the last hour:

```euo
sql open mydata.db
sql exec CREATE TABLE IF NOT EXISTS loot(at INTEGER, item TEXT, amount INTEGER)
set %item gold                   ; in a real script: after each pickup
set %amount 250
sql exec INSERT INTO loot(at, item, amount) VALUES(#SysTime, %item, %amount)
set %since #SysTime - 3600000    ; one hour ago
sql query SELECT item, SUM(amount) AS total FROM loot WHERE at > %since
+ GROUP BY item ORDER BY total DESC LIMIT 5
for %i 1 #SqlCnt
{
  sql row %i                     ; sets %item and %total
  display ok %item : %total in the last hour
}
halt
```

The same table answers other questions with one line each. For example,
`SELECT COUNT(*) AS n FROM loot WHERE item = 'gold'` counts the pickups of gold, and
`SELECT item, MAX(amount) AS best FROM loot GROUP BY item` gives the best pickup of each item.

With `*` variables, you would need a numbered variable for each pickup (`*loot1`, `*loot2`, …), another one
for the next number, and a loop over all of them for every total. The old entries would stay in the
registry for good.

### Several scripts adding to one counter

Several scripts, one per client, count kills in one shared total. With a `*` variable:

```euo
set *kills *kills + 1            ; reads the value, adds one, writes it back
display ok Kills counted by every script: *kills
halt
```

Reading and writing are two separate steps. If two scripts read `41` at the same moment, both write `42`
and a kill is lost. It is rare, but it happens more often as the number of scripts grows.

With `SQL`, the database adds one in a single statement, so no other script can change the value in the
middle. A script that finds the file busy waits for its turn (up to 5 seconds):

```euo
sql open shared.db
sql exec CREATE TABLE IF NOT EXISTS counters(name TEXT PRIMARY KEY, n INTEGER)
sql exec INSERT OR IGNORE INTO counters VALUES('kills', 0)
sql exec UPDATE counters SET n = n + 1 WHERE name = 'kills'
sql query SELECT n AS kills FROM counters WHERE name = 'kills'
display ok Kills counted by every script: %kills
halt
```

Every script has to open the same file. A file name without a folder starts from
[`#CurPath`](/variables/curpath/), the folder of EasyUO Reforged, so `shared.db` is the same file for all
scripts.

## Moving `*` variables into a database

Copy each value into a `%` variable and save it:

```euo
sql open mydata.db
set %runs *runs                  ; one line for each value you want to keep
set %kills *kills
sql save %runs %kills
if #SqlRes = OK
  display ok Copied to mydata.db
halt
```

From then on, the script uses `sql load` and `sql save` instead of the `*` variables.

The `*` variables stay in the registry, because no script command deletes one. To remove them, open
`regedit`, go to `HKEY_CURRENT_USER\Software\EasyUO` and delete the values whose names start with `*`
(`set` writes the names in capitals, such as `*RUNS`). Leave the key and its other values alone: EasyUO
keeps its own settings there.
