---
title: "#TargCurs"
description: "1 while a target cursor is showing; set it to 1 to let the user pick a target."
kind: variable
category: extended
access: rw
type: boolean
needsClient: true
related: ["Target", "#LTargetID", "#LTargetKind"]
aliases: ["target cursor", "pick target"]
dll: TargCurs
source: wiki
---

`#TargCurs` is `1` while the client shows a target cursor and `0` otherwise. [`target`](/commands/target/) waits
for it to become `1`.

Setting it to `1` shows a target cursor yourself. Whatever the user then clicks lands in
[`#LTargetID`](/variables/ltargetid/) (and [`#LTargetKind`](/variables/ltargetkind/)), without targeting anything
in the game: a simple way for a script to ask "which item?".

## Example

```euo
event SysMessage Click the item to use.
set #TargCurs 1
while #TargCurs = 1
  wait 1
set %item #LTargetID
```
