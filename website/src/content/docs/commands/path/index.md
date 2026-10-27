---
title: "Path"
description: "Plans a walking route across the map, around walls, water and buildings, with stairs and bridges, and walks it."
kind: command
category: path
syntax: "path {go|walk|step|stop|find|get|can|check|from|set|block|unblock|avoid|link|clear} [arguments...]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path go", "path find", "event PathFind", "Move", "Tile"]
aliases: ["pathfinding", "route", "walk to", "go to"]
---

`path` plans a route from your character to a place anywhere on the facet, around walls, rivers and
buildings, over bridges, up and down stairs, and walks it. It reads the map from the client's own files, so
it knows the whole facet, not only what is on screen.

```euo
path go 1823 2821            ; from here to Trinsic, on foot
if #PathState <> arrived
  event SysMessage Did not get there: #PathState
```

To look at the route first, plan it with [`path find`](/commands/path/find/), then walk it:

```euo
path find 1823 2821
if #PathState <> ok
{
  event SysMessage No route: #PathState
  halt
}
for %i 1 #PathCnt
{
  path get %i
  ; #PathX #PathY #PathZ is where step %i ends, #PathDir its direction
}
path walk
```

## Sub-commands

| Command | What it does |
|---|---|
| [`path go`](/commands/path/go/) | Plans a route to a place and walks it. |
| [`path walk`](/commands/path/walk/) | Walks the route `path find` planned. |
| [`path step`](/commands/path/step/) | Moves a walk on and returns at once, so the script can do other things meanwhile. |
| [`path stop`](/commands/path/stop/) | Ends the walk `path step` is moving on. |
| [`path find`](/commands/path/find/) | Plans a route from your character (or from `path from`) to a place. |
| [`path get`](/commands/path/get/) | Loads one step of the route into `#PathX`, `#PathY`, `#PathZ`, `#PathDir`. |
| [`path can`](/commands/path/can/) | Says whether a character can stand at a place, and at what height. |
| [`path check`](/commands/path/check/) | Asks the client itself whether the character can take a step of the route, or onto a place. |
| [`path from`](/commands/path/from/) | Plans from another place instead of your character. |
| [`path set`](/commands/path/set/) | Changes an option: accuracy, search limits, how to walk, doors, creatures, … |
| [`path block`](/commands/path/block/) | Marks places the route must never use. |
| [`path unblock`](/commands/path/unblock/) | Removes blocked places. |
| [`path avoid`](/commands/path/avoid/) | Marks areas the route should go around if it can. |
| [`path link`](/commands/path/link/) | Adds a teleporter, gate or ladder the route may use. |
| [`path clear`](/commands/path/clear/) | Forgets blocks, avoid areas, links and the places where a step was refused. |

A `path` line never stops the script. [`#PathState`](/variables/pathstate/) says how the last `path`
command went: `ok` or `arrived`, or what went wrong.

## What the route knows about

The route is planned from the map designers' world: terrain and water, town buildings and walls, trees,
bridges, stairs and dungeons. The map files don't have the dynamic world: **player houses, items players
placed, open or closed doors, and creatures**. Your client only learns about those when they come within
about 18 tiles.

So `path` adds what your client holds around the character: items on the ground, doors, creatures, and the
walls and floors of player houses (on `client.exe` 7.0.117.1 and `client_beta.exe` 7.0.117.31, and on other
builds where EasyUO Reforged finds them). While walking, it also asks the client itself about the next 12
tiles of the route ([`path check`](/commands/path/check/)), which covers whatever is left: custom houses, or
a build where it can't read house pieces. A route is right everywhere about the map,
and right near the character about the rest. Farther away it can lead into a house or a crowd the client
hasn't shown yet; the walker sees those as it gets near, and goes round them (see
[How it walks](/commands/path/go/#how-it-walks)). Use [`path block`](/commands/path/block/) for places you
know about.

The options, blocks, avoid areas, links and the places where a step was refused last until the script is
started again.

## Reforged notes

`path` and the `#Path…` variables are new in EasyUO Reforged. [`event PathFind`](/commands/event/pathfind/),
[`Move`](/commands/move/) and [`Tile`](/commands/tile/) are unchanged; the walker uses `event PathFind` and the
walk and Open Door macros itself.

The step rules (how high a character can climb, how much head room it needs, how stairs and bridges work)
are those of the ClassicUO client.

Programs that drive the client through [`uo.dll`](/dll/) get the planning too: [`GetPath`](/dll/getpath/)
returns a whole route in one call, and `PathCan`, `PathCheck`, `PathSet`, `PathBlock`, `PathUnblock`,
`PathAvoid`, `PathLink` and `PathClear` match the sub-commands. There is no walker in `uo.dll`.

The first route on a facet loads that facet's map files, which takes a moment. Current clients ship
Felucca and Trammel as `.uop` files, which use about 90 MB of memory each once loaded. A long route takes
under a second: Britain to Minoc, about 1,500 steps, took 0.7 s on the developer's PC.
