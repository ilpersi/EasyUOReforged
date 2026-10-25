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

## uo.dll

- [`uo.dll`](/dll/) is a 64-bit build, for 64-bit programs. Its API is unchanged, plus
  [`ScanBuffs`](/dll/scanbuffs/), [`GetBuff`](/dll/getbuff/) and [`BuffBarOpen`](/dll/buffbaropen/) for the
  buff bar.

## The editor

- Line numbers, **Ctrl+Space** autocomplete (it knows the sub-commands of `menu`, `sql`, `event` and the
  others), find and replace.
- Code folding for subs, `{ }` blocks and `repeat`, with Fold All / Unfold All.
- Format Script (**Ctrl+Shift+F**) re-indents a script in one step.
- Breakpoints, conditional breakpoints, step into / over / out, run to cursor and a live call stack.

See [Editing and debugging](/guide/debugging/).

## Not in Reforged

- [`event Sleep`](/commands/event/sleep/) is accepted but does nothing.
- [`PlayCD`](/commands/playcd/), [`StopCD`](/commands/stopcd/) and
  [`InitEvents`](/commands/initevents/) do nothing, as in EasyUO 1.5.

See also the [known limitations](/reforged/known-limitations/).
