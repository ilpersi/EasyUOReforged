# Pathfinding: design

A design for long-distance pathfinding in EasyUO Reforged, written for discussion before and while it is
built. It is a proposal: names and defaults may change. Built so far: phase 1 (see [Phases](#phases)); the
script reference is the [`path` command](https://ilpersi.github.io/EasyUOReforged/commands/path/).

## The problem

A script has three ways to move the character today, and none of them gets it across a town:

| Tool | What it does | Limit |
|---|---|---|
| `event PathFind x y [z]` | Asks the client's own pathfinder to walk there. | About one screen. Does not wait, and fails silently. |
| `move x y [acc] [timeout]` | Presses the arrow keys in a straight line. | No pathfinding: a wall stops it. |
| `tile init/cnt/get` | Reads map, statics and tiledata from the client's files, one tile at a time. | Only data, no route. Slow for a search: a file seek per call, no cache. |

### What EasyUO can and cannot see

- **Known everywhere, from the files:** the terrain (`mapN`) and the *statics* (`staticsN.mul`). Statics are what
  the map designers placed: town buildings, walls, trees, bridges, dungeon stairs. EasyUO already reads them.
- **Known only near the player, from the server:** the *dynamic* world. That covers player houses (multis,
  including custom-house designs, which arrive by packet), items players placed, whether a door is open, and
  mobiles. The server sends these only within about 18 tiles. The client then keeps them in its object list,
  which EasyUO already reads (that is how `FindItem` works).

So a route planned from the files alone is right about the terrain and the designers' world everywhere, and
wrong only where the dynamic world gets in the way. Those places are near the player by the time they matter.

### Prior art

- **TazUO** (a ClassicUO fork, BSD-2-Clause) has two pathfinders. A short-range A* runs over the live client
  world with the real step rules. A long-range weighted A* runs over the map and statics files in 8×8 chunks. It
  adds house footprints, plus "dynamic blocks": cells where a step was refused, so the next search avoids them.
- **Stealth** (closed source) publishes its API. `GetPathArray3D` returns a 3D path with an XY and a Z accuracy.
  `IsWorldCellPassable` checks one step and returns the Z there. `MoveXYZ` walks, with movement options: open
  doors, walk through NPCs, corner rules, heuristic multiplier, turn cost.

## The idea: plan globally from the files, correct locally from the client

Three layers of knowledge are merged into one "what is at this cell" view:

1. **Static world (files):** terrain and statics, known everywhere, all the time.
2. **Live overlay:** what the client sees now. Ground items, multis and mobiles come from the client's object
   list. Later, possibly the client's own walkability answer (see [BlockInfo](#blockinfo-the-clients-own-answer)).
3. **Memory:**
   - blocks learned from refused steps, which expire;
   - the script's own rules: blocked cells, areas to avoid, and links for teleporters, gates and ladders.

A planner searches that view with the server's step rules. A walker follows the path, and replans from where
the character is whenever layer 2 or 3 changes ahead of it.

## Parts

### World model (`uo/walkmap.pas`)

- It is its own reader, so the `tile` command does not change. It reads maps from `.mul` or from UOP, plus
  `staidxN`/`staticsN`, the dif files when present, and full tiledata records, including the 64-bit flags and
  the `height` field that `tile` never reads.
- It reads three things correctly that `tile` currently gets wrong:
  - Trammel reads its own `map1`/`statics1`.
  - Felucca and Trammel are 7168 tiles wide on current clients.
  - Ter Mur blocks are 512 tiles high.
- Each 8×8 block is decoded once and cached. A cell holds the land tile (its height and the average height of
  its corners) and the objects standing on it (height, top and flags).

### Step rules (`uo/walkrules.pas`)

- The rules for "can I step from here to there, and at what height do I land" are ported from ClassicUO's
  `Pathfinder.cs`. ClassicUO is BSD-2-Clause, the same licence as EasyUO Reforged.
- The rules cover:
  - surfaces, bridges and stairs, and the climb limit;
  - head room (a character is 16 high);
  - impassable objects, and water;
  - diagonal steps, which need both neighbouring straight steps to be open.
- ServUO and RunUO are GPL and are used as a reference only.

### Planner (`uo/pathplan.pas`)

- A* over `(x, y, z)` positions in 8 directions, so bridges, two-storey buildings and dungeon levels work.
- **Costs count steps, not distance.** In UO a diagonal step takes as long as a straight one, so both cost the
  same. Turning costs a little extra, since a direction change is a move request of its own. That keeps paths
  straight and less bot-like.
- **Goal:** arrive within an XY and a Z accuracy. If the goal cell itself cannot be stood on, the nearest cell
  that can is used instead.
- **Budgets:** a node budget, a time budget and a search box around start and goal. With them, "there is no
  path" (an island, a closed area) answers fast instead of searching a whole facet.
- **Stop:** the script's Stop button interrupts a search.
- **Exact by default.** On the real Felucca map, Britain to Trinsic (1,214 steps) took 260k nodes and about
  0.5 s, and Britain to Minoc (1,480 steps) took 450k nodes and 0.8 s. A weighted search (heuristic 120)
  roughly halved the nodes, but the routes were about 4% longer with twice the turns. So the default is the
  exact search, with TazUO's budgets: 1,000,000 nodes and 5 s. A faster long-range search is a phase 4
  question.

### Walker (phase 2)

Two ways to drive the character:

- **`client` mode** (the default where the client's pathfinder address is known):
  - Our path supplies the long route.
  - The client's own `PathFind` walks to a point about 12 tiles ahead on it, with the exact Z, and handles every
    live obstacle exactly.
  - The next point is sent before the character arrives, so walking doesn't stop.
- **`steps` mode:** one step at a time with the walk macro. Each step counts as refused when the position doesn't
  change in time.

The walker replans from the current position in three cases:

- when a step is refused (that cell becomes a learned block);
- when something new appears on the next few cells of the path;
- when the character ends up off the path.

Doors cost a little more than open ground, and the walker opens them with the open-door macro.

### Live overlay (phase 2)

- **Ground items:** their height and flags come from tiledata, by type.
- **Mobiles:** they block, unless the script says to ignore them.
- **Classic multis** (boats, tents, classic houses): components come from `MultiCollection.uop` / `multi.mul`.
- **Custom houses:** their design comes by packet, not from the files, so their footprint is treated as blocked
  at ground level, unless the start or the goal is inside. Inside a house, the client's own `PathFind` takes
  over.

### BlockInfo: the client's own answer

EasyUO has always had `BlockInfo` (in `uo.dll` only). It calls the client's own walkability check for up to
32×32 tiles at once, but its 2-byte-per-tile result has never been decoded. If it turns out to mean "you can
stand here at height z" or "blocked", it becomes the most precise overlay possible, for everything the client
has loaded, custom houses included. Decoding it needs testing on a live client: a wall, a door, water, stairs,
a house.

## Script commands

`path` is a new command; nothing about `event PathFind`, `move` or `tile` changes.

| Form | Effect | Phase |
|---|---|---|
| `path find {x} {y} [z]` | Plan from the character's position, on its facet. `#PathCnt` steps, 0 = no path. `#PathState` says why. | 1 |
| `path get {n}` | Step n into `#PathX`, `#PathY`, `#PathZ`, `#PathDir`. | 1 |
| `path can {x} {y} [z]` | Can the character stand there, and at what height (`#PathZ`)? | 1 |
| `path from {x} {y} {z} [facet]` | Plan from there instead of the character (`path from` alone: back to the character). | 1 |
| `path set {option} {value}` | Accuracy, budgets, turn cost, heuristic weight, doors, mobiles, walker mode. | 1 |
| `path block` / `path unblock` | Cells or rectangles the planner must never use. | 1 |
| `path avoid {x} {y} {x2} {y2} {cost}` | Areas it should go around if it can: guard zones, spawns. | 1 |
| `path link {x} {y} {z} {x2} {y2} {z2} [cost]` | A teleporter, gate or ladder, same facet. | 1 |
| `path clear [what]` | Forget rules. | 1 |
| `path go {x} {y} [z] [accuracy] [timeout]` | Plan and walk, waiting until done, like `move`. | 2 |
| `path walk` / `path step` / `path stop` | Walk the last plan. `path step` advances without waiting, so the script can heal or read the journal between steps. | 2 |

Example (phase 1, planning only):

```euo
path find 1434 1699
if #PathCnt = 0
{
  event sysmessage no path: #PathState
  halt
}
for %n 1 #PathCnt
{
  path get %n
  event sysmessage %n : #PathX #PathY #PathZ
}
```

## Phases

| Phase | Content | Checked by |
|---|---|---|
| 1 | World model, step rules, planner; `path find/get/can/set/block/unblock/avoid/link/clear` | unit tests and the real client files |
| 2 | Walker (`client` and `steps` modes), live overlay, learned blocks, doors; `path go/walk/step/stop` | a live client |
| 3 | Decode `BlockInfo`, and use it as the local overlay | a live client |
| 4 | `uo.dll` access, links between facets, a faster long-range search if measurements need one | tests and a live client |

## Open questions

- How does a multi appear in the client's object list, and can a custom house's design be read from memory?
- What does `BlockInfo`'s 2-byte result mean?
- How far does the client's own `PathFind` really reach on each client version? That sets the walker's
  look-ahead.
- Which shard-specific links (teleporters, moongates) are worth shipping as ready-made lists, if any?
