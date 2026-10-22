---
title: "Str"
description: "Works on a piece of text (length, position, part, case, insert, delete, count); the result goes to #StrRes."
kind: command
category: misc
syntax: "str {operation} {text} [parameters...]"
sets: ["#StrRes"]
related: ["#StrRes"]
aliases: ["string", "text", "substring", "length"]
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

`pos` and `count` ignore case. When parameters are missing, `#StrRes` is `N/A`.

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
```

Split a text at `_`, using `count` and the occurrence parameter of `pos`:

```euo
set %test _this_is_a_test_
str count %test _
set %parts #StrRes - 1
for %n 1 %parts
{
  str pos %test _ %n
  set %from #StrRes + 1
  set %next %n + 1
  str pos %test _ %next
  set %len #StrRes - %from
  str mid %test %from %len
  display ok #StrRes
}
```
