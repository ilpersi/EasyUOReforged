---
title: "#GumpSerial"
description: "Serial of the selected server gump, new each time the server opens it."
kind: variable
category: gumps
access: ro
type: id
origin: reforged
needsClient: true
related: ["ScanGumps", "#GumpTypeID", "#GumpName"]
aliases: ["gump serial", "server gump serial"]
---

`#GumpSerial` is the serial the server gave the gump selected by [`#GumpIndex`](/variables/gumpindex/), in
the usual EUO format. Only gumps the server sends have one ([`#GumpName`](/variables/gumpname/) is
`generic_gump`).

**It changes every time the server opens the gump**, even the same one. To recognise a gump, use
[`#GumpTypeID`](/variables/gumptypeid/). The serial tells two copies apart: a window that closed and
opened again has a new one.

Reads `N/A` for a window that is not a server gump, and on client builds older than 7.0.29.97 or from
7.0.30 to 7.0.46. Reads `N/A` when no gump is selected: none is open, [`ScanGumps`](/commands/scangumps/) has not run, or [`#GumpIndex`](/variables/gumpindex/) is past [`#GumpCnt`](/variables/gumpcnt/).

## Example

```euo
scangumps
set %first #GumpSerial
wait 20
scangumps
if #GumpSerial <> %first
  event sysmessage The window in front is new.
halt
```
