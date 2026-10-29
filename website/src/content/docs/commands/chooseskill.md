---
title: "ChooseSkill"
description: "Selects the skill that #Skill, #SkillCap and #SkillLock report."
kind: command
category: client
syntax: "chooseskill {skill} [real]"
needsClient: true
sets: ["#Skill", "#SkillCap", "#SkillLock"]
related: ["exevent SkillLock", "#Skill"]
aliases: ["skill", "skill value", "skill level"]
dll: GetSkill
source: wiki
---

`chooseskill` selects the skill that [`#Skill`](/variables/skill/), [`#SkillCap`](/variables/skillcap/) and
[`#SkillLock`](/variables/skilllock/) describe. The variables are read from the client each time you use
them, so they always show the current value; you do not need to run `chooseskill` again to refresh them.

## Parameters

| Parameter | Meaning |
|---|---|
| `skill` | The skill. Only the first four letters count, so `mage` and `magery` both work. See the table below. |
| `real` | Optional. `#Skill` reports the base value, without bonuses from items and stats. |

Skill values are in tenths: `700` is 70.0. `#SkillLock` is `up`, `down` or `locked`. An unknown name
gives `0` everywhere.

## Skill codes

The code is the first four letters of the skill's name, with two exceptions: **Animal Lore** is `ANIL`
(`ANIM` is Animal Taming) and **Stealth** is `STLT` (`STEA` is Stealing).

| Code | Skill | Code | Skill |
|---|---|---|---|
| `ALCH` | Alchemy | `LUMB` | Lumberjacking |
| `ANAT` | Anatomy | `MACE` | Mace Fighting |
| `ANIL` | Animal Lore | `MAGE` | Magery |
| `ANIM` | Animal Taming | `MEDI` | Meditation |
| `ARCH` | Archery | `MINI` | Mining |
| `ARMS` | Arms Lore | `MUSI` | Musicianship |
| `BEGG` | Begging | `MYST` | Mysticism |
| `BLAC` | Blacksmithy | `NECR` | Necromancy |
| `BOWC` | Bowcraft / Fletching | `NINJ` | Ninjitsu |
| `BUSH` | Bushido | `PARR` | Parrying |
| `CAMP` | Camping | `PEAC` | Peacemaking |
| `CARP` | Carpentry | `POIS` | Poisoning |
| `CART` | Cartography | `PROV` | Provocation |
| `CHIV` | Chivalry | `REMO` | Remove Trap |
| `COOK` | Cooking | `RESI` | Resisting Spells |
| `DETE` | Detecting Hidden | `SNOO` | Snooping |
| `DISC` | Discordance | `SPEL` | Spellweaving |
| `EVAL` | Evaluating Intelligence | `SPIR` | Spirit Speak |
| `FENC` | Fencing | `STEA` | Stealing |
| `FISH` | Fishing | `STLT` | Stealth |
| `FOCU` | Focus | `SWOR` | Swordsmanship |
| `FORE` | Forensic Evaluation | `TACT` | Tactics |
| `HEAL` | Healing | `TAIL` | Tailoring |
| `HERD` | Herding | `TAST` | Taste Identification |
| `HIDI` | Hiding | `THRO` | Throwing |
| `IMBU` | Imbuing | `TINK` | Tinkering |
| `INSC` | Inscription | `TRAC` | Tracking |
| `ITEM` | Item Identification | `VETE` | Veterinary |
| `LOCK` | Lockpicking | `WRES` | Wrestling |

## Example

```euo
chooseskill mage
if #Skill < 700
{
  display ok You need at least 70 Magery for this script.
  halt
}
display ok Enough Magery: let's go.
halt
```
