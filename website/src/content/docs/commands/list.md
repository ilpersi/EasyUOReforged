---
title: "List"
description: "Named lists of values: add, insert, get, set, delete, count, search, sort, split a text into a list and join it back, merge, intersect and subtract lists. The answer goes to #ListRes."
kind: command
category: misc
syntax: "list {operation} {list} [parameters...]"
origin: reforged
sets: ['#ListRes']
related: ["#ListRes", "Str", "While", "For", "menu List", "menu Memo"]
aliases: ["array", "arrays", "lists", "collection", "queue", "stack", "sort", "split", "join", "merge", "union", "intersect", "intersection", "subtract", "difference", "unique", "remove duplicates"]
---

`list` keeps as many named lists of values as a script needs: the item types to loot, the lines of a
`#Property`, the players seen so far. Each line answers in [`#ListRes`](/variables/listres/). Positions start
at **1**, as in [`str`](/commands/str/) and [`#FindIndex`](/variables/findindex/).

| Line | Does | `#ListRes` |
|---|---|---|
| `list add {list} {value} [value...]` | Adds each value at the end. | The new count. |
| `list insert {list} {position} {value} [value...]` | Puts the values before `position`; `count + 1` adds them at the end. | The new count. |
| `list set {list} {position} {value}` | Replaces the value at `position`. | The count. |
| `list delete {list} {position}` | Removes the value at `position`. | The new count. |
| `list get {list} {position}` | — | The value; `N/A` outside 1 to the count. |
| `list count {list}` | — | How many values; `0` for a list never made. |
| `list indexof {list} {value} [from]` | — | The first position, from `from` on, whose value is `value`, ignoring case; `0` if none. |
| `list find {list} {text} [from]` | — | The first position, from `from` on, whose value contains `text`, ignoring case; `0` if none. |
| `list clear {list}` | Forgets the list. | `0`. |
| `list clone {list} {source}` | Makes `list` a copy of `source`. | The count. |
| `list sort {list} [text\|number] [down]` | Sorts the values (see [Sorting](#sorting)). | The count. |
| `list split {list} {text} {separator}` | Makes `list` the pieces of `text` between the separators. | The new count. |
| `list join {list} [separator]` | — | The values with `separator` between them; nothing between them without one. |
| `list merge {new} {list} [list...] [keepduplicates]` | Makes `new` the values of all the lists, each once. | The count of `new`. |
| `list intersect {new} {list} [list...]` | Makes `new` the values that are in every list, each once. | The count of `new`. |
| `list subtract {new} {list} {other}` | Makes `new` the values of `list` that are not in `other`, each once. | The count of `new`. |

A line with a missing name, position or value, a position outside the list, or another word after `list` sets
`#ListRes` to `N/A` and changes nothing.

## Examples

```euo
list add ores iron gold agapite
list get ores 2
set %second #ListRes             ; => %second = gold
list insert ores 1 copper
list indexof ores GOLD
set %where #ListRes              ; => %where = 3
list delete ores 2
list count ores
set %n #ListRes                  ; => %n = 3
list join ores ,
set %all #ListRes                ; => %all = copper,gold,agapite
halt
```

Remove the repeats from a list by merging it into itself. `list add` keeps every value it is given, repeats
included; `list merge` keeps each value once, ignoring case, in the spelling it met first:

```euo
list add types POF KUF pof EEF
list count types
set %added #ListRes              ; => %added = 4
list merge types types
set %n #ListRes                  ; => %n = 3
list join types _
set %left #ListRes               ; => %left = POF_KUF_EEF
halt
```

## Going through a list

Count the list first, then go from 1 to the count. A `while` loop does nothing when the list is empty:

```euo
list add loot POF KUF EEF
list count loot
set %n #ListRes
set %i 0
while %i < %n
{
  set %i %i + 1
  list get loot %i
  event sysmessage Looking for #ListRes
  finditem #ListRes C_ , #BackpackID
}
halt
```

A [`for`](/commands/for/) loop counts **down** when its end is smaller than its start, so for an empty list
`for %i 1 0` would run twice (for 1 and for 0). Put it in an `if`:

```euo
list add loot POF KUF
list count loot
set %n #ListRes
if %n > 0
{
  for %i 1 %n
  {
    list get loot %i
    event sysmessage #ListRes
  }
}
halt
```

To use the values one at a time, as a queue, take the first one and delete it. `list delete` answers with the
count left, so the loop ends when the list is empty:

```euo
list add todo POF KUF EEF
list count todo
while #ListRes > 0
{
  list get todo 1
  set %next #ListRes
  list delete todo 1
}
halt                             ; => %next = EEF
```

## Values

Every word after the list's name is one value: `list add ores iron gold` adds two values. A space ends a word,
so a value with spaces comes from a variable, or is glued together with `,` and [`#SPC`](/variables/spc/):

| Line | Values added |
|---|---|
| `list add names Sir Robin` | Two: `Sir` and `Robin`. |
| `list add names Sir , #SPC , Robin` | One: `Sir Robin`. |
| `list add names %who` | One: what `%who` holds, spaces and all. |
| `list add names #CharName #Property` | Two, each with its real spaces. |
| `list add names Sir_Robin` | One, with `_`, not a space. |

```euo
list add names Sir , #SPC , Robin Lady , #SPC , Ann
list count names
set %n #ListRes                  ; => %n = 2
list indexof names Lady , #SPC , Ann
set %where #ListRes              ; => %where = 2
halt
```

Values are kept exactly as given, never trimmed. `#Journal`, `#SysMsg` and the other texts that show a space as
`_` don't match the same text with real spaces (see [Spaces and `_`](/commands/str/#spaces-and-_)). The
[words that can't be passed](/commands/str/#words-that-cant-be-passed) to `str` can't be passed to `list`
either: a lone `,` glues the words beside it, so a value that is only a comma can only be the last word.

## Splitting and joining

`list split` cuts a text at every separator, as [`str part`](/commands/str/) does: the separator is matched
ignoring case, empty pieces are kept, and an empty text gives an empty list. `list join` puts the values back
into one text.

The separator is the **last** word of both, on purpose: a lone `,` or `.` glues the words beside it everywhere
else on a line, but not at its end. So comma-separated text works:

```euo
set %csv Sir , #SPC , Robin,Lady , #SPC , Ann,Tim
list split people %csv ,
set %n #ListRes                  ; => %n = 3
list get people 2
set %who #ListRes                ; => %who = Lady Ann
list join people #SPC , and , #SPC
set %text #ListRes               ; => %text = Sir Robin and Lady Ann and Tim
halt
```

[`#Property`](/variables/property/) ends each of its lines with `$`, so `list split props #Property $` gives one
value per line, plus an empty one after the last `$`, which `list delete props #ListRes` removes:

```euo
finditem POF C_ , #BackpackID
if #FindCnt > 0
{
  event property #FindID
  list split props #Property $
  list delete props #ListRes
  list get props 1
  event sysmessage The first line is #ListRes
}
halt
```

To keep the values apart when you join them, join with something they don't contain: `$`, `|`, or a `,` as the
last word. `list join names #SPC` gives `Sir Robin Lady Ann`, and nothing can tell where a name ends.

## Sorting

Without `text` or `number`, `list sort` sorts by number when every value is a whole number, and as text,
ignoring case, when any value is not. `text` and `number` force one or the other; `number` reads a text as `0`,
as arithmetic does. `down` puts the largest first. Values that sort the same keep their order.

```euo
list add hp 10 9 100
list sort hp
list join hp _
set %up #ListRes                 ; => %up = 9_10_100
list sort hp text
list join hp _
set %astext #ListRes             ; => %astext = 10_100_9
list sort hp down
list get hp 1
set %top #ListRes                ; => %top = 100
halt
```

## Combining lists

`list merge`, `list intersect` and `list subtract` build a **new** list from others. The lists they read never
change; the new list replaces any list of that name, and may be one of the lists read.

- A value is in the result once, compared ignoring case; the spelling met first is kept. Only
  `list merge … keepduplicates` keeps every value of every list, in order. `keepduplicates` is read only as the
  last word, so a list with that name can't be the last one merged.
- The values come in the order of the first list, then (for `merge`) the values the next lists add.
- A list never made counts as an empty one.

```euo
list add mine iron gold IRON copper
list add wanted Gold verite
list merge all mine wanted
list join all _
set %all #ListRes                ; => %all = iron_gold_copper_verite
list merge every mine wanted keepduplicates
set %n #ListRes                  ; => %n = 6
list intersect both mine wanted
list join both _
set %both #ListRes               ; => %both = gold
list subtract missing wanted mine
list join missing _
set %missing #ListRes            ; => %missing = verite
halt
```

## Lists in a menu

A list box numbers its entries from 1, as a list does, so `menu Get` gives the position of the chosen entry:

```euo
list add towns Britain Minoc Vesper
menu Clear
menu Window Size 200 160
menu List Create townbox 10 10 180 100
list count towns
set %n #ListRes
set %i 0
while %i < %n
{
  set %i %i + 1
  list get towns %i
  menu List Add townbox #ListRes
}
menu Button ok 10 120 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton <> ok
  wait 1
menu Get townbox
list get towns #MenuRes
display ok You chose #ListRes
halt
```

A [memo](/commands/menu/memo/) writes its line breaks as `$`, so `list join` fills one and `list split` reads it
back, one value per line:

```euo
list add notes Buy_reagents Repair_armor
list join notes $
menu Clear
menu Window Size 300 200
menu Memo notesbox 10 10 280 150 #ListRes
menu Button ok 10 165 60 25 OK
menu Show
set #MenuButton N/A
while #MenuButton <> ok
  wait 1
menu Get notesbox
list split notes #MenuRes $
display ok The memo has #ListRes lines
halt
```

## What a list is

- A list's name is one word and ignores case: `Loot` and `LOOT` are the same list. A name may be built with
  `.`, as `list add slot . %i sword` adds to the list `slot3` when `%i` is 3. A variable gives its value:
  `list add %which gem` adds to the list named by `%which`. So `%loot` is not the list `loot`, and while `%loot`
  is not set, it reads `N/A` and every such line goes to a list called `N/A`.
- A list with no values does not exist: a list never made counts `0`, and deleting its last value forgets it.
- Each script has its own lists, and a script it [`call`](/commands/call/)s shares them, as it shares the `%`
  variables. They are kept when the script starts over from the top (an [`exit`](/commands/exit/), or the end of
  the script) and forgotten when you start it again. [`namespace`](/commands/namespace/) doesn't change them.
- While a script runs, the editor's [Watches panel](/guide/debugging/#watches) shows each list and lets you edit
  its values, *Tools → VarDump* lists them, and [`EUOCli`](/guide/euocli/) reports them at the end of a run.

## Writing for EasyUO 1.5 too

`list` is new in EasyUO Reforged. In EasyUO 1.5 a line starting with `list` is ignored, and `#ListRes` reads
`N/A`. A script that must also run there builds variable names with `.` (see
[Operators](/language/operators/)):

```euo
set %ore1 iron
set %ore2 gold
set %ores 2
for %i 1 %ores
{
  set %name %ore . %i
  event sysmessage %name
}
halt
```

A sub or label called `list` keeps working: `gosub list` and `goto list` find it as before.
