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
source: wiki
---

`#RHandID` is the ID of the item the client arms in your right hand with the *Arm/Disarm* macro. Set it to
an item that can be held in that hand, then run [`event Macro 24 2`](/commands/event/macro/) to put it in
your hand, or run the macro again to take it off.

The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #RHandID %sword
event Macro 24 2
```
