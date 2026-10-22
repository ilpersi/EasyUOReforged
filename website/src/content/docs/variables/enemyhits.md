---
title: "#EnemyHits"
description: "Returns the percentage of hit points left on the current enemy."
kind: variable
category: combat
access: ro
type: number
needsClient: true
source: wiki
---

The #enemyHits system variable represents the percentage of hit points left on the current enemy.

:::note
It is only possible to see one enemy at a time using this variable. If you have more than one enemy, the variable will switch values randomly.
:::

## Example

```euo
if #enemyID <> N/A
  display ok You're being attacked! The attacker has , #enemyHits , % Hits.
```
