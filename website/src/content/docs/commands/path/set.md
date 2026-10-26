---
title: "path Set"
description: "Changes an option of the pathfinder: accuracy, search limits, how to walk, doors, creatures and more."
kind: subcommand
category: path
syntax: "path set {option} {value}"
origin: reforged
sets: ["#PathState"]
related: ["path find", "path go"]
---

`path set` changes one option of [`path find`](/commands/path/find/) and of the walk
([`path go`](/commands/path/go/), [`path walk`](/commands/path/walk/), [`path step`](/commands/path/step/)).
The options last until the script is started again, which puts them back to the defaults below.

| Option | Default | Meaning |
|---|---|---|
| `accuracy` | `0` | The route may end this many tiles from the goal, in any direction. |
| `accuracyz` | `5` | When `path find` is given a height, the route may end this much above or below it. |
| `maxnodes` | `1000000` | How many places the search may look at before it gives up (`#PathState` `budget`). |
| `timeout` | `5s` | How long the search may take before it gives up (`timeout`). A time is a number of **ticks** of 50 ms, or a whole number of **seconds** followed by `s`. |
| `margin` | `100` | The search only looks this many tiles beyond the rectangle around start and goal (and around the links it can use). A route that needs a longer detour needs a bigger margin. |
| `turncost` | `30` | What a change of direction costs, in hundredths of a step. The client turns before it steps in a new direction, which takes time. |
| `heuristic` | `100` | How strongly the search heads for the goal, in percent. Above 100 the search is faster, but the route may be a little longer, with more turns. |
| `difs` | `off` | `on` also reads the client's map patch files (`mapdif*`, `stadif*`). The client only uses them when the shard tells it to. |

The walk:

| Option | Default | Meaning |
|---|---|---|
| `mode` | `auto` | How to walk. `steps`: one step at a time with the walk macro. `client`: send the client's own pathfinder to points along the route (where EasyUO Reforged knows it; else `steps`). `auto` is `steps` for now. |
| `lead` | `18` | In `client` mode, how far from the character, in tiles, a point may be. |
| `mobiles` | `block` | `ignore` plans through creatures, as if they weren't there. Your own character is never in the way. |
| `doors` | `on` | `on`: a route may go through a door, which the walker opens, except the doors of player houses. `all`: those too, to walk into your own house. `off`: doors are walls. |
| `doorcost` | `50` | What going through a door costs on top of the step, in hundredths of a step. |
| `blocktime` | `60s` | How long the walker avoids a place where a step was refused. A time, as for `timeout`. |
| `check` | `12` | How far ahead, in tiles from the character, the walker asks the client itself whether the route can be walked (see [`path check`](/commands/path/check/)). A tile the client refuses is avoided like a refused step, before the character gets there. `0` never asks. |
| `log` | `off` | A file the walker writes what it does to, one line each time it decides something: the waypoints it sends, the refusals and why, the replans, the steps, the doors. A name without a folder goes in the EasyUO Reforged folder; lines are added at the end. `off` stops it. For when a walk doesn't do what you expect. |

[`#PathState`](/variables/pathstate/) is `ok`, or `error: …` for an unknown option or a bad value.

## Example

```euo
path set accuracy 1        ; next to the goal is close enough
path set timeout 10s       ; long trips across the facet
path set mobiles ignore    ; push through crowds
path go 2505 552
```
