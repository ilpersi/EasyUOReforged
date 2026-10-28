---
title: "#LHandID"
description: "ID of the item for the left hand; set it, then event Macro 24 1 arms it."
kind: variable
category: combat
access: rw
type: id
needsClient: true
related: ["#RHandID", "event Macro", "exevent Equip"]
aliases: ["left hand", "arm", "weapon"]
dll: LHandID
source: wiki
---

`#LHandID` is the ID of the item the client arms in your left hand (a shield or a two-handed weapon) with the
*Arm/Disarm* macro, [`event Macro 24 1`](/commands/event/macro/). With your left hand empty, the macro equips
the item with this ID. With something in your left hand, the macro saves that item's ID here and takes it off,
so running the macro again puts it back.

To arm a given item, set `#LHandID` to it and run the macro with your left hand empty. With the hand empty and
no ID set, the client says "You must first disarm a weapon in order to arm one."

The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #LHandID %shield
event Macro 24 1
```
