---
title: "#SkillLock"
description: "Returns the current lock status of the skill chosen with chooseSkill command."
kind: variable
category: extended
access: ro
type: string
source: wiki
---

The #skillLock system variable determines the current lock status of the skill chosen with [chooseSkill](/commands/chooseskill/) command.

| Value  | Description                  |
|--------|------------------------------|
| up     | Skill lock is pointing up.   |
| down   | Skill lock is pointing down. |
| locked | Skill lock is locked.        |

#skillLock Values

## Example

```euo
chooseSkill taming
if #skillLock = locked
{
    event SysMessage Your taming is locked. Cannot continue.
    halt
}
```
