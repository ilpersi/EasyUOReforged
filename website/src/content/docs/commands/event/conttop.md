---
title: "event ContTop"
description: "Brings a gump to the front, counted from the top gump."
kind: subcommand
category: event
syntax: "event ContTop {index}"
needsClient: true
related: ["IgnoreCont", "#ContName", "ContPos"]
aliases: ["bring gump to front", "container top"]
dll: ContTop
---

`event ContTop` brings one of the open gumps to the front, as if you had clicked it. `index` counts the gumps
from the top, the same way the `#Cont…` variables see them: `0` is the gump already on top, `1` the next one
down, and so on. Gumps on the [`IgnoreCont`](/commands/ignorecont/) list are skipped.

After it, the `#Cont…` variables describe the gump you brought forward.

## Example

```euo
; bring the second gump forward and see what it is
event ContTop 1
wait 5
display ok Now on top: #ContName
halt
```

## Notes

The command needs the client function it calls to be known for your client version. On a client where it is
not, nothing happens.
