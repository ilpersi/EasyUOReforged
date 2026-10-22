---
title: "#MaxMana"
description: "The most mana your character can have."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Mana"]
aliases: ["max mana"]
source: wiki
---

`#MaxMana` is the most mana your character can have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
while #Mana < #MaxMana
  wait 1s
```
