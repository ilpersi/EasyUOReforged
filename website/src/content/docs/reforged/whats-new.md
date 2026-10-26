---
title: What's new in Reforged
description: Everything EasyUO Reforged adds to EasyUO 1.5 or does differently, with links to the details.
sidebar:
  order: 1
---

EasyUO Reforged is a port of EasyUO 1.5 from Delphi 7 to Lazarus / Free Pascal, as a native 64-bit Windows
application. The language is the same and **existing `.euo` scripts are meant to run unchanged**: every
command, every `#variable` and the quirks scripts rely on (tick timing, `GOTO` / `GOSUB` resolution,
`EXIT` restarting the script, …) are kept on purpose.

What it adds is listed below. Reference pages mark these with **New in Reforged** or **Changed in
Reforged**, and the [command](/commands/) and [variable](/variables/) lists can filter on both.

## New commands and variables

- **[`Path`](/commands/path/)**: plan a walking route anywhere on the facet, around walls and water, over
  bridges and up stairs, from the client's own map files, and walk it.
  - [`path go`](/commands/path/go/) and [`path walk`](/commands/path/walk/) walk a route and wait;
    [`path step`](/commands/path/step/) and [`path stop`](/commands/path/stop/) let a script heal or fight
    meanwhile.
  - The walker walks step by step, or drives the client's own pathfinder a stretch at a time. It sees the
    items, doors, creatures and (on `client_beta.exe` 7.0.117.31) house walls your client holds, opens doors,
    and goes round what it finds in the way.
  - It asks the client itself about the next 12 tiles of the route, so it goes round a house it can't read
    before stepping into it. [`path check`](/commands/path/check/) asks the same from a script.
  - With [`path block`](/commands/path/block/), [`path avoid`](/commands/path/avoid/) and
    [`path link`](/commands/path/link/) a script adds what the map doesn't know.
  - Results come back in [`#PathState`](/variables/pathstate/), [`#PathCnt`](/variables/pathcnt/),
    [`#PathX`](/variables/pathx/), [`#PathY`](/variables/pathy/), [`#PathZ`](/variables/pathz/) and
    [`#PathDir`](/variables/pathdir/).
- **[`SQL`](/commands/sql/)**: keep data in an SQLite database file, with raw SQL or a quick
  [`save`](/commands/sql/save/) / [`load`](/commands/sql/load/) of variables. Results come back in
  [`#SqlRes`](/variables/sqlres/), [`#SqlCnt`](/variables/sqlcnt/),
  [`#SqlChanges`](/variables/sqlchanges/) and [`#SqlLastID`](/variables/sqllastid/).
  See [Using SQL](/guides/sql/).
- **[`ScanBuffs`](/commands/scanbuffs/)**: read the buff bar, with names, descriptions and timers, through
  [`#BuffCnt`](/variables/buffcnt/), [`#BuffIndex`](/variables/buffindex/), [`#BuffID`](/variables/buffid/),
  [`#BuffCliloc`](/variables/buffcliloc/), [`#BuffName`](/variables/buffname/),
  [`#BuffDesc`](/variables/buffdesc/), [`#BuffTime`](/variables/bufftime/) and
  [`#BuffBarOpen`](/variables/buffbaropen/).
- **[`menu Memo`](/commands/menu/memo/)**: a multi-line, scrollable text field for menu windows.
- **[`#ReforgedVer`](/variables/reforgedver/)**: the build version of EasyUO Reforged.
  [`#EUOVer`](/variables/euover/) still returns `1_50_00`, so existing version checks keep working.

## Changed behaviour

- **[`Tile`](/commands/tile/)** reads the `.uop` map files of newer client installs directly; there is no
  need to extract them to the old `.mul` format first.
- **[`Tile`](/commands/tile/)** reads current maps correctly: Trammel from its own files instead of
  Felucca's, Felucca and Trammel up to x 7167 instead of 6143, and Ter Mur from the right place in its
  files. Scripts can see different tiles there than in EasyUO 1.5. Plain `tile init` also works on installs
  that lack some of the map patch files, instead of stopping the script.

## uo.dll

- [`uo.dll`](/dll/) is a 64-bit build, for 64-bit programs. Its API is unchanged, plus
  [`ScanBuffs`](/dll/scanbuffs/), [`GetBuff`](/dll/getbuff/) and [`BuffBarOpen`](/dll/buffbaropen/) for the
  buff bar.
- [`BlockInfo`](/dll/blockinfo/) no longer crashes `client.exe` 7.0.117.1: EasyUO 1.5 passed the client's
  function one argument too few. Its page now says what the two bytes per tile mean.

## The editor

- Line numbers and **Ctrl+Space** autocomplete (it knows the sub-commands of `menu`, `sql`, `event` and the
  others).
- A Find and Replace window with regular expressions, wrap-around, a match count, every match highlighted,
  search in a selection or in all open scripts, search history, and **F3** / **Shift+F3**.
- Code folding for subs, `{ }` blocks and `repeat`, with Fold All / Unfold All.
- Format Script (**Ctrl+Shift+F**) re-indents a script in one step.
- Breakpoints, conditional breakpoints, step into / over / out, run to cursor and a live call stack.

See [Editing and debugging](/guide/debugging/).

## Not in Reforged

- [`event Sleep`](/commands/event/sleep/) is accepted but does nothing.
- [`PlayCD`](/commands/playcd/), [`StopCD`](/commands/stopcd/) and
  [`InitEvents`](/commands/initevents/) do nothing, as in EasyUO 1.5.

See also the [known limitations](/reforged/known-limitations/).
