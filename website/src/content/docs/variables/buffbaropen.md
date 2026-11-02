---
title: "#BuffBarOpen"
description: "#true when the client’s buff bar window is open, #false when it is closed."
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

`#BuffBarOpen` is [`#true`](/variables/true/) (`-1`) when the buff bar window is open and
[`#false`](/variables/false/) (`0`) when it is closed, so a script can compare it with either. It reads
`N/A` with no client, or on a client whose buff bar cannot be read.

[`ScanBuffs`](/commands/scanbuffs/) can only see buffs while the window is open, so this tells an open bar
with no buffs (`#BuffBarOpen` `#true`, `#BuffCnt` 0) apart from a closed one.

## Reforged notes

Up to v26.10.29 it was `1` when open, like [`#CliLogged`](/variables/clilogged/). A script that compares
it with `1` must compare it with `#true` now; one that compares it with `0` works as before.

## Example

```euo
if #BuffBarOpen = #false
  display ok Open the buff bar so the script can see your buffs.
halt
```
