---
title: FindItem
description: "Finds items and characters by type or ID and fills the #Find… variables with the first match."
kind: command
category: client
syntax: finditem {type|id}[_{type|id}...] [index] [G|G_{range}|C|C_{container}|A|CA_{container}]
needsClient: true
sets: ['#FindID', '#FindType', '#FindX', '#FindY', '#FindZ', '#FindDist', '#FindKind', '#FindStack', '#FindBagID', '#FindRep', '#FindCol', '#FindIndex', '#FindCnt']
related: ['IgnoreItem', '#FindIndex', '#FindMod', 'event Drag', 'dll:ScanItems']
dll: ScanItems
aliases: ['find item', 'search item', 'scan items', 'find object']
source: wiki
---

`FindItem` takes a snapshot of the objects the client knows about (items and characters, on the
ground and in open containers), keeps the ones that match, and selects one of them. The selected
object's details go into the [`#Find…` variables](/variables/?category=finditem);
`#FindCnt` says how many objects matched.

## Parameters

| Parameter | Meaning |
|---|---|
| `type` / `id` | What to look for. A **type** is 2–3 letters (`POF` is gold), an **ID** is 6–8 letters (`YKLMNOP`). Join several with `_` (`NSF_FSF`): each one matches either as a type or as an ID. Use `*` to match every object. |
| `index` | Optional. Which match to select, counting from 1. Default: 1. |
| filter | Optional, always the last parameter. Limits where to look. See the table below. |

| Filter | Keeps only |
|---|---|
| `G` | Objects on the ground. |
| `G_{range}` | Objects on the ground at most `range` tiles away. |
| `C` | Objects inside containers. The container must be open. |
| `C_{container}` | Objects inside the container with that ID. The container must be open. |
| `A` | Adds objects the client still keeps in memory but doesn't show. See [Hidden objects](#hidden-objects). |
| `CA_{container}` | Like `C_{container}`, including objects the client doesn't show. |

## Reading the results

- **Found:** `#FindCnt` is the number of matches and the `#Find…` variables describe the
  selected one: `#FindID`, `#FindType`, position (`#FindX`, `#FindY`, `#FindZ`, `#FindDist`),
  `#FindKind` (0 = in a container, 1 = on the ground), `#FindStack`, `#FindBagID`, `#FindRep` and
  `#FindCol`.
- **Not found:** `#FindCnt` is `0`, `#FindKind` is `-1`, and `#FindID` and `#FindType` read `X`.
  Test `#FindCnt` or `#FindKind`, not `#FindID`.
- **The other matches:** set [`#FindIndex`](/variables/findindex/) to 2, 3, … `#FindCnt` to
  select them one after the other. This reuses the snapshot, so it is much faster than calling
  `FindItem` again.

The snapshot is taken when `FindItem` runs. If an object moves or disappears afterwards, the
variables keep showing what it was at that moment until the next `FindItem`.

## Examples

Pick up a dagger lying within 2 tiles and drop it at a screen position:

```euo
finditem TSF G_2
if #FindCnt > 0
{
  event Drag #FindID
  wait 20
  click 200 300 p
}
halt
```

Move a stack of black pearl out of a known bag. The comma glues `C_` and the bag ID into a single
`C_ABCDEFG` parameter:

```euo
set %regbag ABCDEFG          ; your reagent bag's ID
finditem KUF C_ , %regbag
if #FindCnt > 0
{
  event Drag #FindID
  wait 20
  click 200 300 p
}
halt
```

Count the gold stacks in the backpack and list each one:

```euo
finditem POF C_ , #BackpackID
for %i 1 #FindCnt
{
  set #FindIndex %i
  display ok Stack %i : #FindStack gold
}
halt
```

## Notes

### Hidden objects

By default `FindItem` skips objects the client keeps in memory but doesn't draw. For example, an
item dropped into a closed bag in the bank box can still be "found" until the bank box closes,
which used to make scripts drag items that weren't on screen. The `A` filter (for *all*) includes
them, which also finds the equipment, clothing and backpacks of other characters. Cheffe's own
advice from when he added it still applies: **only use `A` when you really need it.**

### Items and characters

`#FindStack` is `0` for characters (mobiles), so it is a quick way to tell them apart from items.
