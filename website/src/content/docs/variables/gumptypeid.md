---
title: "#GumpTypeID"
description: "Type ID of the selected server gump: which gump it is, the same every time."
kind: variable
category: gumps
access: ro
type: id
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpSerial", "#GumpName", "#GumpKind"]
aliases: ["gump type", "gump id", "server gump"]
---

`#GumpTypeID` says which gump the server sent, for the gump selected by [`#GumpIndex`](/variables/gumpindex/),
in the usual EUO format. Only gumps the server sends have one ([`#GumpName`](/variables/gumpname/) is
`generic_gump`).

**It is the value to recognise a server gump by.** It is the same every time the server opens the same
gump, and it does not depend on the client build. Read it once by hand with the gump open, keep it in your
script, and look for it with `ScanGumps T_` and the ID. On most emulator shards it is a code made from the
gump's name in the server's source, so it stays the same until the shard changes that gump.

Reads `N/A` for a window that is not a server gump, and on client builds older than 7.0.29.97 or from
7.0.30 to 7.0.46. Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
set %confirm JHEIIPI       ; the gump's #GumpTypeID on your shard
scangumps T_ , %confirm
if #GumpCnt > 0
  event sysmessage The confirmation is open.
halt
```
