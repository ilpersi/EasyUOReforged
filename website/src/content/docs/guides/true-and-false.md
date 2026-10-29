---
title: "#True and #False"
description: "How to use #True and #False as on/off flags, and why if %flag only works with #True."
sidebar:
  order: 3
source: wiki
---

[`#True`](/variables/true/) and [`#False`](/variables/false/) are on/off values: `#True` for yes, on, done,
`#False` for no, off, not yet. They make conditions short and easy to read.

Without them, a setting is usually written as text:

```euo
set %usemagery yes

if %usemagery = yes
  display ok Heal with Magery.
if %usemagery = no
  display ok Heal with bandages.
halt
```

With them, the condition reads like a sentence:

```euo
set %usemagery #True

if %usemagery
  display ok Heal with Magery.
if ! %usemagery
  display ok Heal with bandages.
halt
```

`if %usemagery` runs the next line when `%usemagery` is true; `if ! %usemagery` turns the test around and runs it
when it is false.

## Why it has to be `#True`

`#True` is the number `-1` and `#False` is `0`, the same values comparisons such as `%a = 1` give. [`if`](/commands/if/),
[`while`](/commands/while/) and [`until`](/commands/repeat/) treat **only `-1`** as true. So:

| `%flag` holds | `if %flag` | `if ! %flag` |
|---|---|---|
| `#True` (`-1`) | runs | skips |
| `#False` (`0`) | skips | runs |
| Text, such as `yes` | skips | runs: text counts as `0`, so `yes` behaves like `#False` |
| `1` or any other number | skips | **also skips** |

Set flags with `#True` and `#False`, never with `yes` or `1`, and `if %flag` / `if ! %flag` always do what they
say.

*Based on a quick guide by Una from the EasyUO wiki.*
