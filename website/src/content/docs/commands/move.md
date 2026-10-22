---
title: "Move"
description: "Moves the character to a specified location."
kind: command
category: client
syntax: "move {X-Coordinate} {Y-Coordinate} [tolerance] [timeout]"
needsClient: true
related: ["event pathfind"]
source: wiki
---

The move command moves the character to a specified position. No pathfinding is done, so you should probably use [event PathFind](/commands/event/pathfind/) instead.

If unspecified, tolerance defaults to 2.

if unspecified, timeout defaults to 3s.

:::note
Please note that if you are using UOAssist, you need to make sure these keys are not assigned to anything: Cursor Up, Cursor Down, Cursor Left, Cursor Right, Home, End, Page Up and Page Down. EasyUO uses these keys to move your character.
:::

## Example

```euo
; This will attempt to get within 2 tiles of location 1234 1234.
; If it does not get there within 3 seconds it will give up.
; The closest it will get is 2 tiles away, lower that arguement to get closer.
move 1234 1234 2 3s
```
