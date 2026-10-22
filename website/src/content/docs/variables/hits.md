---
title: "#Hits"
description: "Your character’s current hit points."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#MaxHits", "#Stamina", "#Mana"]
aliases: ["health", "hp", "hit points"]
source: wiki
---

`#Hits` is your character's current hit points; [`#MaxHits`](/variables/maxhits/) is the most it can have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Hits < #MaxHits / 2
  gosub heal
```
