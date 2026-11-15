---
title: "MoveItem"
description: "Moves an item, or part of a stack, into a container and reports in #MoveRes whether it arrived."
kind: command
category: client
syntax: "moveitem {id} {destination} [amount] [x y]"
needsClient: true
origin: reforged
sets: ['#MoveRes']
related: ["exevent Drag", "exevent DropC", "FindItem", "#MoveRes", "#BackpackID"]
aliases: ["move item", "drag and drop", "put in container", "verified move", "move stack"]
---

`moveitem` does a whole drag and drop in one line: it picks the item up, drops it into the destination, waits
for each step, tries again when that is safe, and says in [`#MoveRes`](/variables/moveres/) what happened. It
replaces the `exevent drag`, `wait`, `exevent dropc`, check-and-retry subs that scripts write by hand.

```euo
set %bag ABCDEFG                     ; the ID of a bag in your backpack
finditem POF C_ , #BackpackID        ; gold
if #FindCnt > 0
{
  moveitem #FindID %bag
  if #MoveRes <> ok
    display ok The gold did not arrive: #MoveRes
}
halt
```

## Parameters

| Parameter | Meaning |
|---|---|
| `id` | The item. The client has to know it: on screen, or in a container it has seen. |
| `destination` | The container to put it in (your [`#BackpackID`](/variables/backpackid/), a bag, a chest you opened, your bank box), or a pile of the same kind to add it to. A mobile works too (see `left` below). |
| `amount` | Optional. How many to move from a stack, or `all`. **Default: the whole stack**, unlike [`exevent Drag`](/commands/exevent/drag/), whose default is 1. More than the stack holds moves the whole stack. |
| `x`, `y` | Optional, only after an amount. Where to put it inside the container, from its top-left corner. With a place, it never joins a pile there. |

```euo
set %bag ABCDEFG
finditem ZLK C_ , #BackpackID        ; logs
if #FindCnt > 0
  moveitem #FindID %bag 10 40 40     ; 10 logs, to their own pile at 40,40
halt
```

## Results

[`#MoveRes`](/variables/moveres/) is one of these words:

| `#MoveRes` | What happened | Where the item is |
|---|---|---|
| `ok` | The item is in the destination: its ID is in it, or a pile of its kind there grew by the amount (it joined that pile, so its own ID is gone). | In the destination. |
| `left` | It was picked up and dropped, but the client can't see it in the destination. Usually a container outside your backpack that you haven't opened. Also after a drop onto a mobile that took it, or when the server used it up. | Unknown to the client. |
| `refused` | It was picked up, but the server refused every drop: a full or locked container, too far away, not a container. | Where the server put it back: where it was, or at your feet if that place was gone. |
| `nolift` | The server never let it be picked up: too far away, not movable, locked down, not yours, or you moved items too fast every time. | Where it was. |
| `noitem` | The client doesn't know the item. Nothing was sent. | - |
| `nodest` | The client doesn't know the destination. Nothing was sent. | - |
| `held` | Something hangs on the cursor. Nothing was sent. | - |
| `error` | A parameter is missing or wrong: no destination, an amount that is 0 or not a number, `x` without `y`. Nothing was sent. | - |

Nothing is ever left on the cursor: `moveitem` moves items through the server, the way
[`exevent Drag`](/commands/exevent/drag/) does, and the cursor never holds them.

## How it checks

`moveitem` watches the client's list of items. It never reads the journal, so it works the same whatever the
client's language and whatever the shard's messages say.

- **Picked up**: the item leaves the client's list. When the server refuses, it stays.
- **Arrived**: its ID turns up in the destination, or a pile of its kind there grows by the amount.
- **Refused**: its ID turns up again somewhere else.

When the server doesn't let it pick the item up, it tries again, at least 0.65 seconds later, because servers
refuse item moves that come too fast after each other. When the server refuses the drop, it starts over. It
picks up 3 times at most. A move that works takes a fraction of a second. One that keeps failing gives up
within about 4 seconds, and never takes more than about 8.

It drops only after it has seen the item picked up. The server drops whatever you are holding, so a drop sent
after a refused pick-up could move another item.

## What the client can see

The client is told what goes into a container only when it may look inside:

- **Your backpack, every bag in it, and your bank box**: always, even a bag you never opened.
- **Any other container** (a chest on the floor, in a house, a pack animal): only after you have opened it, as
  long as you stay near it. Open it first, or `moveitem` gives `left` even when the move worked.

## Pause, Stop and stepping

- **Pause** holds the move between two checks, and the time paused doesn't count. If the server took the item
  meanwhile, it is dropped on resuming.
- **Stop** ends the move and leaves `#MoveRes` as it was. If the item has already been picked up, it is still
  dropped first, so it isn't left in the air.
- **Step Into** and **Step Over** treat the whole move as one step.

## Notes

- `ok` after joining a pile means that a pile of that kind in the destination grew by the amount. If something
  else of the same kind arrives there at the same moment, that counts too.
- Moving an item to another place in the same container reads `ok` whether it moved or not.
- On ModernUO, whatever you put into a **locked-down container** in a house is locked down with it. Taking it out
  again gives `nolift` until it is released (say *I wish to release this* and target it).
- The ground and the paperdoll are not destinations: use [`exevent DropG`](/commands/exevent/dropg/) and
  [`exevent Equip`](/commands/exevent/equip/) for those. `moveitem` never puts anything on the ground itself; only
  the server does, when it bounces an item whose container is gone.
- `moveitem` doesn't change [`#FindID`](/variables/findid/) or any other result of [`finditem`](/commands/finditem/).

## Reforged notes

`moveitem` and `#MoveRes` are new in EasyUO Reforged. No existing command changes because of them, and a sub or
label called `moveitem` keeps working. It's the only change for old scripts: a line starting with the word
`moveitem` used to be ignored and is now this command.

It was checked on a ModernUO shard with `client.exe` 7.0.118.46. Other servers that give the picked-up part of a
stack a new ID can report `left` where the drop was refused.

`uo.dll` has no equivalent. A program using it calls `Drag` and `DropC` and checks the items itself.
