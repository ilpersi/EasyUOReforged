---
title: "#Skill"
description: "Value of the skill chosen with chooseskill, in tenths (700 = 70.0)."
kind: variable
category: extended
access: ro
type: number
needsClient: true
related: ["ChooseSkill", "#SkillCap", "#SkillLock"]
aliases: ["skill value", "skill level"]
source: wiki
---

`#Skill` is the value of the skill, in tenths: `700` is 70.0. It describes the skill selected with [`chooseskill`](/commands/chooseskill/), and is read from the client each
time you use it. With `chooseskill … real` it is the base
value, without bonuses.

## Example

```euo
chooseskill anim
if #Skill < 1000
  display ok Tame bulls.
else
  display ok Tame ridgebacks.
halt
```
