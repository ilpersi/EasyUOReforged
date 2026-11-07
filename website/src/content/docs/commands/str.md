---
title: "Str"
description: "Works on a piece of text (length, position, part, case, replace, split, trim, join, insert, delete, count); the result goes to #StrRes."
kind: command
category: misc
changed: true
syntax: "str {operation} {text} [parameters...]"
sets: ["#StrRes"]
related: ["#StrRes", "#SPC", "#DOT", "#SMC"]
aliases: ["string", "text", "substring", "length", "replace", "split", "trim", "join", "concat", "concatenate"]
source: wiki
---

`str` works on a piece of text and puts the result in [`#StrRes`](/variables/strres/).

| Operation | Result in `#StrRes` |
|---|---|
| `str len {text}` | The number of characters. |
| `str pos {text} {part} [n]` | Where `part` starts in `text`, counting from 1; with `n`, where its `n`-th occurrence starts. `0` when it is not there. |
| `str count {text} {part}` | How many times `part` occurs in `text`. |
| `str left {text} {n}` | The first `n` characters. |
| `str right {text} {n}` | The last `n` characters. |
| `str mid {text} {start} {n}` | `n` characters starting at character `start`. |
| `str lower {text}` | The text in lower case. |
| `str upper {text}` | The text in upper case. |
| `str ins {text} {part} {start}` | The text with `part` inserted at character `start`. |
| `str del {text} {start} {n}` | The text with `n` characters removed, starting at character `start`. |
| `str replace {text} {search} [with]` | The text with every `search` replaced by `with`, or removed when `with` is left out. |
| `str part {text} {separator} {n}` | The `n`-th field between separators, counting from 1. `N/A` when there is no such field. |
| `str trim {text} [chars]` | The text without those characters at either end. Without `chars`: spaces and `_`. |
| `str join {separator} {text} [text...]` | The texts in order, with the separator between them. |
| `str concat {text} [text...]` | The texts in order, with nothing between them. |

`pos`, `count`, `replace`, `part` and `trim` ignore case when they look for something, and the result keeps the
case of the text. When parameters are missing, `#StrRes` is `N/A`.

## Examples

```euo
set %s HELLO
str len %s          ; 5
str pos %s LL       ; 3
str left %s 4       ; HELL
str right %s 2      ; LO
str mid %s 2 3      ; ELL
str lower %s        ; hello
str upper hello     ; HELLO
str ins %s I 3      ; HEILLO
str del %s 3 2      ; HEO
str count %s L      ; 2
display ok #StrRes
halt
```

### Replace

```euo
str replace red_red_blue RED green   ; green_green_blue
display ok #StrRes
str replace a-b-c -                  ; abc: nothing to replace it with, so it is removed
display ok #StrRes
halt
```

A replacement may contain what it replaces: `str replace a_b _ __` gives `a__b`. When `search` isn't in the text,
or is empty, the result is the text unchanged.

### Split

`str part` takes one field out of a text. Use it with `for` and `str count` to go through all of them: a text has one
field more than it has separators.

```euo
set %list iron_gold_agapite
str count %list _
set %n #StrRes + 1
for %i 1 %n
{
  str part %list _ %i
  display ok #StrRes
}
halt
```

A separator at the start, at the end or doubled makes an empty field, so `_a__b` has the fields *empty*, `a`, *empty*
and `b`. An empty field is empty text, and asking for a field past the last one gives `N/A`. To read a field into a
numbered variable, write `set %ore . %i #StrRes` in the loop.

A separator can be several characters. To take what stands between two markers, use `str part` twice:

```euo
set %list iron^10|gold^20|agapite^30|
str part %list gold^ 2       ; 20|agapite^30|
str part #StrRes | 1         ; 20
display ok #StrRes
halt
```

### Trim

```euo
str trim __hello_world__     ; hello_world
display ok #StrRes
str trim /ore/gold/ /        ; ore/gold
display ok #StrRes
halt
```

Without `chars`, `trim` removes spaces and `_`. Every character of `chars` counts on its own: `str trim %s $/` removes
both `$` and `/`.

To remove characters everywhere in a text and not only at its ends, go through them with `str replace`:

```euo
set %name My?Shard!
set %bad ?!/
str len %bad
set %n #StrRes
for %i 1 %n
{
  str mid %bad %i 1
  str replace %name #StrRes
  set %name #StrRes
}
display ok %name              ; MyShard
halt
```

### Join and concat

```euo
str join _ iron gold agapite  ; iron_gold_agapite
display ok #StrRes
str join #SPC Sir Robin       ; Sir Robin
display ok #StrRes
str concat Sir #SPC Robin     ; Sir Robin
display ok #StrRes
halt
```

An empty value keeps its place in `join`, so `str part` finds the same fields again. `str join _ a %empty c`, with
`%empty` holding empty text, gives `a__c`.

## Spaces and `_`

Text from the client holds its spaces in one of two ways, and `replace` and `part` take you at your word: `_` doesn't
match a real space, as with `str pos` and `in`.

| The text | Spaces are | Write |
|---|---|---|
| [`#Journal`](/variables/journal/), [`#SysMsg`](/variables/sysmsg/), `#ContName`, `#TileName`, `#ShopName` | `_` | `_` |
| [`#Property`](/variables/property/), `#CharName`, `#Shard`, `#CliTitle` | real spaces | [`#SPC`](/variables/spc/) |

```euo
set %line You_must_wait              ; as #Journal holds it
str part %line _ 3                   ; wait
display ok #StrRes
str replace %line _ #SPC             ; You must wait
display ok #StrRes
halt
```

`#Property` also ends each line with `$`, so `$` separates its lines, and it has one more field than it has lines,
an empty one after the last `$`. Here is the number from a line like `Uses Remaining: 25`:

```euo
event Property #FindID
str part #Property Remaining: 2      ; " 25$", and whatever lines follow
str part #StrRes $ 1                 ; " 25"
str trim #StrRes                     ; 25
set %uses #StrRes
str part #Property $ 1               ; the first line, the item's name
str part #StrRes #SPC 1              ; its first word
set %firstWord #StrRes
halt
```

To compare a `#Property` text the way you would a journal line, `str replace #Property #SPC _` gives you `_` everywhere.

## Words that can't be passed

A line is split into words, and a few words are read as part of the line before `str` gets them. This is true of every
command.

| To pass | Write | Why |
|---|---|---|
| A space | [`#SPC`](/variables/spc/) | A space ends a word. |
| A `.` | [`#DOT`](/variables/dot/) | A lone `.` glues the words on either side together, unless it is the last word. |
| A `;` at the start of a word | [`#SMC`](/variables/smc/) | A word starting with `;` starts a comment. |
| A `,` | Only as the last word | A lone `,` glues the words on either side together, even when it comes from a variable. |

So `str replace %s ,` removes the commas, but `str replace %s , _`, `str part %s , 2` and `str join , %a %b` can't work
and give `N/A`. To cut a text at a comma, use `str pos %s ,` followed by `str left` and `str del`.

## Reforged notes

- `str replace`, `str part`, `str trim`, `str join` and `str concat` are new. In EasyUO 1.5 these words did nothing but
  set `#StrRes` to `N/A`, as any unknown operation still does.
- The other operations are unchanged.
