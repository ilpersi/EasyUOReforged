---
title: "#FindLayer"
description: "Layer a character wears the object FindItem selected in, or N/A when nobody wears it."
kind: variable
category: finditem
access: ro
type: number
origin: reforged
needsClient: true
related: ["FindItem", "#FindBagID", "#FindKind", "#MountID", "dll:GetItem"]
aliases: ["layer", "equip layer", "worn", "equipped", "paperdoll"]
---

`#FindLayer` is the layer, in decimal, in which a character wears the object
[`FindItem`](/commands/finditem/) selected at the current [`#FindIndex`](/variables/findindex/).
[`#FindBagID`](/variables/findbagid/) is then the ID of the character wearing it.

It reads `N/A` when the object isn't worn (it lies in a container or on the ground), when nothing was
found, and without a client. FindItem finds worn objects by the same rules as objects in containers: other
characters' equipment, for one, only with its `A` filter (see FindItem's notes).

## Layers

The shard decides which layer an object goes in, by the same numbers on every shard:

| Layer | Slot | Layer | Slot |
|---|---|---|---|
| 1 | one-handed weapon | 16 | facial hair |
| 2 | two-handed weapon or shield | 17 | middle torso (tunic, surcoat, sash) |
| 3 | shoes | 18 | earrings |
| 4 | pants | 19 | arms |
| 5 | shirt | 20 | cloak |
| 6 | helm or hat | 21 | backpack |
| 7 | gloves | 22 | outer torso (robe) |
| 8 | ring | 23 | outer legs (skirt, kilt) |
| 9 | talisman | 24 | inner legs (leg armour) |
| 10 | necklace | 25 | mount |
| 11 | hair | 26 | a vendor's stock to buy |
| 12 | waist (half apron) | 27 | a vendor's stock to resell |
| 13 | inner torso (chest armour) | 28 | a vendor's stock to sell |
| 14 | bracelet | 29 | bank box |
| 15 | face | | |

## Example

```euo
; the backpack type: is the one found worn, or inside another bag?
finditem ZJF
if #FindCnt > 0
{
  if #FindLayer = 21
    display ok #FindID is a backpack worn by #FindBagID
  else
    display ok #FindID is not worn ( #FindLayer )
}
halt
```
