---
title: "path Go"
description: "Plans a route to a place and walks it, waiting until the character gets there."
kind: subcommand
category: path
syntax: "path go {x} {y} [z] [accuracy] [timeout]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path walk", "path step", "path stop", "path find", "Move"]
aliases: ["walk to", "go to", "travel", "autowalk"]
---

`path go` plans a route from your character to `x`, `y` and walks it. Like [`Move`](/commands/move/), the
script waits until the walk is over; [`#PathState`](/variables/pathstate/) then says how it went.

```euo
path go 1434 1699
if #PathState <> arrived
  event SysMessage Did not get there: #PathState
```

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | Where to go, as in [`#CharPosX`](/variables/charposx/) and [`#CharPosY`](/variables/charposy/). |
| `z` | Optional height, as for [`path find`](/commands/path/find/): to pick a floor of a building or a dungeon level. |
| `accuracy` | Arrive within this many tiles. Without it, the `accuracy` of [`path set`](/commands/path/set/) (0: exactly there). To give it, give `z` too. |
| `timeout` | Give up after this long: a number of ticks of 50 ms, or a whole number of seconds followed by `s`, as for [`Move`](/commands/move/). Without it, there is no time limit. |

## Results

[`#PathState`](/variables/pathstate/) is one of:

| Value | Meaning |
|---|---|
| `arrived` | The character is there, within `accuracy`. When nothing can stand on the goal (a tree, a chest), next to it. |
| `blocked` | The way was cut on the way there, and no other route was found. |
| `failed` | The character couldn't get on: it stood still for 15 seconds, got no closer to the goal for 30, or every step from where it stands was refused. |
| `link` | The route uses a [`path link`](/commands/path/link/) the walker can't use by itself, a gate or a ladder: the character stands on its start. Use it, then [`path walk`](/commands/path/walk/) goes on. |
| `timeout` | The `timeout` ran out (or the first route took longer to plan than the `timeout` of [`path set`](/commands/path/set/)). |
| `stopped` | You pressed Stop. |
| `nopath`, `budget` | No route was found at the start, as for [`path find`](/commands/path/find/). |
| `noclient`, `nomap`, `error: …` | As for [`path find`](/commands/path/find/). |

[`#PathCnt`](/variables/pathcnt/), [`#PathX`](/variables/pathx/) … [`#PathDir`](/variables/pathdir/) show the
route that was being walked, as after [`path find`](/commands/path/find/). The walker plans again on the way
when it has to, so it can differ from the first one. [`path get`](/commands/path/get/) reads its steps.

## How it walks

- **One step at a time.** By default the walker walks the route step by step, with the walk macro
  ([`event Macro 5`](/commands/event/macro/)). A step the character doesn't take is sent again, and it counts
  as refused when the character still hasn't moved after one and a half seconds.
- **With the client's own pathfinder**, after [`path set mode client`](/commands/path/set/). The walker sends
  the client's pathfinder, the one [`event PathFind`](/commands/event/pathfind/) uses, to points along the
  route, each up to 18 tiles from the character (`lead` in [`path set`](/commands/path/set/)). Before sending
  a point, the walker runs the client's search on its own map, and only sends a point the client should
  accept. It is a little faster on open ground, but on `client_beta.exe` the client's walk often ends early
  or takes its own way, so it isn't the default.
  - The client's own walk ends by itself after a handful of steps, so the walker sends a fresh point every
    3 steps, and before the character gets to the last one. The character doesn't stop for them.
  - When the client's walk ends a few tiles before a point anyway, the walker takes those steps itself.
  - When the client refuses a point anyway ("Can't get there"), the next one is nearer. After a few
    refusals, it walks the next stretch one step at a time.
  - When the client takes a point but the character doesn't start moving, the walker walks the next stretch
    one step at a time straight away.
  - On a client whose pathfinder EasyUO Reforged doesn't know, it walks one step at a time anyway.
- **What it sees.** Besides the map files, it reads what your client holds around the character about once
  a second: items on the ground, doors, creatures and the walls and floors of player houses (on `client.exe`
  7.0.117.1, `client_beta.exe` 7.0.117.31, and other builds where EasyUO Reforged finds them). When
  something new stands on the next steps of the route, it plans again from where the character is. It also plans again when the character ends up off the route.
- **It asks the client.** About once a second, and whenever the route changes, the walker asks the client
  itself whether the next 12 tiles of the route can be walked (`check` in [`path set`](/commands/path/set/)),
  with the check the client runs before every step ([`path check`](/commands/path/check/)). A tile the client
  refuses is avoided like a refused step, before the character gets there, and the walker asks about the
  tiles round it too, so a house it couldn't see is learned in one go. Doors it opens and creatures are left
  to it. Where the client lands a step at another height (stairs it can't see), the walker takes the client's.
- **Refused steps.** A place where a step was refused is avoided for a minute (`blocktime` in
  [`path set`](/commands/path/set/)), and the walker plans around it. Planning around such a place first
  looks for a short way back onto the route; only if there is none does it plan the whole way again. [`path clear learned`](/commands/path/clear/) forgets these places.
- **Doors.** A door costs a little more than open ground (`doorcost`), so a route goes through one only when
  that saves steps. In front of a closed door, the walker turns to it and uses the Open Door macro
  ([`event Macro 12`](/commands/event/macro/)) before it steps through. The doors of player houses count as
  walls: a route doesn't go through somebody's house. [`path set doors all`](/commands/path/set/) opens
  them too, and `doors off` treats every door as a wall.
- **Put back.** When the server refuses a step the client had already shown, the client puts the character
  back. A tile the character is put back off twice is avoided like a refused step.
- **Giving up.** A walk that has got no closer to the goal for 30 seconds ends with `failed`.
- **Creatures** are in the way, except your own character. [`path set mobiles ignore`](/commands/path/set/)
  walks as if they weren't there; with full stamina a character can push through them.
- **Links.** On a teleporter added with [`path link`](/commands/path/link/), the walker steps on and waits up
  to 3 seconds for the jump. A link that needs using, such as a gate or a ladder, ends the walk with `link`.
- **Stop and Pause** work during the walk, as for [`Move`](/commands/move/). Time spent paused doesn't count
  as standing still.

## Notes

- The options, blocks, avoid areas and links of the other `path` commands apply to the walk.
- `path go` remembers its goal: after `link`, `timeout` or `stopped`, [`path walk`](/commands/path/walk/) goes on
  toward it.
- To do other things while walking, such as healing or reading the journal, use
  [`path step`](/commands/path/step/) in a loop instead.

## Reforged notes

New in EasyUO Reforged. Walking only happens on the facet you are on: a link to another facet is not followed.
See [Known limitations](/reforged/known-limitations/) for what has been checked on a live client.
