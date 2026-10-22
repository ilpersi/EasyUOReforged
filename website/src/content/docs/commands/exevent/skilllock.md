---
title: "exevent SkillLock"
description: "Sets the lock of a skill, or of all skills."
kind: subcommand
category: exevent
syntax: "exevent SkillLock {skill|all} {up|down|locked}"
needsClient: true
related: ["event SkillLock", "ChooseSkill", "#SkillLock", "exevent StatLock"]
aliases: ["skill lock"]
dll: SkillLock
source: wiki
---

`exevent SkillLock` sets whether a skill may go up, go down, or stay where it is. The client's skill window
shows the new lock at once. [`event SkillLock`](/commands/event/skilllock/) does exactly the same.

## Parameters

| Parameter | Meaning |
|---|---|
| `skill` | The skill's code, the first four letters of its name, or `all` for every skill. See [`chooseskill`](/commands/chooseskill/#skill-codes) for the codes. |
| lock | `up`, `down` or `locked`. |

Read a skill's current lock with [`chooseskill`](/commands/chooseskill/) and
[`#SkillLock`](/variables/skilllock/).

## Example

```euo
exevent SkillLock mage down
exevent SkillLock arms locked
exevent SkillLock all up
```
