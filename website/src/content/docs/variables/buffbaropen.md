---
title: "#BuffBarOpen"
description: "1 when the client’s buff bar window is open, 0 when it is closed."
kind: variable
category: buffs
access: ro
type: boolean
origin: reforged
needsClient: true
related: ["ScanBuffs", "#BuffCnt", "#BuffIndex"]
dll: BuffBarOpen
aliases: ["buff bar open"]
---

`#BuffBarOpen` is `1` when the buff bar window is open and `0` when it is closed, like
[`#CliLogged`](/variables/clilogged/). It reads `N/A` on a client whose buff bar cannot be read.

[`ScanBuffs`](/commands/scanbuffs/) can only see buffs while the window is open, so this tells an open bar
with no buffs (`#BuffBarOpen` 1, `#BuffCnt` 0) apart from a closed one.

## Example

```euo
if #BuffBarOpen = 0
  display ok Open the buff bar so the script can see your buffs.
halt
```
