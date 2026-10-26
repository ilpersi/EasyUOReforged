# Pathfinding: design

A design for long-distance pathfinding in EasyUO Reforged, written for discussion before and while it is
built. It is a proposal: names and defaults may change. Built so far: phases 1 and 2 (see [Phases](#phases));
the script reference is the [`path` command](https://ilpersi.github.io/EasyUOReforged/commands/path/).

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
- **Checked in the editor on a live client:** `path can` gave the same height as `#CharPosZ`, and a route from
  east of Minoc to Britain's bank (1,725 steps) took 273 ms.

### Walker (phase 2)

Two ways to drive the character:

- **`client` mode** (planned as the default where the client's pathfinder address is known; as built,
  `steps` is the default, see "As built" below):
  - Our path supplies the long route.
  - The client's own `PathFind` walks to a point ahead on it, with the exact Z, and handles every live obstacle
    exactly.
  - How far ahead the client accepts is not a fixed distance (see
    [The client's own pathfinder](#the-clients-own-pathfinder)). The walker keeps its points within 18 tiles of
    the character. It can run the client's search on our own map first, to pick the farthest point the client
    should accept. It moves the point nearer along our path each time the client answers "Can't get there"; if
    even a near point is refused, that stretch is walked in `steps` mode.
  - The next point is sent before the character arrives, so walking doesn't stop.
- **`steps` mode:** one step at a time with the walk macro. Each step counts as refused when the position doesn't
  change in time.

The walker replans from the current position in three cases:

- when a step is refused (that cell becomes a learned block);
- when something new appears on the next few cells of the path;
- when the character ends up off the path.

Doors cost a little more than open ground, and the walker opens them with the open-door macro.

**As built** (`uo/pathwalk.pas`; the defaults are in `TPathWalker.ResetOptions`):

- **`steps` is the default** (`path set mode auto`), chosen with the user on 2026-10-26 after the live tests
  on the beta: the client's own pathfinder kept ending its walks, taking its own way and being corrected
  by the server (and once left `#CharPosX` 3 tiles off until the next login), while single steps never went
  wrong. On open ground client mode took 0.30 s a tile, steps 0.37 s with a 0.3 s gap between steps; the
  character moves about 0.22 s after a step, so the gap is now 0.2 s. `client` mode stays available.
- **Checked on the beta** (2026-10-26, near Minoc, one test at a time with the user): 22 tiles on open ground
  in 5.4 s; round a row of player houses both ways (35 to 39 steps); `path step`, `path stop` and
  `path walk` picking the route up again at the character's step; a 273-step route to 2500,560 in 68.8 s
  (0.25 s a step) with no refusal, replan or put-back. Its only resends came at the 24 turns, where the
  first walk macro only turns the character.
- **Minoc to the Britain bank** (2500,560 to 1434,1699, a 1,476-step route): 1,488 moves in 6 min 11 s,
  arriving exactly. 24 short replans and no full one: 13 for creatures stepping onto the next steps, 9 after
  ending a tile off the route, 2 after a refused step. No put-back. The longest pauses were 2.2 s, at the
  two refused steps; every other one was under 0.85 s.
- **Routes are planned without the character's facing** (walker and `path find`): with it, a first step the
  way the character faced saved a turn, and a character facing south-east planned 11 + 11 diagonal steps
  instead of 22 east, an equally short V.

- `ClientSearch` is the client's search as read from its code. A waypoint goes out only when it accepts it at
  the exact tile. Waypoints stay within `lead` (18) tiles of the character, at most a lead of route steps
  ahead (36 at first), and stop before a door or a link.
- A refusal is "Can't get there" in the journal since the waypoint was sent. Each one halves the lead; below 3
  steps the next 18 steps are walked in `steps` mode. Each waypoint reached adds 4 back.
- A waypoint the client takes without a word but doesn't start walking to within 1 s: the next 18 steps are
  walked in `steps` mode at once. Seen on the beta after its own position globals (0xB296D4..DC) had drifted
  3 tiles west of the character object, after a stalled `event PathFind`: its pathfinder then plans from
  the wrong tile, and next to the goal it doesn't move at all. The walk macro is not affected.
- **The beta's own walk ends after a handful of steps**, 4 to 7 far from its target and 1 or 2 near it,
  however often it is sent again: seen with a plain `event PathFind` and with the walker (2026-10-26, near
  Minoc). A new `PathFind` sent while the character walks doesn't make it pause. So a fresh waypoint goes
  out every 3 steps walked (`KeepAliveSteps`), and 3 steps before the waypoint.
- A walk that stood still for 0.5 s short of the waypoint is not a refusal. Within 4 steps of the waypoint
  (`EndSteps`) the walker takes those steps with the walk macro; farther away, the next waypoint goes out
  from there, with the same lead. Only a refused step makes a cell a learned block. Learning the waypoint's
  cell when the client stopped next to it, as first built, marked tiles that were free.
- With these, a 22-tile walk on the beta (2701,513 to 2723,513) took 7.9 s with 3 short stops in its last 4
  tiles, before the `EndSteps` rule.
- In `steps` mode steps go out 0.3 s apart at least, since the client may drop a request that comes during a
  step. A step not taken is sent again after 0.5 s (after 0.3 s when it only turned the character), and is
  refused after 1.5 s without movement.
- The overlay is read again every second. After each read, the next 16 steps are checked with the step rules.
- A replan first searches from the character back to the route 12 steps past the trouble (30,000 nodes, a
  margin of 36), and splices that in. If that fails, it plans the whole way again.
- Learned blocks last 60 s, are per facet, and cover the whole cell at every height. The character's own cell
  is never one.
- A walk fails after 15 s without movement, or after 8 replans in a row without movement.
- A link step: the walker stands on its start for 3 s. A teleporter moves it on; anything else ends the walk
  with `link`.
- Doors: face the door (a step toward a shut door only turns), the open-door macro, 0.8 s, read the overlay
  again. Two tries, then the cell is learned. Checked live on the beta: macro 12 opened a house's front door
  and an inner door.
- House doors (a door on a cell that also holds a house piece) count as walls unless `path set doors all`.
  With them open, a route near Minoc went in through a house's front door and out its far side, and the
  server refused a tile there (2699,500) that the client showed as free: the client put the character
  back on every try, and the walker resent its waypoint forever.
- A tile the character is put back off twice (back on the tile it just left, within 1.5 s) becomes a learned
  block. A walk that hasn't got closer to the goal for 30 s (`ProgressMs`) fails, whatever it was doing.
- When the client's walk ends off the route, the walker replans and walks the next 18 steps in `steps` mode.
  Along the front of the row of houses near Minoc (y 510), the client's own way kept being corrected by
  the server: positions jumped 2 or 3 tiles, sometimes backwards. Walking round the houses to 2688,488
  (39 steps) took 25 s before this rule; the stretch walked in steps went at 0.35 s a step.
- The client doesn't know the learned blocks, so a waypoint goes out only when the emulated client search,
  run without them, reaches it by a way that crosses none. Otherwise the walker's own route goes round a
  learned tile while the client, sent ahead, walks straight back onto it (the simulated walk did exactly
  that until this rule). Put back off a tile already learned: the next 18 steps go in `steps` mode.
- All waits are the interpreter's `Delay`, so Stop and Pause work. A replan's search releases the
  interpreter's lock, as `path find` does.
- `tests/PathWalkTests.pas` walks it against a simulated client that walks a "true" world the walker only
  partly sees.

### Live overlay (phase 2)

- **Ground items:** their height and flags come from tiledata, by type.
- **Mobiles:** they block, unless the script says to ignore them.
- **Classic multis** (boats, tents, classic houses): components come from `MultiCollection.uop` / `multi.mul`.
- **Custom houses:** their design comes by packet, not from the files, so their footprint is treated as blocked
  at ground level, unless the start or the goal is inside. Inside a house, the client's own `PathFind` takes
  over.

**As built** (`uo/walklive.pas`, read by `TUOCmd.PathLiveObjects`):

- Ground items and mobiles come from the item list `FindItem` walks (from `C_CHARPTR`), on every supported
  client. A serial with bit `$40000000` is an item, any other is a mobile; that is the protocol's split. Only
  objects with kind 1 (on the ground) count. Read live on the beta: mobiles and items share that list, with
  different vtables.
- House pieces come from the client's multi list: on `client_beta.exe` 7.0.117.31 (stamp `$6AD6CEB3`) a linked
  list from `[0xB5B70C]`, next at +0x9C, X/Y/Z at +0x48, graphic at +0x70. It holds the pieces of every house
  the client has drawn (about 3,400 near Minoc). This is a small table keyed by PE stamp in `uocommands.pas`
  (`MultiLists`), not a `TCstDB` field. Where it is on `client.exe` is still open.
- Classic multis are not read from `multi.mul`: on the beta they sit in the same list, and on `client.exe` the
  walker learns them from refused steps.
- Items and house pieces are statics as far as the step rules go: tiledata flags and height by graphic, at
  their own height. A mobile is an obstacle 16 high, as in ClassicUO. Doors (the tiledata Door flag) are left
  out when the walker opens doors, and cost `doorcost` (50) more.
- Objects are kept within 40 tiles of the character. `path find` and `path can` use the overlay too, filled at
  the moment they run.

### BlockInfo: the client's own answer

EasyUO has always had `BlockInfo` (in `uo.dll` only). It calls the client's own walkability check for up to
32×32 tiles at once, but its 2-byte-per-tile result has never been decoded. If it turns out to mean "you can
stand here at height z" or "blocked", it becomes the most precise overlay possible, for everything the client
has loaded, custom houses included. Decoding it needs testing on a live client: a wall, a door, water, stairs,
a house.

### The client's own pathfinder

Read from the code of `client.exe` 7.0.117.1 and `client_beta.exe` 7.0.117.31; the search is the same in both.

- **The call.** `event PathFind` enters the client's walk-to function. It plans from the character's position,
  plus any steps still queued. It searches once for the exact tile, then once more allowing one tile off. When
  both fail it prints "Can't get there".
- **The search.**
  - It is an A* where every step costs 1, diagonals included.
  - Its estimate of the distance left is the straight-line distance in 3D, so each unit of Z counts as a tile.
  - It gives up after expanding 500 positions per attempt; the hard cap is 5,000.
  - It accepts arrival within ±8 of the goal's Z.
  - A diagonal step needs both neighbouring straight steps open, the same rule as ours.
- **It only sees what the client has loaded.** Each cell comes from the client's in-memory world. A cell with
  nothing loaded has no ground, so the search treats it as blocked. There is no other check on the distance from
  the character.
  - `client.exe` keeps a 7×7-block area (56×56 tiles), placed from the view range (18 by default). It reaches
    at least 18 tiles west and north of the character, and at least 30 east and south.
  - `client_beta.exe` uses a new block manager by default. It loads the blocks the game window shows through a
    per-frame budget, and evicts blocks beyond a radius computed from the screen size. What is loaded at a given
    moment depends on the window and on timing.
  - Measured by reading memory with the character standing at 2713,523: `client.exe` had 18 tiles loaded
    to the west, 20 north and 30 or more east and south. The beta had between 20 and 30 tiles in every direction.
- **The budget is rarely the limit.** We ran the same search on our own map model:
  - The refused case near Minoc (12 steps ahead) needed only 13 positions.
  - On three long routes, points 30 to 40 steps ahead were accepted 97 to 100% of the time.
  - So the 500 run out only when the straight line toward the goal meets a wide obstacle.
- **What the refusals near Minoc really were:** a player house that our map can't see stood across our route
  (see [Open questions](#open-questions)).

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
| 5 | House pieces from the client table: a `TCstDB` field for the client's list of drawn house pieces (its head global, plus the next/position/graphic offsets), found by a runtime signature pattern in `ScannerTable_Modern`, in place of the one-build `MultiLists` table in `uo/uocommands.pas`; and where `client.exe` keeps its house pieces, added the same way | `CstDbModernBuildTests`, and the live overlay test (`TestPathLiveObjectsSeeTheCharacter`) on each client |

## Open questions

- How does a multi appear in the client's object list, and can a custom house's design be read from memory?
  On the beta, yes: while the house is drawn, each of its pieces is an object in the client's multi list (and in
  its old dynamic-item grid), with its position, height and graphic. The walker reads that list. Not yet checked
  on `client.exe`.
- Does `event PathFind` to the character's own tile stop a walk the client is doing? `path stop` would need it.
- What does `BlockInfo`'s 2-byte result mean?
- How far does the client's own `PathFind` really reach on each client version? That sets the walker's
  look-ahead. Measured by hand on a live client near Minoc, with points taken from our planned route:
  - 8 steps ahead was accepted and walked exactly, height included;
  - 12 steps ahead was refused with "Can't get there";
  - the cut-off was different at every spot tried, so it depends on the start, the goal and what lies between;
  - the beta client refused more often than the standard client.

  Reading the clients' code explained the mechanism (see
  [The client's own pathfinder](#the-clients-own-pathfinder)): a 500-position budget, and only cells the client
  has loaded.

  The refusal itself was the world, not a limit:
  - A player house covers 2693–2723, 495–509, and our route from 2707,517 ran into it from step 8 onwards. Our
    map has no houses.
  - The beta holds the house's pieces (about 2,200 walls and floors) only while the house is drawn. From
    2713,523 it had none; from 2709,513 it had them all.
  - With those pieces added, the emulated client search gives the result seen in the game:
    - step 8 is reached one tile off (the exact tile is part of the house);
    - steps 9 to 13 are unreachable even with the 5,000-position cap;
    - step 14 is reachable again, around the house.
  - Our planner, given the same pieces, goes round the house for 4 extra steps.
- Which shard-specific links (teleporters, moongates) are worth shipping as ready-made lists, if any?
- Where does `client.exe` keep the pieces of the houses it draws, and can the beta's list (`[0xB5B70C]`,
  next +0x9C) be found by a signature, so a new beta build gets it without a hand-made entry? Phase 5.