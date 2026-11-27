---
title: "Str"
description: "Works on a piece of text (length, position, part, case, replace, split, trim, join, insert, delete, count, encode) and formats times, dates and decimals; the result goes to #StrRes."
kind: command
category: misc
changed: true
syntax: "str {operation} {text} [parameters...]"
sets: ["#StrRes"]
related: ["#StrRes", "#SPC", "#DOT", "#SMC", "Send", "Timer", "#Time", "#Date"]
aliases: ["string", "text", "substring", "length", "replace", "split", "trim", "join", "concat", "concatenate", "url encode", "json escape", "encode", "format", "decimal", "duration", "date format", "time format", "clock", "datetime", "h:mm:ss"]
source: wiki
---

`str` works on a piece of text and puts the result in [`#StrRes`](/variables/strres/).

| Operation | Result in `#StrRes` | EasyUO 1.5 |
|---|---|---|
| `str len {text}` | The number of characters. | Yes |
| `str pos {text} {part} [n]` | Where `part` starts in `text`, counting from 1; with `n`, where its `n`-th occurrence starts. `0` when it is not there. | Yes |
| `str count {text} {part}` | How many times `part` occurs in `text`. | Yes |
| `str left {text} {n}` | The first `n` characters. | Yes |
| `str right {text} {n}` | The last `n` characters. | Yes |
| `str mid {text} {start} {n}` | `n` characters starting at character `start`. | Yes |
| `str lower {text}` | The text in lower case. | Yes |
| `str upper {text}` | The text in upper case. | Yes |
| `str ins {text} {part} {start}` | The text with `part` inserted at character `start`. | Yes |
| `str del {text} {start} {n}` | The text with `n` characters removed, starting at character `start`. | Yes |
| `str replace {text} {search} [with]` | The text with every `search` replaced by `with`, or removed when `with` is left out. | **No:** new in Reforged |
| `str part {text} {separator} {n}` | The `n`-th field between separators, counting from 1. `N/A` when there is no such field. | **No:** new in Reforged |
| `str trim {text} [chars]` | The text without those characters at either end. Without `chars`: spaces and `_`. | **No:** new in Reforged |
| `str join {separator} {text} [text...]` | The texts in order, with the separator between them. | **No:** new in Reforged |
| `str concat {text} [text...]` | The texts in order, with nothing between them. | **No:** new in Reforged |
| `str urlencode {text}` | The text made safe inside a URL's query or form data: every character but `A-Z a-z 0-9 - _ . ~` written as `%XX`. | **No:** new in Reforged |
| `str jsonescape {text}` | The text made safe between the quotes of a JSON string: `"`, `\` and line breaks escaped. | **No:** new in Reforged |
| `str decimal {number} {places}` | The whole number written with `places` decimals: `str decimal 953 1` gives `95.3`. | **No:** new in Reforged |
| `str duration {seconds} [format]` | A number of seconds as `h:mm:ss`, or in the format given. | **No:** new in Reforged |
| `str date {yymmdd} [format]` | A [`#Date`](/variables/date/) value as `yyyy-mm-dd`, or in the format given. | **No:** new in Reforged |
| `str clock {hhmmss} [format]` | A [`#Time`](/variables/time/) value as `hh:mm:ss`, or in the format given. | **No:** new in Reforged |
| `str datetime {yymmdd} {hhmmss} [format]` | A date and a time together, as `yyyy-mm-dd hh:mm:ss`, or in the format given. | **No:** new in Reforged |

:::note[Writing for EasyUO 1.5 too]
`replace`, `part`, `trim`, `join`, `concat`, `urlencode`, `jsonescape`, `decimal`, `duration`, `date`, `clock` and
`datetime` are new in EasyUO Reforged. EasyUO 1.5 knows only the other ten: there, these twelve set `#StrRes` to
`N/A` and do nothing else, with no error. A script that must also run on
EasyUO 1.5 uses only the operations marked *Yes*, and does the rest with `pos`, `left`, `mid` and `del`.
:::

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

### Replace (Reforged)

```euo
str replace red_red_blue RED green   ; green_green_blue
display ok #StrRes
str replace a-b-c -                  ; abc: nothing to replace it with, so it is removed
display ok #StrRes
halt
```

A replacement may contain what it replaces: `str replace a_b _ __` gives `a__b`. When `search` isn't in the text,
or is empty, the result is the text unchanged.

### Split (Reforged)

`str part` takes one field out of a text. Use it with `for` and `str count` to go through all of them: a text has one
field more than it has separators. [`list split`](/commands/list/#splitting-and-joining) cuts the whole text into
a list in one line, and `list join` puts it back.

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

### Trim (Reforged)

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

### Join and concat (Reforged)

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

### Encode for send (Reforged)

Data that [`send`](/commands/send/) carries has its own special characters: `&` and `=` separate the fields of form
data, and `"` and `\` end or escape a JSON string. Pass a value that may hold them, or spaces, through `urlencode`
(form data, a URL's query) or `jsonescape` (JSON) before you glue it in:

```euo
set %msg Gold , #SPC , & , #SPC , gems
str urlencode %msg
set %enc #StrRes              ; => %enc = Gold%20%26%20gems
set %data text= , %enc        ; => %data = text=Gold%20%26%20gems
set %say He , #SPC , said , #SPC , "hi"
str jsonescape %say
set %esc #StrRes              ; => %esc = He said \"hi\"
set %body {"content":" , %esc , "}
halt
```

Both work on the bytes of the text, so letters with accents keep working: `urlencode` writes each of their bytes as
`%XX`, `jsonescape` leaves them as they are. Neither cares about case.

### Time and numbers (Reforged)

Skill values are tenths (`953` is 95.3), and [`#Time`](/variables/time/), [`#Date`](/variables/date/) and
[`timer`](/commands/timer/) give plain numbers. These operations write them for people to read:

```euo
str decimal 953 1
set %skill #StrRes           ; => %skill = 95.3
str decimal -5 1
set %loss #StrRes            ; => %loss = -0.5
str duration 3725
set %ran #StrRes             ; => %ran = 1:02:05
str date 261122
set %day #StrRes             ; => %day = 2026-11-22
str clock 143005
set %at #StrRes              ; => %at = 14:30:05
str datetime 261122 143005
set %stamp #StrRes           ; => %stamp = 2026-11-22 14:30:05
halt
```

- `decimal` puts the point `places` digits from the right and adds zeros where needed: `str decimal 7 2` gives
  `0.07`. `places` goes from `0` (the number as it is) to `18`. The point is always `.`, whatever the Windows
  settings say.
- `duration` doesn't stop at 24 hours: `str duration 90000` gives `25:00:00`. A negative number gets a `-`.
- `date` and `clock` take the value with or without its leading zeros, so `93015`, which arithmetic makes of
  `093015`, is still `09:30:15`. The year is 20yy. A value that isn't a real date or time gives `N/A`.

A skill gain per hour, from a gain in tenths and a number of seconds, is one line of arithmetic and a `decimal`:

```euo
set %gain 12                 ; 1.2 points, in tenths
set %secs 1800               ; in half an hour
set %rate %gain * 3600 / %secs
str decimal %rate 1
set %perHour #StrRes         ; => %perHour = 2.4
halt
```

### Date and time formats (Reforged)

`duration`, `date`, `clock` and `datetime` take a format after the value: everything else on the line, the words
joined by one space. The letters of the format stand for parts of the time, as in FreePascal's `FormatDateTime`:

| Letters | Gives | `date` | `clock` | `datetime` | `duration` |
|---|---|---|---|---|---|
| `d` `dd` | Day: `5`, `05` | Yes | | Yes | |
| `ddd` `dddd` | Weekday: `Sun`, `Sunday` | Yes | | Yes | |
| `m` `mm` | Month: `1`, `01` (minutes in `clock` and `duration`, and right after an `h`) | Yes | Yes | Yes | Yes |
| `mmm` `mmmm` | Month: `Nov`, `November` | Yes | | Yes | |
| `yy` `yyyy` | Year: `26`, `2026` | Yes | | Yes | |
| `h` `hh` | Hour: `9`, `09` | | Yes | Yes | Yes |
| `n` `nn` | Minutes: `5`, `05` | | Yes | Yes | Yes |
| `s` `ss` | Seconds: `5`, `05` | | Yes | Yes | Yes |
| `z` `zzz` | Milliseconds (always `0` here) | | Yes | Yes | Yes |
| `am/pm` `a/p` `ampm` | A 12-hour clock: `am`/`pm` as written, `a`/`p`, or `AM`/`PM` | | Yes | Yes | |
| `[h]` `[n]` `[s]` | All the hours, minutes or seconds, not stopping at 24 or 60 | | | | Yes |

```euo
str date 261122 dd/mm/yyyy
set %eu #StrRes              ; => %eu = 22/11/2026
str date 261122 dddd d mmmm yyyy
set %long #StrRes            ; => %long = Sunday 22 November 2026
str date 261122 yyyymmdd
set %file #StrRes            ; => %file = 20261122
str clock 143005 h:nn am/pm
set %twelve #StrRes          ; => %twelve = 2:30 pm
str datetime 261122 143005 dd/mm hh:nn
set %short #StrRes           ; => %short = 22/11 14:30
str duration 3725 [n] min
set %mins #StrRes            ; => %mins = 62 min
str duration 3725 h hours n min
set %words #StrRes           ; => %words = 1 hours 2 min
halt
```

**Text in a format needs no quotes.** A word is read as letters for the time only when every one of its letters
is one of them for that operation; any other word is written as it is. `Today`, `hours` and `min` stay words, and
so does `day:`, because `a` is not a time letter. Day and month names are always English, and `/` and `:` are
always `/` and `:`, whatever the Windows settings say. The letters `c`, `f`, `t`, `e` and `g`, which mean something
to `FormatDateTime`, are always plain letters here.

Quote a word made only of time letters to write it as it is, with `'...'` or `"..."`:

```euo
str date 261122 dd mmmm 'my' birthday
set %a #StrRes               ; => %a = 22 November my birthday
str date 261122 dd mmmm my birthday
set %b #StrRes               ; => %b = 22 November 1126 birthday
str duration 1500 [s] 'ms'
set %c #StrRes               ; => %c = 1500 ms
str clock 143005 hh:nn 'h'
set %d #StrRes               ; => %d = 14:30 h
halt
```

Without the quotes `my` is a month and a year, `ms` minutes and seconds, and `h` the hour again. A quoted text may
hold spaces. Five or more `d` in a row, and a result longer than 254 characters, give `N/A`. A duration goes up to
2147483647 seconds (68 years).

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

- `str replace`, `str part`, `str trim`, `str join`, `str concat`, `str urlencode` and `str jsonescape` are new. In
  EasyUO 1.5 these words did nothing but set `#StrRes` to `N/A`, as any unknown operation still does.
- Lengths and positions count letters: `str len Mèrlin` is `6` and `str left Mèrlin 2` is `Mè`, as in EasyUO 1.5.
  Reforged stores text as UTF-8, where `è` takes two bytes, and counted those bytes before. `urlencode` and
  `jsonescape` work on the bytes, as they must. See [Letters with accents](/language/variables/#letters-with-accents).
- The other operations are unchanged.
