---
title: "GetSkill"
description: "Reads a skill."
kind: dll-method
category: method
syntax: "Call GetSkill skill"
needsClient: true
related: ["ChooseSkill", "#Skill", "dll:SkillLock"]
aliases: ["UO.GetSkill"]
---

Reads a skill. `skill` is its code, the first four letters of its name (see `chooseskill`).

## Parameters

| Parameter | Type | Meaning |
|---|---|---|
| `skill` | string | Skill code, or `all` for `SkillLock`. |

## Returns

In this order, from stack position 1:

| Value | Type | Meaning |
|---|---|---|
| `value` | number | In tenths, with bonuses. |
| `base` | number | In tenths, without bonuses. |
| `cap` | number | In tenths. |
| `lock` | number | 0 up, 1 down, 2 locked. |
