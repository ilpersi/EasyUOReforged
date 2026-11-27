---
title: "#FindProp"
description: "Property tooltip of the object FindItem selected, as the last ScanProps read it; N/A when it wasn't read."
kind: variable
category: finditem
access: ro
type: string
origin: reforged
needsClient: true
related: ["ScanProps", "FindItem", "#FindID", "#Property", "event Property", "dll:GetItem"]
aliases: ["properties", "property", "tooltip", "item properties"]
---

`#FindProp` is the property tooltip of the object [`FindItem`](/commands/finditem/) selected at the
current [`#FindIndex`](/variables/findindex/), as the last [`ScanProps`](/commands/scanprops/) read
it. Its format is [`#Property`](/variables/property/)'s: the name, then each tooltip line, each followed
by `$`.

```euo
finditem * C_ , #BackpackID
scanprops
if #FindCnt > 0
{
  for #FindIndex 1 #FindCnt
    log #FindID #FindProp
}
halt
```

It reads `N/A` when the last `ScanProps` didn't read that object: no `ScanProps` yet, nothing found, an
index out of range, a `FindItem` since then that found other objects, and without a client. It reads `$`
for an object whose tooltip the shard never sent.

## Reforged notes

New in EasyUO Reforged. See [`ScanProps`](/commands/scanprops/) for how it reads the tooltips and how
the text can differ from `event Property`'s in rare cases.
