---
title: "Move"
description: "Walks the character towards a position with the arrow keys; no pathfinding."
kind: command
category: client
syntax: "move {x} {y} [tolerance] [timeout]"
needsClient: true
related: ["event PathFind", "Path", "#CharPosX", "#CharPosY"]
aliases: ["walk", "go to"]
dll: Move
source: wiki
---

`move` walks the character towards the world position `x`, `y` by pressing the movement keys, step by step
in a straight line. It does **no pathfinding**: walls and obstacles stop it. [`event PathFind`](/commands/event/pathfind/)
lets the client find a way around them, and [`path find`](/commands/path/find/) plans longer routes.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | World position, as in [`#CharPosX`](/variables/charposx/) and [`#CharPosY`](/variables/charposy/). |
| `tolerance` | Optional. How many tiles away counts as arrived. Default: 2. |
| `timeout` | Optional. Give up after this long. A time is a number of **ticks** of 50 ms (`20` is one second), or a whole number of **seconds** followed by
`s` (`5s`). |

Without a timeout, `move` keeps walking until it arrives, or until it notices it is stuck and stops trying.

:::caution
`move` uses the cursor keys, Home, End, Page Up and Page Down. If UOAssist or a similar tool has those keys
assigned to something else, the character won't walk.
:::

## Example

```euo
; get within 2 tiles of 1234,1234, giving up after 3 seconds
move 1234 1234 2 3s
```
