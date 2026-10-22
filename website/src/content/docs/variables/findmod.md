---
title: "#FindMod"
description: "Offset added to #FindX and #FindY for objects in containers, written x_y."
kind: variable
category: finditem
access: rw
type: string
needsClient: true
related: ["#FindX", "#FindY"]
aliases: ["offset"]
source: wiki
---

`#FindMod` is an offset added to [`#FindX`](/variables/findx/) and [`#FindY`](/variables/findy/) for objects in
containers, written `x_y`, for example `140_220`. It is `0_0` until you set it. Use it to click a fixed spot
relative to an item, such as the backpack icon on a paperdoll.

## Example

```euo
set #FindMod 140_220         ; from the paperdoll to its backpack icon
finditem #BackpackID C_ , #CharID
event Drag %something
wait 2s
click #FindX #FindY p        ; drop it on the backpack icon
```
