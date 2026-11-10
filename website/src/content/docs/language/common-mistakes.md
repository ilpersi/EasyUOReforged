---
title: "Common mistakes"
description: "The rules of the language that scripts break most often, each with an example that shows what really happens."
sidebar:
  order: 5
---

EasyUO reports no errors. A line it can't understand is skipped, and the script goes on. So a mistake shows up
only as a script that does the wrong thing, or nothing. This page lists the rules behind most such scripts.

In the examples, a comment that starts with `=>` shows what a variable holds when the script has stopped. These
examples are run through the interpreter every time EasyUO Reforged is tested, so they show what really happens.

## The rules that matter most

1. **A name that doesn't exist gives no error.** A line that starts with a word that is not a
   [command](/commands/) is skipped, and a [`#variable`](/variables/) that doesn't exist reads `N/A`. Take
   every command and every `#variable` from the lists, never from memory or from another language.
2. **Every word needs spaces around it,** operators and parentheses included: `if ( %a > 1 )`,
   `set %a %b + 1`. `(%a > 1)` and `%b+1` are not understood.
3. **Only a few commands calculate:** `set`, `if`, `while`, `until`, `return` and `waitfor`. Every other
   command takes its words as they are: `wait %a + 1` waits `%a` ticks. Calculate with `set` first.
4. **True is `-1`, false is `0`.** Use [`#true`](/variables/true/) and [`#false`](/variables/false/).
   `if %flag` is true only when `%flag` holds `-1`: `if 1` and `if yes` are false.
5. **A value is one word.** `set %a hello world` stores `hello`. Write spaces as `_`, or glue words with a
   comma: `set %a hello , #spc , world`.
6. **A block's `{` is alone on the very next line** after its command, and `}` is alone on its line. Without a
   block, the command controls only the next line.
7. **End the script with [`halt`](/commands/halt/).** Reaching the last line starts the script again from the
   top, and [`exit`](/commands/exit/) in the main script does the same. Only `halt` and `stop` stop it.
8. **Put subs after the `halt`,** where the normal flow never reaches them. Leave a sub with `return`, never
   with `goto`.
9. **A time is in ticks of 50 ms:** `wait 20` is one second. Or write seconds with an `s`: `wait 5s`.
   Only [`sleep`](/commands/sleep/) counts in milliseconds.
10. **Game values are your own.** Item types (`POF`), IDs (`YKLMNOP`), gump names, journal texts and screen
    positions differ between shards, clients and characters. Don't take them from someone else's script
    without checking: [Finding IDs and types](/guides/finding-ids/) shows how to read yours.

Each rule in a script:

```euo
set %a 1
nosuchcommand %a 2              ; rule 1: not a command, so the line is skipped
set %v #nosuchvariable          ; => %v = N/A
set %b %a + 1                   ; => %b = 2
set %c %a+1                     ; => %c = %a+1
halt                            ; => %a = 1
```

`%a+1` in the third `set` is one word (rule 2), so nothing is replaced and nothing is added.

```euo
set %a 2
set %right no
set %wrong no
if ( %a > 1 )
  set %right yes                ; => %right = yes
if (%a > 1)
  set %wrong yes                ; => %wrong = no
halt
```

```euo
set %a 5
gosub count %a + 1              ; rule 3: gosub doesn't calculate, it passes three words
halt

sub count
  set %words %0                 ; => %words = 3
  set %first %1                 ; => %first = 5
return
```

```euo
set %x 0
if 1
  set %x %x + 1                 ; rule 4: skipped, 1 is not true
if yes
  set %x %x + 1                 ; skipped
if #true
  set %x %x + 10                ; runs
set %t 2 > 1                    ; => %t = -1
set %f 2 < 1                    ; => %f = 0
halt                            ; => %x = 10
```

```euo
set %a hello world              ; => %a = hello
set %b hello_world              ; => %b = hello_world
set %c hello , #spc , world     ; => %c = hello world
halt
```

```euo
set %n 0
if 1 = 2
{
  set %n %n + 1                 ; rule 6: skipped with its block
}
if 1 = 2

{
  set %n %n + 10                ; runs: the blank line was the one line the if controls
}
halt                            ; => %n = 10
```

```euo
set %runs %runs + 1
if %runs < 3
  exit                          ; rule 7: back to the first line, the variables keep their values
halt                            ; => %runs = 3
```

## Which commands do what

| | Commands |
|---|---|
| Calculate their parameters | `set` `if` `while` `until` `return` `waitfor` |
| Take a `{ }` block, or else the next line | `if` `else` `for` `while` `sub` `onhotkey` `cmppix` |
| Take a time in ticks, or in seconds with `s` | `wait` `waitfor` `findjournal` `target` `move` `path` |

## Lines

- One command per line. The first word is the command, the rest are its parameters.
- `;` starts a comment, anywhere on a line. For a `;` in a text use [`#smc`](/variables/smc/), for a `.`
  [`#dot`](/variables/dot/), for a space [`#spc`](/variables/spc/).
- Case doesn't matter, for commands, variables, sub names and text comparisons.
- A line starting with `+` continues the line before it. The pieces join **without** a space, so write
  `+ more` where you want one.
- A label is a name followed by `:` on a line of its own (`mainloop:`). `goto mainloop` jumps to it.

```euo
set %text abc
+def
halt                            ; => %text = abcdef
```

## Variables

- A variable that was never set reads `N/A`.
- A variable is replaced by its value only when it is a word of its own. Glue it to other text with a comma.
- `%0`, `%1`, `%2`, … are the parameters of the last `gosub` or `call`. They are ordinary variables shared by
  the whole script, so a sub that calls another sub loses its own. Copy them first.
- Numbers are whole numbers. `$1A` is hexadecimal. Text counts as `0` in arithmetic.
- `%a , %b` joins two values into one word. `%item . %i` builds a variable name: with `%i` holding `2` it
  reads `%item2`. That is how scripts make lists.

```euo
set %a %never                   ; => %a = N/A
set %count 3
set %text gold:%count           ; => %text = gold:%count
set %glued gold: , %count       ; => %glued = gold:3
set %hex $1A + 0                ; => %hex = 26
set %sum abc + 5                ; => %sum = 5
set %item1 sword
set %item2 shield
set %i 2
set %name %item . %i            ; => %name = shield
halt
```

```euo
gosub outer A
halt

sub outer
  gosub inner B
  set %mine %1                  ; => %mine = B
return

sub inner
return
```

## Conditions

- `=` and `<>` compare as text, ignoring case, when either side is not a number.
- `<` `>` `<=` `>=` are **always false** when either side is not a number, `N/A` included.
- `in` and `notin` test whether the left text is inside the right one.
- `&&` binds tighter than `||`.
- `!` turns around only the value right after it. Write `if ! ( %a = 2 )` or `if %a <> 2`, never
  `if ! %a = 2`.
- `/` drops the remainder, and dividing by 0 gives `0`.

```euo
set %a hello
set %r1 %a = HELLO              ; => %r1 = -1
set %r2 %a > 33                 ; => %r2 = 0
set %r3 %a < 33                 ; => %r3 = 0
set %r4 ell in %a               ; => %r4 = -1
set %r5 1 = 1 || 1 = 2 && 1 = 3 ; => %r5 = -1
set %b 1
set %r6 ! ( %b = 2 )            ; => %r6 = -1
set %r7 ! %b = 2                ; => %r7 = 0
set %r8 7 / 2                   ; => %r8 = 3
set %r9 7 / 0                   ; => %r9 = 0
set %r10 2 + 3 * 4              ; => %r10 = 14
halt
```

## Loops and subs

- [`for`](/commands/for/) counts **down** when its start is larger than its end. So `for %i 1 #FindCnt`
  runs twice, for 1 and for 0, when [`finditem`](/commands/finditem/) found nothing. Test `#FindCnt > 0`
  first.
- A [`gosub`](/commands/gosub/) to a sub that doesn't exist does nothing, and so does a
  [`call`](/commands/call/) of a file that isn't found.
- `return %x` puts `%x` in [`#Result`](/variables/result/).
- Old scripts write `if %a > 1 2` to make the `if` control the next 2 lines. Read it that way when you meet
  it, and write blocks in new scripts.

```euo
set %runs 0
for %i 1 0
  set %runs %runs + 1
halt                            ; => %runs = 2
```

```euo
gosub add 2 3
set %sum #Result                ; => %sum = 5
set %after before
gosub nosuchsub
set %after after                ; => %after = after
halt

sub add
return %1 + %2
```
