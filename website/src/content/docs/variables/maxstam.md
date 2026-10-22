---
title: "#MaxStam"
description: "The most stamina your character can have."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Stamina"]
aliases: ["max stamina"]
dll: MaxStam
source: wiki
---

`#MaxStam` is the most stamina your character can have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Stamina = #MaxStam
  gosub run
```
