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
source: wiki
---

`#LHandID` is the ID of the item the client arms in your left hand with the *Arm/Disarm* macro. Set it to
an item that can be held in that hand, then run [`event Macro 24 1`](/commands/event/macro/) to put it in
your hand, or run the macro again to take it off.

The value lives in the client: setting it changes it for every script attached to that client.

## Example

```euo
set #LHandID %shield
event Macro 24 1
```
