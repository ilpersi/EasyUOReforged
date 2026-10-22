---
title: "#LSpell"
description: "Number of the last spell cast; set it, then event Macro 16 casts that spell."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
related: ["event Macro", "#LSkill", "Target"]
aliases: ["last spell", "cast spell"]
dll: LSpell
source: wiki
---

`#LSpell` is the number of the spell you cast last. Set it and run [`event Macro 16`](/commands/event/macro/)
(*Last Spell*) to cast that spell.

The numbers are the ones listed for casting on the `event Macro` page: [Magery](/commands/event/macro/#magery)
counts from `0` (Clumsy) to `63` (Water Elemental), [Necromancy](/commands/event/macro/#necromancy) from `101`,
[Chivalry](/commands/event/macro/#chivalry) from `201`, and so on.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.

## Example

```euo
set #LSpell 28               ; Greater Heal
event Macro 16 0
target 3s
event Macro 23 0             ; target self
```
