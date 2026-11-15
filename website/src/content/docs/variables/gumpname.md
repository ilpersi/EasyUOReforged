---
title: "#GumpName"
description: "The client's own name for the selected gump window, e.g. container_gump."
kind: variable
category: gumps
access: ro
type: string
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpKind", "#ContName"]
aliases: ["gump name"]
---

`#GumpName` is the name the client gives the kind of window selected by [`#GumpIndex`](/variables/gumpindex/),
the same text as [`#ContName`](/variables/contname/), with its spaces written as `_`. For example
`container_gump`, `paperdoll_gump`, `status_gump`, `skill_gump`, `BuffIcons_Gump`, and `generic_gump`
for every gump the server sends.

The names are the same on every client build, so a script can rely on them.

Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
for #GumpIndex 1 #GumpCnt
  if #GumpName = generic_gump
    event sysmessage A server gump is open: #GumpTypeID
halt
```
