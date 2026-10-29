---
title: "#CharStatus"
description: "Letters for your character’s states: poisoned, hidden, war mode and more."
kind: variable
category: character
access: ro
type: string
needsClient: true
related: ["#CharGhost", "event Macro"]
aliases: ["poisoned", "hidden", "war mode", "status flags"]
dll: CharStatus
source: wiki
---

`#CharStatus` is a short string of letters, one for each state your character is in, or empty when none
applies. Test a letter with `in`:

| Letter | State |
|---|---|
| `A` | Frozen: paralysed, casting a spell, or waiting after using the help menu. |
| `B` | Female. |
| `C` | Poisoned. |
| `D` | Affected by lethal strike. |
| `G` | War mode. |
| `H` | Hidden. |

The letters come from the client's status flags, one letter per flag (`A` for the first, `B` for the second,
and so on), so other letters can appear for flags not listed here. They are in reverse order: war mode and
female read `GB`.

## Example

```euo
if C in #CharStatus
  display ok You are poisoned.
if H notin #CharStatus
  event macro 13 21          ; use Hiding
halt
```
