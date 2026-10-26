---
title: "path Check"
description: "Asks the client itself whether the character can take a step, and at what height it lands."
kind: subcommand
category: path
syntax: "path check {n}\npath check {x} {y} [z] [dir]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path can", "path find", "path go", "event PathFind"]
aliases: ["can step", "walkable", "client check"]
---

`path check` asks your client whether the character can take a step, with the same check the client runs
before every step it sends, and that its own pathfinder ([`event PathFind`](/commands/event/pathfind/)) uses.
The client knows everything it holds: house walls and floors, custom houses, items players placed, as well
as the map. [`path can`](/commands/path/can/) answers from the map files plus what EasyUO Reforged can read
of those.

- `path check {n}` checks step `n` of the last route ([`path find`](/commands/path/find/) or
  [`path go`](/commands/path/go/)), from the step before it, at the height the route has there. A diagonal
  step also needs both straight steps beside it free, so those are checked too.
- `path check {x} {y} [z] [dir]` checks the step onto `x`, `y` in direction `dir` (0 north to 7 north-west,
  as [`#CharDir`](/variables/chardir/); default 0) from the tile behind it, at height `z` (default:
  your character's [`#CharPosZ`](/variables/charposz/)). The tile behind it is the one the step comes from:
  south of `x`, `y` for direction 0.

```euo
path check #CharPosX #CharPosY
event SysMessage My own tile: #PathState at #PathZ
path find 2708 490
for %i 1 #PathCnt
{
  path check %i
  if #PathState <> ok
  {
    event SysMessage Step %i: #PathState at #PathX #PathY
    break
  }
}
halt
```

## Results

| Variable | Value |
|---|---|
| [`#PathState`](/variables/pathstate/) | `ok`: the client allows the step. `blocked`: it doesn't (a shut door is `blocked` too). `noclient`, `nocheck` (EasyUO Reforged doesn't know this client's check, or the client didn't answer), or `error: …`. |
| [`#PathX`](/variables/pathx/), [`#PathY`](/variables/pathy/) | The tile checked. For a diagonal step the client refused, the tile that was in the way, which can be one of the two beside it. |
| [`#PathZ`](/variables/pathz/) | The height the character lands at; 0 when the step is refused. |
| [`#PathDir`](/variables/pathdir/) | The direction of the step. |

[`#PathCnt`](/variables/pathcnt/) and the route are left alone.

## Notes

- **Only what the client has loaded.** A tile the client hasn't loaded has nothing to stand on, so it reads
  as `blocked`. Both clients keep about 18 tiles round the character loaded, often more.
- **A step, not a place.** The answer depends on the height you step from and the direction: a staircase can
  be climbed from one side only, a high floor reached only by its stairs. To ask whether a character could
  stand on a tile at all, use [`path can`](/commands/path/can/).
- **Creatures** block only when your character's stamina isn't full, as when walking. Your own character
  never does.
- The walker asks the same of the client by itself, about the next 12 tiles of its route
  (`check` in [`path set`](/commands/path/set/)).

## Reforged notes

New in EasyUO Reforged. It calls the same function in the client as the `uo.dll` method
[`BlockInfo`](/dll/blockinfo/), one step at a time instead of an area at height `z` stepping north.
