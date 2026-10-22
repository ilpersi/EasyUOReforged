---
title: "#ContHP"
description: "Health in percent of the creature whose health bar is the top gump."
kind: variable
category: container
access: ro
type: number
needsClient: true
related: ["#ContName", "#EnemyHits"]
aliases: ["health bar", "pet health", "container hp"]
---

When the gump on top is a health bar (the client calls it `status gump`), `#ContHP` is that creature's
health as a percentage, `0` to `100`. For any other gump it is `0`.

## Example

```euo
; drag a pet's health bar out first, then click it so it is on top
if #ContName = status_gump && #ContHP < 50
  display ok Your pet is below half health.
```
