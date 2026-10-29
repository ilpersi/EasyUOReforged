---
title: "#MaxHits"
description: "The most hit points your character can have."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Hits"]
aliases: ["max health", "max hp"]
dll: MaxHits
source: wiki
---

`#MaxHits` is the most hit points your character can have.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Hits < #MaxHits
  display ok Hurt: #Hits of #MaxHits hit points.
halt
```
