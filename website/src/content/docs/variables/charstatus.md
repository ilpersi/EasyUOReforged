---
title: "#CharStatus"
description: "Letters for your character’s states: frozen, female, flying or poisoned, yellow health bar, war mode, hidden."
kind: variable
category: character
access: ro
type: string
needsClient: true
related: ["#CharGhost", "event Macro"]
aliases: ["poisoned", "hidden", "war mode", "status flags", "flying", "frozen", "paralysed"]
dll: CharStatus
source: wiki
---

`#CharStatus` is a short string of letters, one for each state your character is in, or empty when none
applies. Test a letter with `in`:

| Letter | State |
|---|---|
| `A` | Frozen: paralysed, held in place by the server, or casting a spell that stops you moving. The client won't let you walk. |
| `B` | Female. |
| `C` | Flying (a gargoyle in flight), or poisoned: see [Poison](#poison). |
| `D` | Yellow health bar: for example when you are hit by a lethal strike, or when you are invulnerable. |
| `E` | You can walk through other characters. |
| `G` | War mode. |
| `H` | Hidden. |

Each letter is one of the status flags the server sends for your character: `A` for the first, `B` for the
second, and so on up to `H`. No other letter appears. `F` is a flag the client only uses for items, and servers
don't set it on a character. The letters after `H` would come from the next byte in the client's memory, which
for a character is always 0. The letters are in reverse order: war mode and female read `GB`.

## Poison

On current clients the server doesn't send poison as a status flag. It sends poison and the yellow health bar
as two separate health-bar states, and `#CharStatus` adds `C` when exactly one of the two is on:

| You are | `C` |
|---|---|
| Poisoned | yes |
| Poisoned, with a yellow health bar | no |
| Not poisoned, with a yellow health bar | yes |

The yellow bar always comes with `D`, so you are poisoned when you have `C` without `D`, or `D` without `C`.
Flying also sets `C`, so for a gargoyle this only holds while it is on the ground.

## Example

```euo
set %poisoned #false
if C in #CharStatus
  set %poisoned #true
if D in #CharStatus          ; a yellow bar reverses what C says
  set %poisoned ! %poisoned
if %poisoned
  display ok You are poisoned.
if H notin #CharStatus
  event macro 13 21          ; use Hiding
halt
```
