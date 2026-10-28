---
title: "#RHandID"
description: "ID of the item for the right hand; set it, then event Macro 24 2 arms it."
kind: variable
category: combat
access: rw
type: id
needsClient: true
related: ["#LHandID", "event Macro", "exevent Equip"]
aliases: ["right hand", "arm", "weapon"]
dll: RHandID
source: wiki
---

`#RHandID` is the ID of the item the client arms in your right hand (a one-handed weapon) with the
*Arm/Disarm* macro, [`event Macro 24 2`](/commands/event/macro/). With your right hand empty, the macro equips
the item with this ID. With something in your right hand, the macro saves that item's ID here and takes it off,
so running the macro again puts it back.

To arm a given item, set `#RHandID` to it and run the macro with your right hand empty. With the hand empty and
no ID set, the client says "You must first disarm a weapon in order to arm one."

The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #RHandID %sword
event Macro 24 2
```
