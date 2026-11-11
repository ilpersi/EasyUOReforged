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
final result or a question, not inside a loop.

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

[`exevent drag`](/commands/exevent/drag/) picks an item up and [`exevent dropc`](/commands/exevent/dropc/)
drops it into a container. The amount is `1` unless you give one, so pass `#FindStack` to move a whole stack.
Don't mix `event drag` with the `exevent drop…` commands.

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
[`sql`](/commands/sql/) keeps them in a database file. [SQL or * variables?](/guides/sql-or-persistent-variables/)
compares the two.

```euo
if *runs = N/A
  set *runs 0
set *runs *runs + 1
display ok This script has run *runs times.
halt
```
