---
title: "#MinDmg"
description: "Least damage of the weapon in your hands."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#MaxDmg", "#LHandID", "#RHandID"]
aliases: ["damage", "weapon damage"]
dll: MinDmg
source: wiki
---

`#MinDmg` is the least damage of the weapon you are holding, as the status window shows it; [`#MaxDmg`](/variables/maxdmg/) is the most.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`. It also needs a client with the
extended status of Age of Shadows and later; on older clients it reads `N/A`.

## Example

```euo
display ok Damage #MinDmg - #MaxDmg
halt
```
