---
title: "ChooseSkill"
description: "Reads the current skill value/lock status for a specific skill."
kind: command
category: client
syntax: "chooseSkill {skill name} [\"real\"]"
needsClient: true
source: wiki
---

:::note
From EUO 1.5 Test version 53 and up [Event SkillLock](/commands/event/skilllock/) has been replaced by [Exevent SkillLock](/commands/exevent/skilllock/). For compatibility, the obsolete Event is internally rerouted to the ExEvent.
:::

The chooseSkill command reads the skill value for the specified skill and places the value into the #skill system variable. The current lock status is placed in the #skillLock system variable and the current skill cap is placed in the #skillCap system variable.

The skill name is the first four characters of the actual skill name, with the exception of animal lore (ANIL) and stealth (STLT). See the list below for more info.

## Example

```euo
chooseSkill mage
if #skill < 700
{
msg You don't have enough magery $
halt
}
...

TSPerry72@…
26-Feb-2005 15:52   #39
Here is a list of 4 letter codes for each skill as of February 2005. Listed by UO catagory and alphebetized.

Miscellaneous Skills
Alch - Alchemy
Blac - Blacksmithy
Bowc - Bowcraft Fletching
Bush - Bushido
Carp - Carpentry
Chiv - Chivalry
Cook - Cooking
Fish - Fishing
Focu - Focus
Heal - Healing
Herd - Herding
Lock - Lockpicking
Lumb - Lumberjacking
Mage - Magery
Medi - Meditation
Mini - Mining
Musi - Musicianship
Necr - Necromancy
Ninj - Ninjitsu
Remo - Remove Trap
Resi - Resisting Spells
Snoo - Snooping
Stea - Stealing
Stlt - Stealth
Tail - Tailoring
Tink - Tinkering
Vete - Veterinary

Combat Skills
Arch - Archery
Fenc - Fencing
Mace - Mace Fighting
Parr - Parrying
Swor - Swordsmanship
Tact - Tactics
Wres - Wrestling

Actions
Anim - Animal Taming
Begg - Begging
Camp - Camping
Dete - Detecting Hidden
Disc - Discordance
Hidi - Hiding
Insc - Inscription
Peac - Peacemaking
Pois - Poisoning
Prov - Provocation
Spir - Spirit Speak
Trac - Tracking

Lore & Knowledge
Anat - Anatomy
Anil - Animal Lore
Arms - Arms Lore
Eval - Evaluating Intelligence
Fore - Forensic Evaluation
Item - Item Identification
Tast - Taste Identification
```
