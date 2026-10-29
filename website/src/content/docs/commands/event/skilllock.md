---
title: "event SkillLock"
description: "Sets the lock of a skill, or of all skills; the same as exevent SkillLock."
kind: subcommand
category: event
syntax: "event SkillLock {skill|all} {up|down|locked}"
needsClient: true
related: ["exevent SkillLock", "ChooseSkill", "#SkillLock"]
aliases: ["skill lock"]
dll: SkillLock
source: wiki
---

`event SkillLock` sets whether a skill may go up, go down, or stay where it is. It does exactly the same as
[`exevent SkillLock`](/commands/exevent/skilllock/): EasyUO forwards it there, so both names keep working.

## Parameters

| Parameter | Meaning |
|---|---|
| `skill` | The skill's code, the first four letters of its name, or `all` for every skill. See [`chooseskill`](/commands/chooseskill/#skill-codes) for the codes. |
| lock | `up`, `down` or `locked`. |

## Example

```euo
event SkillLock mage down
event SkillLock all locked
halt
```
