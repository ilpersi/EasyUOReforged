---
title: "event PathFind"
description: "Walks to a nearby spot, letting the client find a way around obstacles."
kind: subcommand
category: event
syntax: "event PathFind {x} {y} [z]"
needsClient: true
related: ["Move", "#CharPosX", "#CharPosY", "#SCnt"]
aliases: ["pathfinding", "walk to", "go to"]
dll: Pathfind
source: wiki
---

`event PathFind` makes the client walk your character to a world position, finding a way around walls and
obstacles.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | World position, as in [`#CharPosX`](/variables/charposx/) and [`#CharPosY`](/variables/charposy/). |
| `z` | Optional height. Default: your current [`#CharPosZ`](/variables/charposz/). |

## Details

- **The script does not wait** for the character to arrive. To wait, compare `#CharPosX` and `#CharPosY`
  with the target in a loop, with a timeout.
- **It only reaches spots within about one screen.** For longer trips, walk in several steps.
- When the client cannot find a way, it says so in the journal and the character does not move.

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Example

Walk to a spot and wait up to 10 seconds to get there:

```euo
set %x 1450
set %y 1630
event PathFind %x %y
set %until #SCnt + 10
while #CharPosX <> %x || #CharPosY <> %y
{
  if #SCnt > %until
    break
  wait 5
}
```
