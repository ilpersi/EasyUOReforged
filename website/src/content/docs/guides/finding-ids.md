---
title: "Finding IDs and types"
description: "How to read from your own game the values a script needs: the IDs and types of items, the names of gumps and the texts of the journal."
sidebar:
  order: 2.6
---

A script needs values that only your game knows: the ID of your bag, the type of the item you look for, the name
of the gump it waits for, the text your shard writes in the journal. They differ between shards, clients and
characters, so a value copied from someone else's script may be wrong for you, and a value somebody guessed
always is. Read them from your own game.

- An **ID** (6 to 8 letters, `YKLMNOP`) is one object: this bag, this horse.
- A **type** (2 or 3 letters, `POF`) is a kind of object: any pile of gold.

In a script, put such values in `set` lines at the top, with a comment, so they are easy to find and change:

```euo
set %lootbag ABCDEFG                ; the ID of your loot bag
set %goldtype POF                   ; the type of gold on your shard
finditem %goldtype C_ , %lootbag
display ok Stacks of gold in the bag: #FindCnt
halt
```

## With the variable inspector

The variable inspector on the right of the editor shows the `#variables` of the client while you play.

| Do this in the game | Then read |
|---|---|
| Double-click an item | [`#LObjectID`](/variables/lobjectid/) and [`#LObjectType`](/variables/lobjecttype/) |
| Target something | [`#LTargetID`](/variables/ltargetid/), or [`#LTargetX`](/variables/ltargetx/) and [`#LTargetY`](/variables/ltargety/) for a place |
| Open a container or a gump | [`#ContID`](/variables/contid/), [`#ContName`](/variables/contname/), [`#ContKind`](/variables/contkind/), [`#ContSize`](/variables/contsize/) |
| Stand somewhere | [`#CharPosX`](/variables/charposx/) and [`#CharPosY`](/variables/charposy/) |

Your own character and backpack need no looking up: they are [`#CharID`](/variables/charid/) and
[`#BackpackID`](/variables/backpackid/).

## With a probe script

A probe is a short script that shows a value and stops. This one asks you to click an object and shows its
ID and type. Ctrl+C copies the text of the box.

```euo
event sysmessage Click the object.
set #TargCurs 1
while #TargCurs = 1
  wait 1
finditem #LTargetID
display ok ID: #FindID $Type: #FindType $Stack: #FindStack
halt
```

This one shows the gump on top, for a script that waits for a gump or clicks in one:

```euo
display ok Name: #ContName $Kind: #ContKind $Size: #ContSize $Position: #ContPosX #ContPosY
halt
```

And this one shows the newest line of the journal as a script sees it, with `_` for spaces, and its colour:

```euo
scanjournal 1
display ok Text: #Journal $Colour: #JColor
halt
```
