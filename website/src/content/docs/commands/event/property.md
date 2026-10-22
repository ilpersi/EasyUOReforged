---
title: "event Property"
description: "Reads the property tooltip of an item or character into #Property."
kind: subcommand
category: event
syntax: "event Property {id}"
needsClient: true
sets: ["#Property"]
related: ["FindItem", "#Property"]
aliases: ["tooltip", "item properties"]
dll: Property
source: wiki
---

`event Property` reads the property tooltip of an item or character, the text that pops up when you hover
over it, and puts it in [`#Property`](/variables/property/). Each line ends with `$`, the name first.

The shard has to send property tooltips: on pre-AoS free shards there are none, and `#Property` stays
empty.

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Example

```euo
finditem %sword C_ , #BackpackID
event Property #FindID
if Vanquishing in #Property
  display ok This sword is of Vanquishing.
```
