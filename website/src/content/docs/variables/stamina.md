---
title: "#Stamina"
description: "Your character’s current stamina."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#MaxStam", "#Hits"]
aliases: ["stam", "fatigue"]
dll: Stamina
source: wiki
---

`#Stamina` is your character's current stamina; [`#MaxStam`](/variables/maxstam/) is the most it can have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Stamina < 10
  wait 5s
```
