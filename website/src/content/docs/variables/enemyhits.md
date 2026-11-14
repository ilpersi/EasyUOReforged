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
changed: true
source: wiki
---

`#EnemyHits` is the health of the enemy in [`#EnemyID`](/variables/enemyid/), in percent: `100` is full health.
It reads `N/A` when the client shows no enemy health bar.

The shard decides how fine the steps are. Shards that send enemy health out of 25 (RunUO and those based on
it) move it in steps of 4; ModernUO sends it out of 100, so it moves by 1.

## Example

```euo
if #EnemyHits < 20
  display ok Almost dead!
halt
```

## Reforged notes

- EasyUO multiplies the client's number by 4, which gives a percentage only on shards that send health out
  of 25. On ModernUO shards it read up to 400. Reforged divides by the maximum the shard sent, so it reads
  a percentage on every shard, and the same numbers as EasyUO on shards that count out of 25.
- On `client_beta.exe` it used to stay at the maximum, whatever the enemy's health. It now goes down with
  the enemy's health, as on the other clients.
