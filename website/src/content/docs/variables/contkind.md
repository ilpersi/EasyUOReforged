---
title: "#ContKind"
description: "Kind of the gump on top, as a code; tells crafting menus, runebooks and more apart."
kind: variable
category: container
access: ro
type: id
needsClient: true
related: ["#ContName", "IgnoreCont"]
aliases: ["gump kind"]
dll: ContKind
source: wiki
---

`#ContKind` is a short code for the kind of the gump on top. Most gumps have one, so it tells whether a
crafting menu, a runebook or something else is open. Like all `#Cont…` variables, it describes the gump on top: the one opened, clicked or moved last. Gumps on the
[`IgnoreCont`](/commands/ignorecont/) list are skipped.

The codes can change when the client is updated. Keep them in variables at the top of your script, so they
are easy to change. [`IgnoreCont`](/commands/ignorecont/) accepts a `#ContKind` value to skip that kind of
gump.

## Example

```euo
set %craftmenu GHCE          ; the crafting menu's #ContKind on your client
if #ContKind <> %craftmenu
  gosub usetool
```
