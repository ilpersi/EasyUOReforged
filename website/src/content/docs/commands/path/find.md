---
title: "path Find"
description: "Plans a walking route from your character to a place on the same facet."
kind: subcommand
category: path
syntax: "path find {x} {y} [z]"
origin: reforged
needsClient: true
sets: ["#PathState", "#PathCnt", "#PathX", "#PathY", "#PathZ", "#PathDir"]
related: ["path get", "path walk", "path go", "path set", "path from", "event PathFind"]
aliases: ["pathfinding", "route"]
---

`path find` plans a route from your character to `x`, `y` on the facet you are on, and keeps it for
[`path get`](/commands/path/get/) and [`path walk`](/commands/path/walk/). The character does not move.

## Parameters

| Parameter | Meaning |
|---|---|
| `x`, `y` | World position, as in [`#CharPosX`](/variables/charposx/) and [`#CharPosY`](/variables/charposy/). |
| `z` | Optional height. Without it, any height at `x`, `y` will do. With it, the route ends within 5 of it (see `accuracyz` in [`path set`](/commands/path/set/)): use it to pick a floor of a building or a dungeon level. |

## Results

- **[`#PathState`](/variables/pathstate/)** is `ok` when a route was found. Otherwise:
  - `nopath`: there is no way there;
  - `budget` or `timeout`: the search gave up before finding one;
  - `stopped`: you pressed Stop;
  - `noclient`: no client is attached;
  - `nomap`: the client's folder lacks this facet's map files;
  - `error: …`: the arguments are wrong.
- **[`#PathCnt`](/variables/pathcnt/)** is the number of steps, 0 when there is no route or you are already
  there.
- **[`#PathX`](/variables/pathx/), [`#PathY`](/variables/pathy/), [`#PathZ`](/variables/pathz/)** are where
  the route ends, and [`#PathDir`](/variables/pathdir/) is the direction of its last step.

## Details

- The route starts where your character stands: [`#CharPosX`](/variables/charposx/),
  [`#CharPosY`](/variables/charposy/), [`#CharPosZ`](/variables/charposz/), on facet
  [`#CursKind`](/variables/curskind/). The way it faces doesn't matter. [`path from`](/commands/path/from/) starts it elsewhere.
- **Arriving.** The route ends exactly at `x`, `y`, unless `accuracy` is set ([`path set`](/commands/path/set/)).
  If nothing can stand there (a tree, a rock, a chest), the route ends next to it.
- **The shortest walk.** A diagonal step takes as long as a straight one, so the route is the one with the
  fewest steps, and it avoids needless changes of direction (each costs a little, see `turncost` in
  [`path set`](/commands/path/set/)).
- **The script waits** while the route is planned: up to 5 seconds, a fraction of a second for most routes.
  Stop interrupts it. A route that can't exist (an island, a closed room) answers `nopath` quickly as long
  as the goal is near, because the search only looks within 100 tiles around start and goal (`margin`).
- **Blocks, avoid areas and links** set with [`path block`](/commands/path/block/),
  [`path avoid`](/commands/path/avoid/) and [`path link`](/commands/path/link/) are used.
- The map is read from the client's files. On top of it, the route sees what your client holds around the
  character: items on the ground, doors, creatures and, on `client_beta.exe` 7.0.117.31, the pieces of
  player houses. Farther away, those are not on it. See
  [What the route knows about](/commands/path/#what-the-route-knows-about).
- Places where a walk had a step refused are avoided for a while (`blocktime` in
  [`path set`](/commands/path/set/)).
- A walk [`path step`](/commands/path/step/) is moving on ends.

## Example

Plan a route to the Britain bank and walk it:

```euo
path find 1434 1699
if #PathState <> ok
  halt
path walk
halt
```

[`path walk`](/commands/path/walk/) does all the work. By hand, a script can walk the route a stretch at a time
with the client's own pathfinder:

```euo
path find 1434 1699
if #PathState <> ok
  halt
set %i 0
while %i < #PathCnt
{
  set %i %i + 10
  if %i > #PathCnt
    set %i #PathCnt
  path get %i
  event PathFind #PathX #PathY #PathZ
  set %until #SCnt + 10
  while #CharPosX <> #PathX || #CharPosY <> #PathY
  {
    if #SCnt > %until
      halt
    wait 5
  }
}
halt
```
