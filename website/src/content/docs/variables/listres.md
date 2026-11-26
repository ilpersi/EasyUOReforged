---
title: "#ListRes"
description: "The answer of the last list line: a count, a value, a position, or the values joined into one text."
kind: variable
category: result
access: ro
type: string
origin: reforged
related: ["List", "#StrRes", "#Result"]
aliases: ["list result", "array result"]
---

`#ListRes` holds the answer of the last [`list`](/commands/list/) line:

| Line | `#ListRes` |
|---|---|
| `list add`, `insert`, `set`, `delete`, `clone`, `sort`, `split` | How many values the list has afterwards. |
| `list merge`, `intersect`, `subtract` | How many values the new list has. |
| `list clear` | `0`. |
| `list count` | How many values the list has; `0` for a list never made. |
| `list get` | The value at that position. |
| `list indexof`, `list find` | The position found, or `0`. |
| `list join` | The values joined into one text. |

It is `N/A` before the first `list` line of a run, and after a line with a missing or wrong word, which changes
nothing. A value can be the text `N/A` too, so to know whether a position exists, compare it with
`list count`.

A value with spaces keeps them in `#ListRes`, as [`#Property`](/variables/property/) does, and a later line that
uses `#ListRes` gets it as one word.

`#ListRes` has its own variable so that a `list` line doesn't overwrite [`#StrRes`](/variables/strres/) or
[`#Result`](/variables/result/).

## Example

```euo
list add ores iron gold
set %count #ListRes              ; => %count = 2
list get ores 1
set %first #ListRes              ; => %first = iron
list find ores old
set %where #ListRes              ; => %where = 2
halt
```
