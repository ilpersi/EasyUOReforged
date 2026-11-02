---
title: "#MountType"
description: "Type of the mount item your character rides, or N/A while it is on foot."
kind: variable
category: character
access: ro
type: id
origin: reforged
needsClient: true
related: ["#MountID", "#FindType", "#FindLayer"]
dll: MountType
aliases: ["mount type", "horse type", "mounted", "riding"]
---

`#MountType` is the type of the mount item your character wears while it rides, in the same letter
format as [`#FindType`](/variables/findtype/): for example `OVX` (graphic `0x3EA0`) for a horse. It reads
`N/A` while your character is on foot, and without a client.

It is the type of the item, not the creature's body type that [`FindItem`](/commands/finditem/) shows
while the creature stands next to you. Each kind of mount has its own item type.
[`#MountID`](/variables/mountid/) is the item's ID.

## Example

```euo
if #MountType = OVX
  display ok You ride a horse.
halt
```
