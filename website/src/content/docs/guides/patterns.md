---
title: "Common patterns"
description: "How scripts do the everyday things: report, find and use items, target, move items, wait for the client and the journal, walk, work on text and loop."
sidebar:
  order: 2.5
---

Most scripts are built from the same few moves. Each one here is a whole script you can run and change. The
item types (`ZLF`, `POF`), IDs and journal texts in them are only examples: yours are different, and
[Finding IDs and types](/guides/finding-ids/) shows how to read them.

## How a script sees and acts

- **Objects have an ID and a type.** An ID (6 to 8 letters, `YKLMNOP`) is one object. A type (2 or 3
  letters, `POF`) is a kind of object. Both are text, never numbers.
- **[`finditem`](/commands/finditem/) is how a script sees objects.** It fills the `#Find…` variables. When
  nothing matched, `#FindCnt` is `0` and `#FindID` reads `X`: always test `#FindCnt`.
- **[`event macro`](/commands/event/macro/) runs the client's own macros:** speech, skills, spells, gumps, last
  object, last target. Look the numbers up on its page.
- **Commands that act on the client need one.** Without a client they do nothing, and the variables that
  describe it read `N/A`.

## Report what the script is doing

[`log`](/commands/log/) writes a line to the editor's Output panel and the script goes on. It needs no client
and the lines stay, so it is the way to follow a script while it runs. It is new in EasyUO Reforged.
[`event sysmessage`](/commands/event/sysmessage/) shows a line in the game window instead.
[`display`](/commands/display/) opens a message box and the script waits until you close it: use it for a
final result or a question, not inside a loop. To keep the lines in a file, with a level you can turn up or
down, use [`logfile`](/commands/logfile/), also new in EasyUO Reforged.

```euo
log Counting the gold...
finditem POF C_ , #BackpackID
log finditem found #FindCnt stacks
display ok Stacks of gold in the backpack: #FindCnt
halt
```

## Find an item and use it

Using an object is two lines: put its ID in [`#LObjectID`](/variables/lobjectid/) and run the client's *Last
Object* macro.

```euo
finditem ZLF C_ , #BackpackID       ; bandages, in the backpack
if #FindCnt = 0
{
  event sysmessage No bandages left
  halt
}
set #LObjectID #FindID
event macro 17 0                    ; use it
target 3s
if #TargCurs = 1
  event macro 23 0                  ; target yourself
halt
```

## Go through every match

Set [`#FindIndex`](/variables/findindex/) to look at the matches one after the other. Test `#FindCnt` first:
`for` counts down when its end is smaller than its start, so with no match it would run for 1 and for 0.

```euo
finditem POF G_3                    ; gold on the ground, within 3 tiles
if #FindCnt > 0
{
  for #FindIndex 1 #FindCnt
  {
    exevent drag #FindID #FindStack
    wait 10
    exevent dropc #BackpackID
    wait 10
  }
}
halt
```

## Target something

Wait for the target cursor with [`target`](/commands/target/), check that it came, say what to target and run
the *Last Target* macro. Set [`#LTargetKind`](/variables/ltargetkind/) every time.

```euo
set %bandages ABCDEFG               ; the ID of your bandages
set %pet HIJKLMN                    ; the ID of your pet
set #LObjectID %bandages
event macro 17 0                    ; use the bandages
target 3s
if #TargCurs = 1
{
  set #LTargetID %pet
  set #LTargetKind 1                ; 1: an object
  event macro 22 0                  ; target it
}
halt
```

## Move items

[`moveitem`](/commands/moveitem/) moves an item into a container in one line: it picks it up, drops it, waits,
tries again when that is safe, and says in [`#MoveRes`](/variables/moveres/) whether it arrived (`ok`). Without
an amount it moves the whole stack. `moveitem` is new in EasyUO Reforged. A container outside your backpack
must have been opened, or the result is `left` even when the move worked.

```euo
set %bag ABCDEFG                    ; the ID of a bag in your backpack
finditem POF C_ , #BackpackID
if #FindCnt > 0
{
  moveitem #FindID %bag
  if #MoveRes <> ok
    event sysmessage The gold did not arrive: #MoveRes
}
halt
```

In EasyUO 1.5, [`exevent drag`](/commands/exevent/drag/) picks an item up and
[`exevent dropc`](/commands/exevent/dropc/) drops it into a container, with no check. The amount is `1`
unless you give one, so pass `#FindStack` to move a whole stack. Don't mix `event drag` with the
`exevent drop…` commands.

```euo
set %bag ABCDEFG                    ; the ID of the bag to fill; it has to be open
finditem POF C_ , #BackpackID
if #FindCnt > 0
{
  exevent drag #FindID #FindStack
  wait 10
  exevent dropc %bag
  wait 10
}
halt
```

## Wait for the client instead of guessing

After an action, the client needs time. [`waitfor`](/commands/waitfor/) waits until a condition is true or a
timeout passes, and [`#WaitRes`](/variables/waitres/) says which happened. It is new in EasyUO Reforged: the
original EasyUO needs a loop with `wait`.

```euo
event macro 8 7                     ; open the backpack
waitfor #ContName = container_gump 3s
if #WaitRes = #false
  display ok The backpack did not open.
halt
```

## Wait for a journal line

Save [`#JIndex`](/variables/jindex/) before you act, then let [`findjournal`](/commands/findjournal/) look
through everything that came in after it. The journal writes spaces as `_`. `findjournal` is new in EasyUO
Reforged too.

```euo
set %j #JIndex                      ; where the journal is now
event macro 15 28                   ; cast Greater Heal
findjournal %j * 3s fizzles you_must_wait
if #JFound = 0
  event sysmessage No answer in 3 seconds
if fizzles in #Journal
  event sysmessage Fizzled
halt
```

## Answer a gump the server sent

A gump the server sends (a menu, a confirmation) is recognised by its type ID, which is the same every time
it opens: read it once with [`scangumps`](/commands/scangumps/) ([Finding IDs](/guides/finding-ids/) has a
probe). In EasyUO Reforged, [`exevent GumpReply`](/commands/exevent/gumpreply/) presses one of its buttons
without a click, with the checkboxes and text fields it needs, and closes the window. Wait for the gump with
`scangumps T_`, and read [`#GumpReplyRes`](/variables/gumpreplyres/) afterwards: `nogump` means it was not
open, and nothing was sent. The button numbers come from the shard, not from the client.

```euo
set %confirm JHEIIPI                ; the gump's #GumpTypeID on your shard
set %t #SCnt + 5
repeat
  scangumps T_ , %confirm
  wait 2
until #GumpCnt > 0 || #SCnt > %t
exevent GumpReply %confirm 1        ; button 1: OKAY
if #GumpReplyRes <> sent
  event sysmessage The confirmation did not open.
halt
```

## Bring a gump to the front

[`event ContTop`](/commands/event/conttop/) brings a gump to the front by its place from the top, counting
from `0` and skipping the gumps on the [`IgnoreCont`](/commands/ignorecont/) list.
[`scangumps`](/commands/scangumps/) lists every gump, counting from `1` and skipping none. So the `ContTop`
number of a gump found with `scangumps` is the number of entries in front of it that are not on the
`IgnoreCont` list. Scan without a `T_` or `A_` filter, or the count is wrong.

The script keeps its own copy of the list: the names it starts with, plus any `ignorecont` the script runs.
A window that opens between the scan and the `event ContTop` moves the count by one, so the script scans
again until the gump is in front. A gump on the `IgnoreCont` list (the map, the menu bar) can't be brought
forward this way.

```euo
set %want JHEIIPI   ; the gump's #GumpTypeID on your shard
; the IgnoreCont list a script starts with, each name between _
set %ign _BARK_GUMP_DAMAGENUMBERS_GUMP_DUMB_GUMP_GAMEAREAEDGEGUMP_MAP_GUMP_MENUBAR_
set %ign %ign , MISSILE_GUMP_NEW_ITEM_PROP_GUMP_RETICLE_GUMP_TARGET_GUMP_UNICODE_BARK_GUMP_
for %try 1 3
{
  gosub ContTopIndex %want
  if #result < 1
    break
  event conttop #result
  wait 2
}
if #result < 0
  event sysmessage That gump is not open.
halt

; ContTopIndex typeID: the event ContTop number of the frontmost server gump
; of that type (0 = already in front), or -1 when none is open.
sub ContTopIndex
  scangumps
  set %n 0
  set %at -1
  for #GumpIndex 1 #GumpCnt
  {
    set %k _ , #GumpName , _
    if %k in %ign
      continue
    if #GumpTypeID = %1
    {
      set %at %n
      break
    }
    set %n %n + 1
  }
return %at
```

To find the gump another way, change the `#GumpTypeID` line: `#GumpArt = YE` for the backpack, or
`#GumpObjID = %id` for a container or a paperdoll.

## Walk somewhere

[`path go`](/commands/path/go/) plans a route around walls and water and walks it. Always read
[`#PathState`](/variables/pathstate/) afterwards. In the original EasyUO, [`move`](/commands/move/) walks in a
straight line and [`event pathfind`](/commands/event/pathfind/) lets the client find a short way.

```euo
path go 1434 1699
if #PathState <> arrived
  display ok Did not get there: #PathState
halt
```

## Work on a text

[`str`](/commands/str/) puts its result in [`#StrRes`](/variables/strres/), and the next `str` replaces it:
copy the result first.

```euo
set %list iron_gold_agapite
str count %list _
set %fields #StrRes + 1             ; => %fields = 3
str part %list _ 2
set %second #StrRes                 ; => %second = gold
str len %second
set %length #StrRes                 ; => %length = 4
halt
```

## Keep a list

In EasyUO Reforged, [`list`](/commands/list/) holds as many values as a script needs, under one name, in
place of numbered variables (`%item1`, `%item2`, ...). Positions start at 1; each answer is in
[`#ListRes`](/variables/listres/), and a line that changes a list answers with its count. Count the list before
a loop, and use `while`, which does nothing for an empty list (`for %i 1 0` runs twice).

```euo
list split ores iron_gold_IRON_agapite _
list merge ores ores                   ; the repeats go: iron gold agapite
list sort ores
list count ores
set %n #ListRes
set %i 0
set %text
while %i < %n
{
  set %i %i + 1
  list get ores %i
  set %text %text , #ListRes , /
}
halt                                   ; => %text = agapite/gold/iron/
```

`list join ores /` gives the same text without the last `/`. `list indexof` and `list find` say where a value
is (0 when it isn't); `list merge`, `list intersect` and `list subtract` build a new list from others.

## Time things and show progress

In EasyUO Reforged, a [`timer`](/commands/timer/) does what deadlines built on `#SCnt` did: give up after a
while, do something every so often, measure how long the script has run. Its answer is in
[`#TimerRes`](/variables/timerres/), in milliseconds. [`str duration`](/commands/str/#time-and-numbers-reforged)
writes seconds as `h:mm:ss` and `str decimal` writes skill tenths as `95.3`, for a status line. A skill gain per
hour is `gain * 3600 / seconds`, in tenths, then `str decimal`.

```euo
timer start run
set %start #Skill
mainloop:
  timer due status
  if #TimerRes
  {
    gosub showStatus
    timer start status 10s
  }
  wait 1s
goto mainloop

sub showStatus
  timer elapsed run
  set %secs #TimerRes / 1000 + 1
  set %gain #Skill - %start
  set %rate %gain * 3600 / %secs
  str duration %secs
  set %ran #StrRes
  str decimal %gain 1
  set %gained #StrRes
  str decimal %rate 1
  log Running %ran gained %gained ( , #StrRes , /h)
return
```

[`str date` and `str clock`](/commands/str/#date-and-time-formats-reforged) write [`#Date`](/variables/date/) and
[`#Time`](/variables/time/) for people, in a format of your choice: `str clock #Time h:nn am/pm` gives `2:30 pm`.

## Ask with a window

[`menu`](/commands/menu/) builds a window of your own. A click on a button puts its name in
[`#MenuButton`](/variables/menubutton/), so set that to something else before you wait for it. There are two
`menu` systems, EasyUO 1.5's and 1.6's, and a script runs under one of them: read
[MENU: EasyUO 1.5 and 1.6](/commands/menu/versions/) before you write or change `menu` lines, and don't mix
their sub-commands.

```euo
menu Clear
menu Window Size 160 45
menu Button ok 10 10 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton = N/A
  wait 1
if #MenuButton = closed
  display ok You closed the window.
else
  display ok You clicked #MenuButton
halt
```

## Run until you stop it

A script that keeps working is a label, the work, a wait and a `goto` back. Keep the work in subs, after the
loop.

```euo
set %rounds 0
mainloop:
  gosub oneRound
  wait 1s
goto mainloop

sub oneRound
  set %rounds %rounds + 1
  event sysmessage Round %rounds
return
```

## Keep data between runs

A `*` variable keeps its value when the script and EasyUO Reforged are closed. For more than a few values,
a settings file ([below](#save-and-load-settings)) or [`sql`](/commands/sql/) keeps them in a file of your own.
[Keeping data between runs](/guides/persistence/) compares the ways.

```euo
if *runs = N/A
  set *runs 0
set *runs *runs + 1
display ok This script has run *runs times.
halt
```

## Save and load settings

A file of `set` lines is a settings file: [`call`](/commands/call/) runs it and the variables are back.
[`logfile write`](/commands/logfile/write/) writes it, one line at a time, exactly as given. Glue `%` to a
name (`% , bandages`) to write the variable's name; the next word gives its value. One file per character
keeps each character's settings apart.

```euo
set %file medic , #CharID , .txt
gosub LoadSettings
if %bandages = N/A
  set %bandages 50                    ; first run: the defaults
set %bandages %bandages - 1
gosub SaveSettings
halt

sub LoadSettings
  call %file                          ; does nothing when the file isn't there yet
return

sub SaveSettings
  logfile open cfg %file new
  logfile write cfg #smc , Settings of #CharName
  logfile write cfg set % , bandages %bandages
  logfile close cfg
  if #LogRes <> OK
    event sysmessage Settings not saved: #LogRes
return
```

Don't write files with `execute cmd /c echo ... >> file`, as older scripts do: each line waits two seconds,
flashes a console window, and breaks on `>`, `|`, `&` or `%` in the text. `logfile` writes at once and says in
[`#LogRes`](/variables/logres/) when it can't.

A value in a settings file must be one word: `call` reads `set %name Dr Who` as `Dr`.
[Keeping data between runs](/guides/persistence/) says when a settings file is the right choice.

## Talk to a web server

[`send get`](/commands/send/) reads a page, and `send post` sends data to one, over `http` or `https`. The answer
is kept, never run: [`#SendRes`](/variables/sendres/) is `OK` when the server answered,
[`#SendCode`](/variables/sendcode/) is its status (`200` when all went well), and
[`#SendReply`](/variables/sendreply/) holds what it sent. Pass a value that may hold spaces or `&` through
[`str urlencode`](/commands/str/#encode-for-send-reforged) before you glue it into form data. For JSON, use
`str jsonescape` and set [`#SendHeader`](/variables/sendheader/) to `Content-Type: application/json$` first.
These forms and the two `str` operations are new in Reforged. Don't use `send httppost` for this in Reforged: it
runs the server's reply as a script. It is still the only form EasyUO 1.5 has: for a script that must also run
there, see [a script for both](/commands/send/#a-script-for-both).

```euo
str urlencode #CharName
set %data name= , #StrRes , &gold= , #Gold
send post https://example.com/euo/report.php %data
if #SendRes <> OK || #SendCode <> 200
  event sysmessage Not sent: #SendRes #SendCode
halt
```
