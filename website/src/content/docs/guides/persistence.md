---
title: "Keeping data between runs"
description: "Every way a script keeps data after it stops: * variables, settings files written with logfile, the SQL command and logs, when to use each, with examples."
sidebar:
  order: 5
---

A script loses its `%` variables when it stops. To keep data until the next run, it has three ways, plus a
fourth for a history that people read:

- [`*` variables](/language/variables/#persistent-variables-), saved in the Windows registry.
- **A settings file**: [`logfile write`](/commands/logfile/write/) writes a file of `set` lines, and
  [`call`](/commands/call/) runs it to set the variables again.
- The [`SQL`](/commands/sql/) command, which keeps data in an SQLite database file.
- **A log**: [`logfile`](/commands/logfile/) messages with the time in front, which you read later. A script
  can't read a log back.

None of them replaces another. `*` variables work exactly as before, and for a few values they are still the
simplest choice. Choose by the shape of the data:

- **A few named values** (a counter, a setting, an ID): `*` variables.
- **A few dozen settings** that you want to see and change in Notepad, one file per character: a settings
  file.
- **Rows of data**: a list, several fields per entry, totals, or data that several scripts change at the same
  time. Use `SQL`.
- **What happened, for you to read later**: a log.

## At a glance

| | `*` variables | Settings file | `SQL` |
|---|---|---|---|
| Where the data is | The registry, under `HKCU\Software\EasyUO`. | A text file you name in [`logfile open`](/commands/logfile/open/). | A file you name in [`sql open`](/commands/sql/open/). |
| Setting up | Nothing: `set *runs 1`. | `call` the file to load it. To save, `logfile open … new`, one `logfile write` per value and `logfile close`. | `sql open` in each script, and a `CREATE TABLE` for your own tables. |
| Shape | One value per name. | One `set` line per value. A value must be one word: `Dr Who` comes back as `Dr`. | Tables with as many rows and columns as you need. |
| Listing, searching, removing | Not from a script: you have to know the name, and no command deletes one. | Not from a script: `call` loads the whole file. To drop a value, stop writing it. | `SELECT … WHERE`, `DELETE`, [`sql delete`](/commands/sql/delete/). |
| Totals, sorting, "in the last hour" | By hand, in a loop over numbered names. | By hand, as with `*` variables. | `SUM`, `COUNT`, `GROUP BY`, `ORDER BY`, `LIMIT`. |
| Two scripts changing one value | A change can be lost (see [below](#several-scripts-adding-to-one-counter)). | Each save writes the whole file, so the last script to save wins. | One statement is never interrupted by another. |
| Who sees it | Every script of your Windows user, in EasyUO Reforged and the original EasyUO. | Every script that calls the same file. | Every script that opens the same file. |
| Original EasyUO | Works there too. | `logfile` is new in EasyUO Reforged. The original EasyUO can still `call` the file. | `SQL` is new in EasyUO Reforged. |
| Back up, move to another PC | `reg export` of the key (it holds EasyUO's own settings too). | Copy the file. | Copy the file. |
| Looking at the data | `regedit`. | Any text editor. You can change a value by hand before the next run. | Any SQLite tool, such as DB Browser for SQLite, or Python. |
| Needs | Nothing. | Nothing. | The SQLite that ships with Windows 10 and 11 (see [Using SQL](/guides/sql/#requirements)). |

A file name without a folder starts from [`#CurPath`](/variables/curpath/), the folder of EasyUO Reforged,
for `logfile open`, `call` and `sql open` alike. So `settings.txt` is the same file for every script.

## When `*` variables are enough

- You keep a handful of values: a run counter, the ID of your loot bag, a chosen option.
- The script must also run in the original EasyUO.
- Older scripts already read or write the same `*` variables.

## When a settings file is the right choice

- Each character has its own settings, and you want one small file per character that you can open, read
  and change in Notepad.
- The script saves all its settings at once, for example when you close its menu.
- You want to copy one character's settings to another computer, or to another character, by copying a file.

Keep in mind:

- **A value must be one word.** `call` runs `set %name Dr Who`, which sets `%name` to `Dr`. A value that
  starts with `;` comes back empty, because the line becomes a comment. IDs, numbers and words are fine.
- **`call` runs every line of the file as a script.** Load only files that your own scripts wrote.
- **Each save writes the whole file again** (`logfile open … new`). Two scripts saving the same file at once
  don't mix their lines, but the last one to save wins.
- Under [`EUOCli run`](/guide/euocli/), `logfile open` only accepts files inside the program folder,
  unless the run has `--allow logfile`.

Older scripts write these files with `execute cmd /c echo … >> file`. That still works, but
[Save and load settings](/guides/patterns/#save-and-load-settings) explains why `logfile write` is better.

## When SQL is worth it

- The data grows over time: every kill, every pickup, every skill gain.
- An entry has several fields (an ID, a name, a place, a time) and you want to find entries by any of them.
- You want totals, averages, the five best, or only what happened in the last hour.
- Several scripts, or several clients, write the same data at once.
- You want to look at the data, back it up or clear it without opening the registry.

## Keeping a history

A log is a file of messages with the date, the time, the level and the script line in front. You read it later,
in Notepad or any other tool. [`logfile set … daily`](/commands/logfile/set/) starts a new file every day, so a
script that runs for days leaves one file per day:

```euo
logfile open loot loot.log
logfile set loot daily 30        ; a new file each day; the last 30 days are kept
set %item gold                   ; in a real script: after each pickup
set %amount 250
logfile info picked up %amount %item
halt
```

Each message is one line, like `2026-11-18 14:03:22.123 [Info] loot.euo:5 picked up 250 gold`. A script can't
read a log back. If a script has to add up its history, keep it in `SQL` (see
[A loot log you can add up](#a-loot-log-you-can-add-up)).

## Examples

### Counting runs

A counter is the classic `*` variable, and it needs nothing else:

```euo
set *runs *runs + 1              ; N/A counts as 0, so the first run gives 1
display ok This script has run *runs times.
halt
```

With a settings file, `call` loads the count and `logfile write` saves it again:

```euo
set %runs 0
call runs.txt                    ; sets %runs; does nothing on the first run
set %runs %runs + 1
logfile open runs runs.txt new   ; new: write the file again from the start
logfile write runs set % , runs %runs
logfile close runs
display ok This script has run %runs times.
halt
```

`% , runs` glues `%` to `runs`, so the file gets the name `%runs`, not its value. The file then holds one
line: `set %runs 1`.

The same with `SQL`: [`sql open`](/commands/sql/open/), then [`sql load`](/commands/sql/load/) and
[`sql save`](/commands/sql/save/) around the change.

```euo
sql open mydata.db
sql load %runs                   ; the value saved last time
set %runs %runs + 1
sql save %runs                   ; keep it for next time
display ok This script has run %runs times.
halt
```

For a single value like this, `*` variables are fine.

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

That works, but every character leaves a registry entry behind, and no script can list them.

With a settings file, glue the character's ID to the file name instead. Each character gets its own small
file that you can open in Notepad:

```euo
set %file lootbag , #CharID , .txt
set %bag N/A
call %file                       ; sets %bag if this character saved one
if %bag = N/A
{
  set %bag ABCDEFG               ; your loot bag's ID
  logfile open bag %file new
  logfile write bag #smc , Loot bag of #CharName
  logfile write bag set % , bag %bag
  logfile close bag
  if #LogRes <> OK
    display ok Not saved: #LogRes
}
display ok #CharName keeps loot in %bag
halt
```

The first line of the file is a comment ([`#smc`](/variables/smc/) is `;`), so you can tell the files apart.
A script still can't list the files, though. With `SQL`, the characters are rows of one table, so a script
can list them all:

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

Here `SQL` does something no other way can. Each pickup becomes a row with the time
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
registry for good. A [log](#keeping-a-history) keeps every pickup too, but only for you to read: no script can
add it up.

### Several scripts adding to one counter

Several scripts, one per client, count kills in one shared total. With a `*` variable:

```euo
set *kills *kills + 1            ; reads the value, adds one, writes it back
display ok Kills counted by every script: *kills
halt
```

Reading and writing are two separate steps. If two scripts read `41` at the same moment, both write `42`
and a kill is lost. It is rare, but it happens more often as the number of scripts grows. A settings file is
no better: each script loads the file, adds one and writes the whole file again, so a kill counted by another
script in between is lost the same way.

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

Every script has to open the same file. A name without a folder starts from `#CurPath`, so `shared.db` is
the same file for all scripts.

## Moving `*` variables

### Into a database

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

### Into a settings file

Write one `set` line for each value:

```euo
logfile open cfg settings.txt new
logfile write cfg set % , runs *runs ; one line for each value you want to keep
logfile write cfg set % , kills *kills
logfile close cfg
if #LogRes = OK
  display ok Copied to settings.txt
halt
```

From then on, the script loads the values with `call settings.txt` and saves them with `logfile write`.

### Removing the old values

The `*` variables stay in the registry, because no script command deletes one. To remove them, open
`regedit`, go to `HKEY_CURRENT_USER\Software\EasyUO` and delete the values whose names start with `*`
(`set` writes the names in capitals, such as `*RUNS`). Leave the key and its other values alone: EasyUO
keeps its own settings there.
