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
`Runebook$Blessed$`.

## Example

```euo
finditem ZBN C_ , #BackpackID     ; a runebook
event Property #FindID
if Blessed in #Property
  display ok It is blessed.
halt
```
