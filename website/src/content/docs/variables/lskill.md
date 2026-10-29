---
title: "#LSkill"
description: "Number of the last skill used; set it, then event Macro 14 uses that skill."
kind: variable
category: lastaction
access: rw
type: number
needsClient: true
related: ["event Macro", "ChooseSkill", "#LSpell"]
aliases: ["last skill", "use skill"]
dll: LSkill
source: wiki
---

`#LSkill` is the number of the skill you used last. Set it and run [`event Macro 14`](/commands/event/macro/)
(*Last Skill*) to use a skill, as if you had clicked its button in the skills list.

The numbers are listed under [Use Skills](/commands/event/macro/#use-skills) on the `event Macro` page; they are
the same numbers that skill uses everywhere, for example Hiding is `21`, Meditation `46`, Spirit Speak `32`.

The value lives in the client, not in the script: setting it changes it for every script attached to that
client, and the client changes it too as you play. Save the old value and put it back if other scripts may
rely on it.

## Example

```euo
set #LSkill 21               ; Hiding
event Macro 14 0
halt
```
