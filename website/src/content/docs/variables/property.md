---
title: "#Property"
description: "Property tooltip read by the last event Property; lines end with $."
kind: variable
category: result
access: ro
type: string
needsClient: true
related: ["event Property"]
aliases: ["tooltip", "item properties"]
source: wiki
---

`#Property` is the property tooltip read by the last [`event Property`](/commands/event/property/): the item's
name first, then its properties, each line ending with `$`. For a blessed runebook, for example, it reads
`Runebook$Blessed$`. Spaces in it are real spaces, not `_` as in [`#Journal`](/variables/journal/), so write
[`#SPC`](/variables/spc/) for them; [`str`](/commands/str/#spaces-and-_) shows how to take it apart.

## Example

```euo
finditem ZBN C_ , #BackpackID     ; a runebook
event Property #FindID
if Blessed in #Property
  display ok It is blessed.
halt
```
