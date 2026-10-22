---
title: "event Macro"
description: "Runs one of the client's built-in macros: speech, gumps, skills, spells, targeting."
kind: subcommand
category: event
syntax: "event Macro {macro} [parameter] [text]"
needsClient: true
related: ["#LObjectID", "#LTargetID", "Target", "Msg"]
aliases: ["client macro", "use skill", "cast spell", "open backpack"]
dll: Macro
source: wiki
---

`event Macro` makes the client run one of its built-in macros, the same ones you can bind to keys in the
client's options: speak, open a gump, use a skill, cast a spell, target, and so on.

## Parameters

| Parameter | Meaning |
|---|---|
| `macro` | Which macro, see the tables below. |
| `parameter` | Optional. Selects a variant: which gump to open, which skill or spell. Default: `0`. |
| `text` | Optional. Text for the speech macros and others marked `^`. When you give text, write the `parameter` too, even if it is `0`. |

The macros that use something "last" ([`#LObjectID`](/variables/lobjectid/), [`#LTargetID`](/variables/ltargetid/),
[`#LSkill`](/variables/lskill/), [`#LSpell`](/variables/lspell/)) read those variables, so set them first to
choose what the macro acts on.

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Macro numbers

### Speech

| Param 1 | Param 2 | Param 3  | Description |
|---------|---------|----------|-------------|
| 1       | 0       | msg text | Say         |
| 2       | 0       | msg text | Emote       |
| 3       | 0       | msg text | Whisper     |
| 4       | 4       | msg text | Yell        |

### Movement

| Param 1 | Param 2 | Param 3 | Description     |
|---------|---------|---------|-----------------|
| 5       | 0       |         | Walk North West |
| 5       | 1       |         | Walk North      |
| 5       | 2       |         | Walk North East |
| 5       | 3       |         | Walk East       |
| 5       | 4       |         | Walk South East |
| 5       | 5       |         | Walk South      |
| 5       | 6       |         | Walk South West |
| 5       | 7       |         | Walk West       |

### War/Peace & Paste

| Param 1 | Param 2 | Param 3 | Description      |
|---------|---------|---------|------------------|
| 6       | 0       |         | Toggle War/Peace |
| 7       | 0       |         | Paste            |

### Gump Control

| Param 1 | Param 2 | Param 3 | Description                 |
|---------|---------|---------|-----------------------------|
| 8       | 0       |         | Open Configuration          |
| 8       | 1       |         | Open Paperdoll              |
| 8       | 2       |         | Open Status                 |
| 8       | 3       |         | Open Journal                |
| 8       | 4       |         | Open Skills                 |
| 8       | 5       |         | Open Spellbook              |
| 8       | 6       |         | Open Chat                   |
| 8       | 7       |         | Open Backpack               |
| 8       | 8       |         | Open Overview               |
| 8       | 9       |         | Open Mail                   |
| 8       | 10      |         | Open Party Manifest         |
| 8       | 11      |         | Open Party Chat             |
| 8       | 12      |         | Open Necro Spellbook        |
| 8       | 13      |         | Open Paladin Spellbook      |
| 8       | 14      |         | Open Combat Book            |
| 8       | 15      |         | Open Bushido Spellbook      |
| 8       | 16      |         | Open Ninjutsu Spellbook     |
| 8       | 17      |         | Open Guild                  |
| 8       | 18      |         | Open Spellweaving SpellBook |
| 8       | 19      |         | Open Questlog               |
| 9       | 0       |         | Close Configuration         |
| 9       | 1       |         | Close Paperdoll             |
| 9       | 2       |         | Close Status                |
| 9       | 3       |         | Close Journal               |
| 9       | 4       |         | Close Skills                |
| 9       | 5       |         | Close Spellbook             |
| 9       | 6       |         | Close Chat                  |
| 9       | 7       |         | Close Backpack              |
| 9       | 8       |         | Close Overview              |
| 9       | 9       |         | Close Mail                  |
| 9       | 10      |         | Close Party Manifest        |
| 9       | 11      |         | Close Party Chat            |
| 9       | 12      |         | Close Necro Spellbook       |
| 9       | 13      |         | Close Paladin Spellbook     |
| 9       | 14      |         | Close Combat Book           |
| 9       | 15      |         | Close Bushido Spellbook     |
| 9       | 16      |         | Close Ninjutsu Spellbook    |
| 9       | 17      |         | Close Guild                 |
| 10      | 1       |         | Minimize Paperdoll          |
| 10      | 2       |         | Minimize Status             |
| 10      | 3       |         | Minimize Journal            |
| 10      | 4       |         | Minimize Skills             |
| 10      | 5       |         | Minimize Spellbook          |
| 10      | 6       |         | Minimize Chat               |
| 10      | 7       |         | Minimize Backpack           |
| 10      | 8       |         | Minimize Overview           |
| 10      | 9       |         | Minimize Mail               |
| 10      | 10      |         | Minimize Party Manifest     |
| 10      | 11      |         | Minimize Party Chat         |
| 10      | 12      |         | Minimize Necro Spellbook    |
| 10      | 13      |         | Minimize Paladin Spellbook  |
| 10      | 14      |         | Minimize Combat Book        |
| 10      | 15      |         | Minimize Bushido Spellbook  |
| 10      | 16      |         | Minimize Ninjutsu Spellbook |
| 10      | 17      |         | Minimize Guild              |
| 11      | 1       |         | Maximize Paperdoll          |
| 11      | 2       |         | Maximize Status             |
| 11      | 3       |         | Maximize Journal            |
| 11      | 4       |         | Maximize Skills             |
| 11      | 5       |         | Maximize Spellbook          |
| 11      | 6       |         | Maximize Chat               |
| 11      | 7       |         | Maximize Backpack           |
| 11      | 8       |         | Maximize Overview           |
| 11      | 9       |         | Maximize Mail               |
| 11      | 10      |         | Maximize Party Manifest     |
| 11      | 11      |         | Maximize Party Chat         |
| 11      | 12      |         | Maximize Necro Spellbook    |
| 11      | 13      |         | Maximize Paladin Spellbook  |
| 11      | 14      |         | Maximize Combat Book        |
| 11      | 15      |         | Maximize Bushido Spellbook  |
| 11      | 16      |         | Maximize Ninjutsu Spellbook |
| 11      | 17      |         | Maximize Guild              |

### Open Door

| Param 1 | Param 2 | Param 3 | Description |
|---------|---------|---------|-------------|
| 12      | 0       |         | Opendoor    |

### Use Skills

| Param 1 | Param 2 | Param 3 | Description                       |
|---------|---------|---------|-----------------------------------|
| 13      | 1       |         | Use Skill Anatomy                 |
| 13      | 2       |         | Use Skill Animal Lore             |
| 13      | 35      |         | Use Skill Animal Taming           |
| 13      | 4       |         | Use Skill Arms Lore               |
| 13      | 6       |         | Use Skill Begging                 |
| 13      | 12      |         | Use Skill Cartography             |
| 13      | 14      |         | Use Skill Detecting Hidden        |
| 13      | 15      |         | Use Skill Discordance             |
| 13      | 16      |         | Use Skill Evaluating Intelligence |
| 13      | 19      |         | Use Skill Forensic Evaluation     |
| 13      | 21      |         | Use Skill Hiding                  |
| 13      | 23      |         | Use Skill Inscription             |
| 13      | 3       |         | Use Skill Item Identification     |
| 13      | 46      |         | Use Skill Meditation              |
| 13      | 9       |         | Use Skill Peacemaking             |
| 13      | 30      |         | Use Skill Poisoning               |
| 13      | 22      |         | Use Skill Provocation             |
| 13      | 48      |         | Use Skill Remove Trap             |
| 13      | 32      |         | Use Skill Spirit Speak            |
| 13      | 33      |         | Use Skill Stealing                |
| 13      | 47      |         | Use Skill Stealth                 |
| 13      | 36      |         | Use Skill Taste Identification    |
| 13      | 38      |         | Use Skill Tracking                |
| 13      | 56      |         | Use Skill Imbuing                 |
| 14      | 0       |         | Last Skill                        |

### Magery

| Param 1 | Param 2 | Param 3 | Description                 |
|---------|---------|---------|-----------------------------|
| 15      | 0       |         | Cast Spell Clumsy           |
| 15      | 1       |         | Cast Spell Create Food      |
| 15      | 2       |         | Cast Spell Feeblemind       |
| 15      | 3       |         | Cast Spell Heal             |
| 15      | 4       |         | Cast Spell Magic Arrow      |
| 15      | 5       |         | Cast Spell Night Sight      |
| 15      | 6       |         | Cast Spell Reactive Armor   |
| 15      | 7       |         | Cast Spell Weaken           |
| 15      | 8       |         | Cast Spell Agility          |
| 15      | 9       |         | Cast Spell Cunning          |
| 15      | 10      |         | Cast Spell Cure             |
| 15      | 11      |         | Cast Spell Harm             |
| 15      | 12      |         | Cast Spell Magic Trap       |
| 15      | 13      |         | Cast Spell Magic Untrap     |
| 15      | 14      |         | Cast Spell Protection       |
| 15      | 15      |         | Cast Spell Strength         |
| 15      | 16      |         | Cast Spell Bless            |
| 15      | 17      |         | Cast Spell Fireball         |
| 15      | 18      |         | Cast Spell Magic Lock       |
| 15      | 19      |         | Cast Spell Poison           |
| 15      | 20      |         | Cast Spell Telekinesis      |
| 15      | 21      |         | Cast Spell Teleport         |
| 15      | 22      |         | Cast Spell Unlock           |
| 15      | 23      |         | Cast Spell Wall Of Stone    |
| 15      | 24      |         | Cast Spell Arch Cure        |
| 15      | 25      |         | Cast Spell Arch Protection  |
| 15      | 26      |         | Cast Spell Curse            |
| 15      | 27      |         | Cast Spell Fire Field       |
| 15      | 28      |         | Cast Spell Greater Heal     |
| 15      | 29      |         | Cast Spell Lightning        |
| 15      | 30      |         | Cast Spell Mana Drain       |
| 15      | 31      |         | Cast Spell Recall           |
| 15      | 32      |         | Cast Spell Blade Spirits    |
| 15      | 33      |         | Cast Spell Dispel Field     |
| 15      | 34      |         | Cast Spell Incognito        |
| 15      | 35      |         | Cast Spell Magic Reflection |
| 15      | 36      |         | Cast Spell Mind Blast       |
| 15      | 37      |         | Cast Spell Paralyze         |
| 15      | 38      |         | Cast Spell Poison Field     |
| 15      | 39      |         | Cast Spell Summon Creature  |
| 15      | 40      |         | Cast Spell Dispel           |
| 15      | 41      |         | Cast Spell Energy Bolt      |
| 15      | 42      |         | Cast Spell Explosion        |
| 15      | 43      |         | Cast Spell Invisibility     |
| 15      | 44      |         | Cast Spell Mark             |
| 15      | 45      |         | Cast Spell Mass Curse       |
| 15      | 46      |         | Cast Spell Paralyze Field   |
| 15      | 47      |         | Cast Spell Reveal           |
| 15      | 48      |         | Cast Spell Chain Lightning  |
| 15      | 49      |         | Cast Spell Energy Field     |
| 15      | 50      |         | Cast Spell Flame Strike     |
| 15      | 51      |         | Cast Spell Gate Travel      |
| 15      | 52      |         | Cast Spell Mana Vampire     |
| 15      | 53      |         | Cast Spell Mass Dispel      |
| 15      | 54      |         | Cast Spell Meteor Swarm     |
| 15      | 55      |         | Cast Spell Polymorph        |
| 15      | 56      |         | Cast Spell Earthquake       |
| 15      | 57      |         | Cast Spell Energy Vortex    |
| 15      | 58      |         | Cast Spell Resurrection     |
| 15      | 59      |         | Cast Spell Air Elemental    |
| 15      | 60      |         | Cast Spell Summon Daemon    |
| 15      | 61      |         | Cast Spell Earth Elemental  |
| 15      | 62      |         | Cast Spell Fire Elemental   |
| 15      | 63      |         | Cast Spell Water Elemental  |

### Necromancy

| Param 1 | Param 2 | Param 3 | Description                       |
|---------|---------|---------|-----------------------------------|
| 15      | 101     |         | Cast Spell \[N\] Animate Dead     |
| 15      | 102     |         | Cast Spell \[N\] Blood Oath       |
| 15      | 103     |         | Cast Spell \[N\] Corpse Skin      |
| 15      | 104     |         | Cast Spell \[N\] Curse Weapon     |
| 15      | 105     |         | Cast Spell \[N\] Evil Omen        |
| 15      | 106     |         | Cast Spell \[N\] Horrific Beast   |
| 15      | 107     |         | Cast Spell \[N\] Lich Form        |
| 15      | 108     |         | Cast Spell \[N\] Mind Rot         |
| 15      | 109     |         | Cast Spell \[N\] Pain Spike       |
| 15      | 110     |         | Cast Spell \[N\] Poison Strike    |
| 15      | 111     |         | Cast Spell \[N\] Strangle         |
| 15      | 112     |         | Cast Spell \[N\] Summon Familiar  |
| 15      | 113     |         | Cast Spell \[N\] Vampiric Embrace |
| 15      | 114     |         | Cast Spell \[N\] Vengeful Spirit  |
| 15      | 115     |         | Cast Spell \[N\] Wither           |
| 15      | 116     |         | Cast Spell \[N\] Wraith Form      |
| 15      | 117     |         | Cast Spell \[N\] Exorcism         |

### Bushido

| Param 1 | Param 2 | Param 3 | Description                          |
|---------|---------|---------|--------------------------------------|
| 15      | 145     |         | Cast Spell \[B\] Honorable Execution |
| 15      | 146     |         | Cast Spell \[B\] Confidence          |
| 15      | 147     |         | Cast Spell \[B\] Evasion             |
| 15      | 148     |         | Cast Spell \[B\] Counter Attack      |
| 15      | 149     |         | Cast Spell \[B\] Lightning Strike    |
| 15      | 150     |         | Cast Spell \[B\] Momentum Strike     |

### Chivalry

| Param 1 | Param 2 | Param 3 | Description                        |
|---------|---------|---------|------------------------------------|
| 15      | 201     |         | Cast Spell \[C\] Cleanse By Fire   |
| 15      | 202     |         | Cast Spell \[C\] Close Wounds      |
| 15      | 203     |         | Cast Spell \[C\] Consecrate Weapon |
| 15      | 204     |         | Cast Spell \[C\] Dispel Evil       |
| 15      | 205     |         | Cast Spell \[C\] Divine Fury       |
| 15      | 206     |         | Cast Spell \[C\] Enemy Of One      |
| 15      | 207     |         | Cast Spell \[C\] Holy Light        |
| 15      | 208     |         | Cast Spell \[C\] Noble Sacrifice   |
| 15      | 209     |         | Cast Spell \[C\] Remove Curse      |
| 15      | 210     |         | Cast Spell \[C\] Sacred Journey    |

### Ninja Moves

| Param 1 | Param 2 | Param 3 | Description                       |
|---------|---------|---------|-----------------------------------|
| 15      | 245     |         | Cast Spell \[NI\] Focus Attack    |
| 15      | 246     |         | Cast Spell \[NI\] Death Strike    |
| 15      | 247     |         | Cast Spell \[NI\] Animal Form     |
| 15      | 248     |         | Cast Spell \[NI\] Ki Attack       |
| 15      | 249     |         | Cast Spell \[NI\] Surprise Attack |
| 15      | 250     |         | Cast Spell \[NI\] Backstab        |
| 15      | 251     |         | Cast Spell \[NI\] Shadowjump      |
| 15      | 252     |         | Cast Spell \[NI\] Mirror Image    |

### Spellweaving

| Param 1 | Param 2 | Param 3 | Description                          |
|---------|---------|---------|--------------------------------------|
| 15      | 601     |         | Cast Spell \[SW\] Arcane Circle      |
| 15      | 602     |         | Cast Spell \[SW\] Gift of Renewal    |
| 15      | 603     |         | Cast Spell \[SW\] Immolating Weapon  |
| 15      | 604     |         | Cast Spell \[SW\] Attunement         |
| 15      | 605     |         | Cast Spell \[SW\] Thunderstorm       |
| 15      | 606     |         | Cast Spell \[SW\] Nature's Fury      |
| 15      | 607     |         | Cast Spell \[SW\] Summon Fey         |
| 15      | 608     |         | Cast Spell \[SW\] Summon Fiend       |
| 15      | 609     |         | Cast Spell \[SW\] Reaper Form        |
| 15      | 610     |         | Cast Spell \[SW\] Wildfire           |
| 15      | 611     |         | Cast Spell \[SW\] Essence of Wind    |
| 15      | 612     |         | Cast Spell \[SW\] Dryad Allure       |
| 15      | 613     |         | Cast Spell \[SW\] Ethereal Voyage    |
| 15      | 614     |         | Cast Spell \[SW\] Word of Death      |
| 15      | 615     |         | Cast Spell \[SW\] Gift of Life       |
| 15      | 616     |         | Cast Spell \[SW\] Arcane Empowerment |

### Mysticism

| Param 1 | Param 2 | Param 3 | Description                |
|---------|---------|---------|----------------------------|
| 15      | 678     |         | Cast Spell Nether Bolt     |
| 15      | 679     |         | Cast Spell Healing Stone   |
| 15      | 680     |         | Cast Spell Purge Magic     |
| 15      | 681     |         | Cast Spell Enchant         |
| 15      | 682     |         | Cast Spell Sleep           |
| 15      | 683     |         | Cast Spell Eagle Stike     |
| 15      | 684     |         | Cast Spell Animated Weapon |
| 15      | 685     |         | Cast Spell Stone Form      |
| 15      | 686     |         | Cast Spell Spell Trigger   |
| 15      | 687     |         | Cast Spell Mass Sleep      |
| 15      | 688     |         | Cast Spell Cleaning Winds  |
| 15      | 689     |         | Cast Spell Bombard         |
| 15      | 690     |         | Cast Spell Spell Plague    |
| 15      | 691     |         | Cast Spell Hail Storm      |
| 15      | 692     |         | Cast Spell Nether Cyclone  |
| 15      | 693     |         | Cast Spell Rising Colossus |

### Miscellaneous

| Param 1 | Param 2 | Param 3 | Description       |
|---------|---------|---------|-------------------|
| 16      | 0       |         | Last Spell        |
| 17      | 0       |         | Last Object       |
| 18      | 0       |         | Bow               |
| 19      | 0       |         | Salute            |
| 20      | 0       |         | Quit Game         |
| 21      | 0       |         | All Names         |
| 22      | 0       |         | Last Target       |
| 23      | 0       |         | Target Self       |
| 24      | 1       |         | Arm/Disarm Left   |
| 24      | 2       |         | Arm/Disarm Right  |
| 25      | 0       |         | Wait For Target   |
| 26      | 0       |         | Target Next       |
| 27      | 0       |         | Attack Last       |
| 28      | 0       | ^       | Delay             |
| 29      | 0       |         | Circletrans       |
| 31      | 0       |         | Close Gumps       |
| 32      | 0       |         | Always Run        |
| 33      | 0       |         | Save Desktop      |
| 34      | 0       |         | Kill Gump Open    |
| 35      | 0       |         | Primary Ability   |
| 36      | 0       |         | Secondary Ability |
| 37      | 0       |         | Equip Last Weapon |

### Client's Range Control

| Param 1 | Param 2 | Param 3 | Description                |
|---------|---------|---------|----------------------------|
| 38      | 0       | ^       | Set Update Range           |
| 39      | 0       | ^       | Modify Update Range        |
| 40      | 0       |         | Increase Update Range      |
| 41      | 0       |         | Decrease Update Range      |
| 42      | 0       |         | Maximum Update Range       |
| 43      | 0       |         | Minimum Update Range       |
| 44      | 0       |         | Default Update Range       |
| 45      | 0       |         | Update Update Range        |
| 46      | 0       |         | Enable Update Range Color  |
| 47      | 0       |         | Disable Update Range Color |
| 48      | 0       |         | Toggle Update Range Color  |

### Invoke Virtues

| Param 1 | Param 2 | Param 3 | Description                             |
|---------|---------|---------|-----------------------------------------|
| 49      | 1       |         | Invoke Honor Virtue                     |
| 49      | 2       |         | Invoke Sacrifice Virtue                 |
| 49      | 3       |         | Invoke Valor Virtue                     |
| 49      | 4       |         | Invoke Compassion Virtue (Does Nothing) |
| 49      | 5       |         | Invoke \*1 Virtue                       |
| 49      | 6       |         | Invoke \*1 Virtue                       |
| 49      | 7       |         | Invoke Justice Protection               |
| 49      | 8       |         | Invoke \*1 Virtue                       |

\*1: Humility, Honesty and Spirituality, in an unknown order. They currently do nothing.

### Targeting System

| Param 1 | Param 2 | Param 3 | Description                     |
|---------|---------|---------|---------------------------------|
| 50      | 1-5\*   |         | select next                     |
| 51      | 1-5\*   |         | select previous                 |
| 52      | 1-5\*   |         | select nearest                  |
| 53      |         |         | attack selected                 |
| 54      |         |         | use selected                    |
| 55      |         |         | current target                  |
| 56      |         |         | targeting system on/off         |
| 57      |         |         | toggle buff window (open/close), see [`#BuffBarOpen`](/variables/buffbaropen/) |
| 58      |         |         | bandage self                    |
| 59      |         |         | bandage target                  |

The targeting system macros set [`#LTargetID`](/variables/ltargetid/) and show the current target's health bar.

\*Parameter 2 chooses what to cycle through: `1` hostile, `2` party members, `3` followers, `4` objects,
`5` mobiles.

### Gargoyle

| Param 1 | Param 2 | Param 3 | Description         |
|---------|---------|---------|---------------------|
| 60      |         |         | toggle gargoyle fly |

## Examples

```euo
event Macro 1 0 Hello everyone        ; say
event Macro 8 7                        ; open the backpack
```

Dig with a shovel at a spot on the ground:

```euo
set #LObjectID %shovel
event Macro 17 0                       ; use the last object: the shovel
target 5s
set #LTargetX 1000
set #LTargetY 1000
set #LTargetKind 3
event Macro 22 0                       ; target the last target: the ground at 1000,1000
```
