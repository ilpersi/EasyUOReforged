---
title: "event Drag"
description: "Picks up an item, as if you dragged it with the mouse."
kind: subcommand
category: event
syntax: "event Drag {id}"
needsClient: true
related: ["exevent Drag", "Click", "#LLiftedID"]
aliases: ["pick up", "drag item"]
dll: Drag
source: wiki
---

`event Drag` picks up the item with the given ID, as if you had started dragging it with the mouse. The item
then hangs on the cursor until you drop it, for example with [`click`](/commands/click/) and `p`.

- The item has to be known to the client: on screen, or in an open container.
- Nothing happens while you are already holding something.

To drop through the server instead, pick the item up with [`exevent Drag`](/commands/exevent/drag/), not
`event Drag`: mixing `event Drag` with the `exevent Drop…` commands can leave a ghost item on the cursor.

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Example

```euo
event Drag %ore
wait 20
click 100 100 p
```
