---
title: "#EnemyID"
description: "Returns the ID of the current enemy."
kind: variable
category: combat
access: ro
type: id
needsClient: true
source: wiki
---

The #enemyID system variable holds the ID of the current enemy.

:::note
It is only possible to see one enemy at a time using this variable. If you have more than one enemy, the variable will switch ID's randomly.
:::

## Example

```euo
if #enemyID <> N/A
  display ok You're being attacked! The attacker has , #enemyHits , % Hits.
```
