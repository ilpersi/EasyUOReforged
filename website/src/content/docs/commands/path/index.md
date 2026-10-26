---
title: "Path"
description: "Plans a walking route across the map, around walls, water and buildings, with stairs and bridges."
kind: command
category: path
syntax: "path {find|get|can|from|set|block|unblock|avoid|link|clear} [arguments...]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path find", "event PathFind", "Move", "Tile"]
aliases: ["pathfinding", "route", "walk to", "go to"]
---

`path` plans a route from your character to a place anywhere on the facet: around walls, rivers and
buildings, over bridges, up and down stairs. It reads the map from the client's own files, so it knows the
whole facet, not only what is on screen.

```euo
path find 1823 2821          ; from here to Trinsic
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
```

`path` plans the route but does not walk it yet. To walk it, a script can feed points along the route to
[`event PathFind`](/commands/event/pathfind/), which walks a short distance and handles what is in the way.

## Sub-commands

| Command | What it does |
|---|---|
| [`path find`](/commands/path/find/) | Plans a route from your character (or from `path from`) to a place. |
| [`path get`](/commands/path/get/) | Loads one step of the route into `#PathX`, `#PathY`, `#PathZ`, `#PathDir`. |
| [`path can`](/commands/path/can/) | Says whether a character can stand at a place, and at what height. |
| [`path from`](/commands/path/from/) | Plans from another place instead of your character. |
| [`path set`](/commands/path/set/) | Changes an option: accuracy, search limits, turn cost, … |
| [`path block`](/commands/path/block/) | Marks places the route must never use. |
| [`path unblock`](/commands/path/unblock/) | Removes blocked places. |
| [`path avoid`](/commands/path/avoid/) | Marks areas the route should go around if it can. |
| [`path link`](/commands/path/link/) | Adds a teleporter, gate or ladder the route may use. |
| [`path clear`](/commands/path/clear/) | Forgets blocks, avoid areas and links. |

A `path` line never stops the script. [`#PathState`](/variables/pathstate/) says how the last `path`
command went: `ok`, or what went wrong.

## What the route knows about

The route is planned from the map designers' world: terrain and water, town buildings and walls, trees,
bridges, stairs and dungeons. The map files don't have the dynamic world: **player houses, items players
placed, open or closed doors, and creatures**. Your client only learns about those when they come within
about 18 tiles. A route can therefore lead into a house or a crowd that is not on the map; use
[`path block`](/commands/path/block/) for places you know about.

The options, blocks, avoid areas and links last until the script is started again.

## Reforged notes

`path` and the `#Path…` variables are new in EasyUO Reforged. [`event PathFind`](/commands/event/pathfind/),
[`Move`](/commands/move/) and [`Tile`](/commands/tile/) are unchanged.

The step rules (how high a character can climb, how much head room it needs, how stairs and bridges work)
are those of the ClassicUO client.

The first route on a facet loads that facet's map files, which takes a moment. Current clients ship
Felucca and Trammel as `.uop` files, which use about 90 MB of memory each once loaded. A long route takes
under a second: Britain to Minoc, about 1,500 steps, took 0.7 s on the developer's PC.
