---
title: "#MountID"
description: "ID of the mount item your character rides, or N/A while it is on foot."
kind: variable
category: character
access: ro
type: id
origin: reforged
needsClient: true
related: ["#MountType", "#FindID", "#FindLayer"]
dll: MountID
aliases: ["mount id", "horse id", "mounted", "riding"]
---

`#MountID` is the ID of the mount item your character wears while it rides, in the same letter format
as [`#FindID`](/variables/findid/). It reads `N/A` while your character is on foot, and without a client,
so `#MountID <> N/A` tells whether you ride.

While you ride, the client keeps the mount as an item your character wears in the mount layer (25, see
[`#FindLayer`](/variables/findlayer/)). The shard puts that item on your character for the ride. On the usual
shards it has an ID of its own, so `#MountID` is not the ID the creature had while it stood next to you.
[`#MountType`](/variables/mounttype/) is its type.

## Example

```euo
if #MountID <> N/A
  display ok You ride the mount item #MountID of type #MountType
else
  display ok You are on foot.
halt
```
