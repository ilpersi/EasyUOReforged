---
title: "#SkillCap"
description: "Cap of the skill chosen with chooseskill, in tenths."
kind: variable
category: extended
access: ro
type: number
needsClient: true
related: ["ChooseSkill", "#Skill"]
aliases: ["skill cap"]
source: wiki
---

`#SkillCap` is the most the skill can reach, in tenths: `1000` is 100.0. It describes the skill selected with [`chooseskill`](/commands/chooseskill/), and is read from the client each
time you use it.

## Example

```euo
chooseskill mage
if #Skill >= #SkillCap
  halt
```
