---
title: "#SkillCap"
description: "Returns the current skill cap for a skill chosen with chooseSkill command."
kind: variable
category: extended
access: ro
type: number
source: wiki
---

The #SkillCap system variable determines the current skill cap for a skill chosen with [chooseSkill](/commands/chooseskill/) command.

## Example

```euo
....
chooseSkill mage
if #skill = #skillCap
    halt
....
```
