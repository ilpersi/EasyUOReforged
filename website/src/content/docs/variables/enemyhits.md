---
title: "#EnemyHits"
description: "Health in percent of the enemy in #EnemyID."
kind: variable
category: combat
access: ro
type: number
needsClient: true
related: ["#EnemyID", "#ContHP"]
aliases: ["enemy health"]
dll: EnemyHits
source: wiki
---

`#EnemyHits` is the health of the enemy in [`#EnemyID`](/variables/enemyid/), in percent: `100` is full health.
On older clients the value moves in steps of 4. It reads `N/A` when the client shows no enemy health bar.

## Example

```euo
if #EnemyHits < 20
  event SysMessage Almost dead!
```
