---
title: "Variables"
description: "The four kinds of variables (%, !, * and #), how names and values work, and who can see which."
sidebar:
  order: 1
source: wiki
---

A variable is a name that holds a value. Its first character says what kind it is:

| Kind | Example | Belongs to | Kept until |
|---|---|---|---|
| **Standard** | `%count` | The script, and scripts it starts with [`call`](/commands/call/). | The script starts again. |
| **Namespace** | `!count` | The current [namespace](/commands/namespace/): this script only, or shared with other scripts. | The script starts again (local) or EasyUO Reforged closes (global). |
| **Persistent** | `*count` | Every script, in this and the original EasyUO. | You change or delete it: it is saved in the registry. |
| **System** | `#CharName` | EasyUO and the client. | Built in; see the [variable reference](/variables/). |

## Names

- A name is made of letters, digits and `_`: `%loot_bag`, `%x2`. Nothing else, not even a `-`.
- Case does not matter: `%Count` and `%COUNT` are the same variable.
- `%0`, `%1`, `%2`, … hold the parameters of the last [`gosub`](/commands/gosub/) or [`call`](/commands/call/), so
  avoid names made of digits only.

```euo
set %var Bob
set %Var Joe
display ok %var              ; Joe: %var and %Var are the same variable
halt
```

## Values

- **A value is one word.** `set %a hello world` stores only `hello`. To store several words, write `_`
  between them, or glue them with commas and [`#SPC`](/variables/spc/): `set %a hello , #spc , world`.
- **Numbers and text are both just values.** A value that looks like a whole number (`42`, `-7`, `$1A`) can be
  used in calculations; anything else counts as `0` there. See [Expressions](/language/expressions/).
- **A variable that was never set reads `N/A`.**
- Use a variable anywhere in a line and its value is put in its place before the command runs. The one
  exception is the variable [`set`](/commands/set/) and [`for`](/commands/for/) assign to.

### Letters with accents

A letter with an accent in a script is the same letter in what the script reads from the client:
[`#Property`](/variables/property/), [`#Journal`](/variables/journal/), [`#SysMsg`](/variables/sysmsg/),
[`#CharName`](/variables/charname/), [`#Shard`](/variables/shard/),
[`#ShopItemName`](/variables/shopitemname/) and [`#CliTitle`](/variables/clititle/). So `in`, `=`,
[`findjournal`](/commands/findjournal/) and [`waitfor`](/commands/waitfor/) find it, and
[`str`](/commands/str/) counts it as one letter:

```euo
event Property #FindID
if Qualità in #Property
  display ok The item lists its quality.
halt
```

```euo
str len Qualità
set %n #StrRes                 ; => %n = 7
str right Qualità 1
set %last #StrRes              ; => %last = à
halt
```

- Text a script sends to the client keeps its letters too: [`msg`](/commands/msg/),
  [`setuotitle`](/commands/setuotitle/) and [`execute`](/commands/execute/) send every letter.
  [`event SysMessage`](/commands/event/sysmessage/), [`event ExMsg`](/commands/event/exmsg/) and
  [`exevent RenamePet`](/commands/exevent/renamepet/) send one byte per letter, so a letter outside Western
  European (`ł`, `ж`, `’`) arrives as `?`.
- The client itself keeps only Western European letters in `#Property`, `#Journal` and `#SysMsg`: any other
  letter (`ł`, `’`, `…`) reads as a different character there, as it did in EasyUO 1.5.
- A sub-script saved in the old Windows encoding instead of UTF-8 is read by [`call`](/commands/call/) as the
  editor reads it, so its letters match too.
- [uo.dll](/dll/) is unchanged: its texts keep one byte per letter, as in EasyUO 1.5.

## Standard variables: `%`

Standard variables are the everyday kind. They belong to the running script and are shared with scripts it
starts with `call`. They are all cleared when the script starts again.

## Namespace variables: `!`

`!x` is the variable `x` of the current [namespace](/commands/namespace/). A script starts in the local
namespace `std`, so until you switch, `!` variables behave like `%` variables. Switch namespaces to give a sub
its own variables ([`namespace local`](/commands/namespace/local/)) or to share variables with other scripts
running in EasyUO Reforged ([`namespace global`](/commands/namespace/global/)).

## Persistent variables: `*`

Persistent variables survive restarts: they are saved in the Windows registry, under
`HKEY_CURRENT_USER\Software\EasyUO`, and every script on the computer can read them. EasyUO Reforged uses the
same place as the original EasyUO, so the two share them.

```euo
if *runs = N/A
  set *runs 0
set *runs *runs + 1
display ok This script has run *runs times.
halt
```

For more data, or data you want to keep in a file of your own, there is also [`SQL`](/commands/sql/).
[Keeping data between runs](/guides/persistence/) compares them with the other ways a script keeps data.

## System variables: `#`

System variables are built in. Most describe the client and your character (`#CharPosX`, `#Hits`,
`#FindID`); a few describe EasyUO itself (`#Time`, `#LPC`). Most are read-only; the writable ones are marked
**Read / write**. They are listed in the [variable reference](/variables/).
