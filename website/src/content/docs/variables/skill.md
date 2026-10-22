---
title: "#Skill"
description: "Returns the current skill level for a skill chosen with chooseSkill command."
kind: variable
category: extended
access: ro
type: number
source: wiki
---

The #Skill system variable determines the current skill level for a skill chosen with [chooseSkill](/commands/chooseskill/) command.

## Example

```euo
chooseSkill anim
if #skill < 1000
    event SysMessage You need to tame bulls.
if #skill >= 1000
    event SysMessage You need to tame ridgebacks.
```
