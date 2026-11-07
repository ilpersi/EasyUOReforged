---
title: "FindJournal"
description: "Searches the journal lines since a bookmark for a colour and any of several texts, waiting up to a timeout."
kind: command
category: client
syntax: "findjournal {since} {color} {timeout} {text} [text...]"
needsClient: true
origin: reforged
sets: ['#JFound', '#Journal', '#JColor']
related: ["ScanJournal", "DeleteJournal", "WaitFor", "#JFound", "#JIndex", "#Journal", "#JColor"]
aliases: ["search journal", "wait for journal", "journal text", "find message"]
---

`findjournal` asks "has any of these texts appeared in the journal since this point?". Save
[`#JIndex`](/variables/jindex/) before you act, then search everything that came in after it. It sees every new line,
even when several arrive together.

```euo
set %j #JIndex
event macro 15 28                      ; cast Greater Heal
findjournal %j * 3s fizzles you_must_wait
if #JFound > 0
  event sysmessage #Journal
halt
```

[`#JFound`](/variables/jfound/) is the running number of the line it found, or `0` if it found none. The line itself
goes to [`#Journal`](/variables/journal/) and its colour to [`#JColor`](/variables/jcolor/), as after
[`scanjournal`](/commands/scanjournal/). With no match they read `N/A` and `0`.

:::caution[All four parameters are needed]
They go by position, so one left out shifts the rest with no error. `findjournal %j * fizzles` reads `fizzles` as the
time and has no text left, so it finds nothing. Start from `findjournal %j * 0 text`, which means any colour and no
waiting. Swapping the numbers in `findjournal %j 5 33 fizzles` asks for colour 5 and a timeout of 33 ticks.
:::

## Parameters

| Parameter | Meaning |
|---|---|
| `since` | Which lines to search. A [`#JIndex`](/variables/jindex/) value (above 500): the lines after it. A number from 1 to 500 counts back from the newest line, as in `scanjournal`: `10` is the newest 10 lines. `0`, a negative number or an unset variable searches nothing. |
| `color` | The colour the line must have, as [`#JColor`](/variables/jcolor/) shows it, or `*` for any colour. A value that can't be read as a number, such as an unset variable, finds nothing. |
| `timeout` | The longest to wait for a match, as in [`waitfor`](/commands/waitfor/): a number of **ticks** of 50 ms (`20` is one second), or a whole number of **seconds** followed by `s` (`5s`). `0` checks once and doesn't wait. A value that can't be read as a time counts as 2 seconds. |
| `text` | What the line must contain, or `*` for any line. Give as many as you like. |

Whatever the `since`, it never looks at more than the newest 100 lines, the same limit as `scanjournal`.

## What matches

A line matches when it has the colour **and** contains **any one** of the texts. There is one colour for the whole call.

| Call | Finds |
|---|---|
| `findjournal %j * 0 fizzles` | that text, in any colour |
| `findjournal %j 33 0 *` | any line of colour 33 |
| `findjournal %j 33 0 fizzles` | that text in that colour |
| `findjournal %j * 0 *` | the next new line, whatever it says |

Text is matched exactly like the [`in`](/language/expressions/) operator: anywhere in the line, ignoring case, with
spaces written as `_`.

Colours can differ between hues and clients. To find the value you need, read `#JColor` after finding a line of that kind.

A text of exactly `*` is the wildcard, and nothing else is. `*sighs*` looks for those characters, and so does
`you_*_wait`, so `*` doesn't work as a pattern inside a text.

## Several texts

The search goes through the lines from oldest to newest and stops at the first one that matches. The order of the texts
doesn't matter: if `You must wait` arrived before `The spell fizzles`, this finds `You must wait`, although `fizzles`
is listed first. Nothing reports which text matched, so test it afterwards:

```euo
set %j #JIndex
event macro 15 28
findjournal %j * 3s fizzles you_must_wait
if fizzles in #Journal
  event sysmessage Fizzled
if you_must_wait in #Journal
  event sysmessage Too soon
if #JFound = 0
  event sysmessage Nothing yet
halt
```

Several texts mean "any of them". To require two texts on one line, search for one and test the other with `in`.

## Going through every match

Because the oldest match comes first, setting the bookmark to `#JFound` moves on to the next one. Each match is handled
once and in order. With `*` for the colour and the text, this goes through every new line:

```euo
set %j #JIndex
msg first line$
msg second line$
wait 1s
repeat
  findjournal %j * 0 *
  if #JFound > 0
  {
    event sysmessage #Journal
    set %j #JFound
  }
until #JFound = 0
halt
```

Use one variable per thing you watch, and they stay independent. There is no bookmark to reset.

## Waiting

With a timeout, the search repeats every tick (50 ms) until a line matches or the time runs out. If a line already
matches, the script goes on without any delay.

- **Pause** holds the wait, and the time paused doesn't count towards the timeout.
- **Stop** ends the wait at once and leaves `#JFound`, `#Journal` and `#JColor` as they were.
- The editor stays responsive during a wait, and the variable inspector keeps updating.

Use `findjournal` rather than [`waitfor`](/commands/waitfor/) to wait for a journal text. A `waitfor` condition can't
search: `#SysMsg` holds only the latest message, and `#JIndex > %j` comes true on any line at all, so nearby chat ends the
wait.

## DeleteJournal

`findjournal` doesn't need [`deletejournal`](/commands/deletejournal/), but it does respect it. Lines it hid are not
searched, and a line found counts as the line last read, so `deletejournal` right after a search hides that line and
everything older. To swap out a hand-written search sub that relies on `deletejournal`, count back from the newest line:

```euo
msg guards$
wait 1s
findjournal 100 * 0 guards
if #JFound > 0
{
  event sysmessage Heard it.
  deletejournal
}
halt
```

## Notes

- `if #JFound` alone is never true, because only `-1` counts as true. Write `if #JFound > 0`.
- Text that other players say matches too. Their lines contain `:_` after the name, so `if :_ in #Journal` tells them
  apart. Colour can also separate them if speech and system messages differ on your client.
- A lone `*` character can't be searched for, since `*` alone is the wildcard.
- If more lines arrive than the client keeps, between two reads of the journal, the running numbers start again from
  1000. A bookmark above `#JIndex` then searches all the lines held, because all of them are newer than it. Every search
  and every read of `#JIndex` keeps the count up to date, and the editor reads it regularly too. Logging out and back
  in without closing the client doesn't restart them: the client keeps its journal, so a bookmark saved before still
  works after. Closing the client does restart them, because the new client has a new journal. A low bookmark can then
  miss the first lines of the new session, so save `#JIndex` again once the client is back.
- The first line after a completely empty journal, right after logging in, doesn't move `#JIndex` on. A bookmark saved
  at that moment doesn't see that one line.

## Reforged notes

`findjournal` and `#JFound` are new in EasyUO Reforged. No existing command changes because of them, and a sub or label
called `findjournal` keeps working. It's the only change for old scripts: a line starting with the word `findjournal`
used to be ignored and is now this command.

`uo.dll` has no equivalent. A program using it reads the lines itself with `GetJournal`.
