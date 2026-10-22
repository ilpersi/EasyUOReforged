---
title: "#SkillLock"
description: "Lock of the skill chosen with chooseskill: up, down or locked."
kind: variable
category: extended
access: ro
type: string
needsClient: true
related: ["ChooseSkill", "exevent SkillLock"]
aliases: ["skill lock"]
source: wiki
---

`#SkillLock` is the lock of the skill: `up`, `down` or `locked`. It describes the skill selected with [`chooseskill`](/commands/chooseskill/), and is read from the client each
time you use it. Change it with
[`exevent SkillLock`](/commands/exevent/skilllock/).

## Example

```euo
chooseskill taming
if #SkillLock = locked
  exevent SkillLock taming up
```
