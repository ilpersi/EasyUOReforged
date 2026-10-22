---
title: "exevent SkillLock"
description: "Changes the skill locks on the different skills."
kind: subcommand
category: exevent
syntax: "Exevent SkillLock {[skill name] | [all]} {[up] | [down] | [locked]}"
needsClient: true
related: ["exevent"]
source: wiki
---

The Exevent SkillLock command changes the skill lock on the specified skill to either: up, down or locked. If you want to change the lock of all the skills as name use the keyword "all".

:::note
This command is only available from EUO 1.5 Test version 53.
:::

## Example

```euo
; changes magery to down
Exevent SkillLock mage down
; locks armlore
Exevent SkillLock arms locked

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
