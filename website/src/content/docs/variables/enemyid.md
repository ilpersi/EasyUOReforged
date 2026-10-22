---
title: "#EnemyID"
description: "ID of the enemy whose health bar the client shows, or N/A."
kind: variable
category: combat
access: ro
type: id
needsClient: true
related: ["#EnemyHits", "event StatBar"]
aliases: ["enemy", "attacker", "opponent"]
source: wiki
---

`#EnemyID` is the ID of the enemy the client shows a health bar for, usually the one you are fighting, or `N/A`
when there is none. With more than one enemy, it shows whichever the client currently tracks, which can
change from moment to moment.

## Example

```euo
if #EnemyID <> N/A
  display ok You are fighting! The enemy has #EnemyHits percent health.
```
