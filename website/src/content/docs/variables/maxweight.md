---
title: "#MaxWeight"
description: "Most weight your character can carry, calculated from strength: 3.5 × Str + 40."
kind: variable
category: status
access: ro
type: number
needsClient: true
related: ["#Weight", "#Str"]
aliases: ["max weight", "carry capacity"]
dll: MaxWeight
source: wiki
---

`#MaxWeight` is the most weight your character can carry, in stones. EasyUO calculates it from your strength
with the classic formula, 3.5 × [`#Str`](/variables/str/) + 40. Shards that use another rule (racial bonuses,
for example) show a different maximum in the status window.

It is read from your character's status, which the client only has once the status window has been opened.
If it reads `N/A`, open the status window once, by hand or with `event Macro 8 2`.

## Example

```euo
if #Weight > #MaxWeight
  display ok You are overweight!
```
