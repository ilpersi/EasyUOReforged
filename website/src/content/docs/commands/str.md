---
title: "Str"
description: "Performs a operation on a string."
kind: command
category: misc
syntax: "str {\"Len\"} {string}\nstr {\"Pos\"} {string} {sub string} [index]\nstr {\"Left\"} {string} {length}\nstr {\"Right\"} {string} {length}\nstr {\"Mid\"} {string} {start} {length}\nstr {\"Lower\"} {string}\nstr {\"Upper\"} {string}\nstr {\"Ins\"} {string} {sub string} {start}\nstr {\"Del\"} {string} {start} {length}\nstr {\"Count\"} {string} {substring}"
source: wiki
---

The [str](/commands/str/) command performs a string operation on the string given and stores the result in #strRes.

| Value | Description |
|----|----|
| Len | Stores the length of the string in the #strRes system variable. |
| Pos | Stores the position of the sub string in the #strRes system variable. *index* tells which occurrence to return (if there's more than one). |
| Left | Stores a part of the string taken from the left, in the #strRes system variable. |
| Right | Stores a part of the string taken from the right, in the #strRes system variable. |
| Mid | Stores a part of the string taken from the middle, in the #strRes system variable. |
| Lower | Stores a lower case version of the string in the #strRes system variable. |
| Upper | Stores an upper case version of the string in the #strRes system variable. |
| Ins | Inserts a string into the string and stores it in the #strRes system variable. |
| Del | Deletes a part of the string and stores it in the #strRes system variable. |
| Count | Returns the number of occurrences of substring in string. |

:::note
- Index parameter in Str Pos is only avalable from EUO 1.5 Test version 27.
- Str Count command is only avalable from EUO 1.5 Test version 27.
:::

## Example

```euo
set %string HELLO
str Len %string     ; #strRes = 5
str Pos %string LL  ; #strRes = 3
str Left %string 4  ; #strRes = HELL
str Right %string 2 ; #strRes = LO
str Mid %string 2 3 ; #strRes = ELL
str Lower %string   ; #strRes = hello
str Upper hello     ; #strRes = HELLO
str Ins %string I 3 ; #strRes = HELILO
str Del %string 3 2 ; #strRes = HEO
str Count %string L ; #strRes = 2

; This is a sample on how to use Str Count
; command and index parameter of Str Pos
; Made by Cheffe.

set %test _this_is_a_test_and_tests_are_cool_

str count %test _
for %cnt #strres 2
{
  set %tmp %cnt - 1
  str pos %test _ %tmp
  set %tmp #strres + 1
  str pos %test _ %cnt
  set %len #strres - %tmp
  str mid %test %tmp %len
  display ok #strres
}
```
