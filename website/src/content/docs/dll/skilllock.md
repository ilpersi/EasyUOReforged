---
title: "SkillLock"
description: "Sets a skill's lock, like `exevent SkillLock`: `lock` 0 up, 1 down, 2 locked; `skill` a skill code or `all`."
kind: dll-method
category: method
syntax: "Call SkillLock skill lock"
needsClient: true
related: ["exevent SkillLock", "dll:GetSkill"]
aliases: ["UO.SkillLock"]
---

Sets a skill's lock, like `exevent SkillLock`: `lock` 0 up, 1 down, 2 locked; `skill` a skill code or `all`.

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `skill` | string | Skill code, or `all` for `SkillLock`. |
| `lock` | number | 0 up, 1 down, 2 locked. |

## Returns

Nothing.
