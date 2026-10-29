---
title: "ContPos"
description: "Moves the top gump to a position on the screen."
kind: command
category: client
syntax: "contpos {x} {y}"
needsClient: true
related: ["#ContPosX", "#ContPosY", "NextCPos", "IgnoreCont"]
aliases: ["move gump", "container position"]
source: wiki
---

`contpos` moves the gump on top (the one the `#Cont…` variables describe) so that its top-left corner is at
`x`, `y` in the client window. It does the same as setting [`#ContPosX`](/variables/contposx/) and
[`#ContPosY`](/variables/contposy/).

Gumps on the [`IgnoreCont`](/commands/ignorecont/) list are skipped when finding the top one.

## Example

```euo
msg bank$
wait 20
contpos 10 10
halt
```
