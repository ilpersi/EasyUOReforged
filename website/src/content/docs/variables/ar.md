---
title: "#AR"
description: "Your character’s physical resistance (armour rating before Age of Shadows)."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#FR", "#CR", "#PR", "#ER"]
aliases: ["armor", "armour", "physical resist"]
dll: AR
source: wiki
---

`#AR` is your character's physical resistance; on shards without the Age of Shadows resistances, its armour rating.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
event SysMessage My physical resist is #AR
```
