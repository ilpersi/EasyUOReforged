---
title: "event Macro"
description: "Runs one of the client's built-in macros: speech, gumps, skills, spells, targeting, dress sets, potions."
kind: subcommand
category: event
syntax: "event Macro {macro} [parameter] [text]"
needsClient: true
related: ["#LObjectID", "#LTargetID", "#LTargetKind", "#LSkill", "#LSpell", "#LHandID", "#RHandID", "Target", "Msg"]
aliases: ["client macro", "use skill", "cast spell", "open backpack", "spell words", "reagents", "dress", "drink potion", "bandage"]
dll: Macro
source: wiki
---

`event Macro` makes the client run one of its built-in macros, the same ones you can bind to keys in the
client's options: speak, open a gump, use a skill, cast a spell, target, and so on.

## Parameters

| Parameter | Meaning |
|---|---|
| `macro` | Which macro, `1` to `67`: see the tables below. Any other number does nothing. |
| `parameter` | Optional. Selects a variant: which gump to open, which skill or spell. Default: `0`. Macros without variants ignore it. |
| `text` | Optional. Only macros `1` to `4` (speech), `28`, `38` and `39` read it. When you give text, write the `parameter` too, even if it is `0`. |

The macros that use something "last" ([`#LObjectID`](/variables/lobjectid/), [`#LTargetID`](/variables/ltargetid/),
[`#LSkill`](/variables/lskill/), [`#LSpell`](/variables/lspell/), [`#LHandID`](/variables/lhandid/),
[`#RHandID`](/variables/rhandid/)) read those variables, so set them first to choose what the macro acts on.

The command calls a function inside the client. On a client version where that function's address is not
known, it does nothing.

## Macro numbers

### Speech

| Macro | Parameter | Text | Description |
|---|---|---|---|
| 1 | 0 | text | Say |
| 2 | 0 | text | Emote |
| 3 | 0 | text | Whisper |
| 4 | 0 | text | Yell |

The parameter is not used.

### Movement

| Macro | Parameter | Description |
|---|---|---|
| 5 | 0 | Walk north-west |
| 5 | 1 | Walk north |
| 5 | 2 | Walk north-east |
| 5 | 3 | Walk east |
| 5 | 4 | Walk south-east |
| 5 | 5 | Walk south |
| 5 | 6 | Walk south-west |
| 5 | 7 | Walk west |

One step in that direction. The parameter is [`#CharDir`](/variables/chardir/) plus one: north is `1` here and
`0` there, north-west `0` here and `7` there. If your character is following someone, it stops first.

### War/Peace & Paste

| Macro | Parameter | Description |
|---|---|---|
| 6 | 0 | Toggle war/peace |
| 7 | 0 | Paste the clipboard |

### Gump Control

Macros `8` to `11` open, close, minimize and maximize a gump. The parameter says which:

| Parameter | Gump | Open (8) | Close (9) | Minimize (10) | Maximize (11) |
|---|---|---|---|---|---|
| 0 | Configuration | yes | yes | closes it | opens it |
| 1 | Paperdoll | yes | yes | yes | yes |
| 2 | Status | yes | yes | yes | yes |
| 3 | Journal | yes | yes | yes | yes |
| 4 | Skills | yes | yes | yes | yes |
| 5 | Spellbook (Magery) | yes | yes | yes | yes |
| 6 | Chat (the old chat) | — | yes | yes | yes |
| 7 | Backpack | yes | yes | yes | yes |
| 8 | Overview | yes | yes | yes | yes |
| 9 | Mail | yes | yes | yes | yes |
| 10 | Party Manifest | yes | yes | closes it | opens it |
| 11 | Party Chat | yes | — | yes | yes |
| 12 | Necro Spellbook | yes | yes | yes | yes |
| 13 | Paladin Spellbook | yes | yes | yes | yes |
| 14 | Combat Book | yes | yes | yes | yes |
| 15 | Bushido Spellbook | yes | yes | yes | yes |
| 16 | Ninjitsu Spellbook | yes | yes | yes | yes |
| 17 | Guild | yes | — | — | — |
| 18 | Spellweaving Spellbook | yes | yes | yes | yes |
| 19 | Questlog | yes | — | — | — |
| 20 | Mysticism Spellbook | yes | yes | yes | yes |
| 21 | Racial Abilities Book | yes | yes | yes | yes |
| 22 | Bard Spellbook (Masteries) | yes | yes | yes | yes |
| 23 | Global Chat | yes | yes | yes | yes |

"—" means the client does nothing for that combination. Close, minimize and maximize act on the gump only
while it is open. Opening the status (`2`) or skills (`4`) gump also asks the server for fresh values.

### Open Door

| Macro | Parameter | Description |
|---|---|---|
| 12 | 0 | Open the door next to you |

### Use Skills

| Macro | Parameter | Description |
|---|---|---|
| 13 | 1 | Use Skill Anatomy |
| 13 | 2 | Use Skill Animal Lore |
| 13 | 35 | Use Skill Animal Taming |
| 13 | 4 | Use Skill Arms Lore |
| 13 | 6 | Use Skill Begging |
| 13 | 12 | Use Skill Cartography |
| 13 | 14 | Use Skill Detecting Hidden |
| 13 | 15 | Use Skill Discordance |
| 13 | 16 | Use Skill Evaluating Intelligence |
| 13 | 19 | Use Skill Forensic Evaluation |
| 13 | 21 | Use Skill Hiding |
| 13 | 23 | Use Skill Inscription |
| 13 | 3 | Use Skill Item Identification |
| 13 | 46 | Use Skill Meditation |
| 13 | 9 | Use Skill Peacemaking |
| 13 | 30 | Use Skill Poisoning |
| 13 | 22 | Use Skill Provocation |
| 13 | 48 | Use Skill Remove Trap |
| 13 | 32 | Use Skill Spirit Speak |
| 13 | 33 | Use Skill Stealing |
| 13 | 47 | Use Skill Stealth |
| 13 | 36 | Use Skill Taste Identification |
| 13 | 38 | Use Skill Tracking |
| 13 | 56 | Use Skill Imbuing |
| 14 | 0 | Last Skill: uses [`#LSkill`](/variables/lskill/) again |

The parameter is the skill's number, sent to the server as it is. The list shows the skills that can be used;
the server refuses the others.

### Casting

| Macro | Parameter | Description |
|---|---|---|
| 15 | spell | Cast the spell: the numbers are under [Spells](#spells) |
| 16 | 0 | Last Spell: casts [`#LSpell`](/variables/lspell/) again |

### Miscellaneous

| Macro | Parameter | Text | Description |
|---|---|---|---|
| 17 | 0 | | Last Object: double-clicks [`#LObjectID`](/variables/lobjectid/) |
| 18 | 0 | | Bow |
| 19 | 0 | | Salute |
| 20 | 0 | | Quit Game: opens the "Quit Ultima Online?" box |
| 21 | 0 | | All Names: shows the names of the mobiles and corpses on screen |
| 22 | 0 | | Last Target |
| 23 | 0 | | Target Self |
| 24 | 1 | | Arm/Disarm Left |
| 24 | 2 | | Arm/Disarm Right |
| 25 | 0 | | Wait For Target |
| 26 | 0 | | Target Next: selects the next mobile on screen, one after the other |
| 27 | 0 | | Attack Last: attacks [`#LTargetID`](/variables/ltargetid/) |
| 28 | 0 | number | Delay |
| 29 | 0 | | Circletrans: toggles the circle of transparency |
| 31 | 0 | | Close Gumps |
| 32 | 0 | | Always Run: toggles it |
| 33 | 0 | | Save Desktop |
| 34 | 0 | | Kill Gump Open: cancels the containers still waiting to open |
| 35 | 0 | | Primary Ability: your weapon's primary special move |
| 36 | 0 | | Secondary Ability: your weapon's secondary special move |
| 37 | 0 | | Equip Last Weapon |

- **Last Target** (`22`) and **Target Self** (`23`) only work while a target cursor is up. Last Target targets
  what [`#LTargetKind`](/variables/ltargetkind/) says: `1` the object [`#LTargetID`](/variables/ltargetid/), `2` the
  ground at [`#LTargetX`](/variables/ltargetx/), [`#LTargetY`](/variables/ltargety/), [`#LTargetZ`](/variables/ltargetz/),
  `3` the static [`#LTargetTile`](/variables/ltargettile/) at that spot.
- **Arm/Disarm** (`24`): `1` is the left hand (shield or two-handed weapon), `2` the right hand. With something in
  that hand, the client saves its ID in [`#LHandID`](/variables/lhandid/) or [`#RHandID`](/variables/rhandid/) and
  takes it off; with the hand empty, it equips the item whose ID is saved there.
- **Wait For Target** (`25`) and **Delay** (`28`) only affect the macro sequences the client plays itself. From a
  script they have no visible effect: use [`Target`](/commands/target/) and [`Wait`](/commands/wait/) instead.
- `30` is in the client's list of macros, but the client does nothing for it.

### Client's Range Control

| Macro | Parameter | Text | Description |
|---|---|---|---|
| 38 | 0 | number | Set Update Range to the number |
| 39 | 0 | number | Modify Update Range: adds the number (negative lowers it) |
| 40 | 0 | | Increase Update Range by 1 |
| 41 | 0 | | Decrease Update Range by 1 |
| 42 | 0 | | Maximum Update Range: 24 if the game window is bigger than 800×600, otherwise 18 |
| 43 | 0 | | Minimum Update Range: 5 |
| 44 | 0 | | Default Update Range: the same as `42` |
| 45 | 0 | | Update Range Info: shows the current range in the system messages |
| 46 | 0 | | Enable Update Range Color |
| 47 | 0 | | Disable Update Range Color |
| 48 | 0 | | Toggle Update Range Color |

### Invoke Virtues

| Macro | Parameter | Description |
|---|---|---|
| 49 | 1 | Invoke Honor Virtue |
| 49 | 2 | Invoke Sacrifice Virtue |
| 49 | 3 | Invoke Valor Virtue |

These are the virtues the client offers. It sends any other number to the server as it is: what that does
depends on the server.

### Targeting System

| Macro | Parameter | Description |
|---|---|---|
| 50 | 1-5\* | select next |
| 51 | 1-5\* | select previous |
| 52 | 1-5\* | select nearest |
| 53 | 0 | attack selected |
| 54 | 0 | use selected: double-clicks it |
| 55 | 0 | current target: targets the selected one, while a target cursor is up |
| 56 | 0 | targeting system on/off |
| 57 | 0 | toggle buff window (open/close), see [`#BuffBarOpen`](/variables/buffbaropen/) |
| 58 | 0 | bandage self |
| 59 | 0 | bandage target: bandages the selected one |

The targeting system macros set [`#LTargetID`](/variables/ltargetid/) and show the current target's health bar.

\*Parameter 2 chooses what to cycle through: `1` hostile, `2` party members, `3` followers, `4` objects,
`5` mobiles. `0` is the same as `1`.

While the targeting system is off (`56`), macros `50` to `55`, `58` and `59` do nothing. While you are dragging
an item, `50` to `55` do nothing either. The bandage macros use a bandage from your backpack.

### Gargoyle

| Macro | Parameter | Description |
|---|---|---|
| 60 | 0 | toggle gargoyle fly (gargoyles only) |

### Dress and Arm Sets

| Macro | Parameter | Description |
|---|---|---|
| 61 | 1-4 | Record Dress: saves what you wear now as that dress set |
| 62 | 0 | Undress: takes off what you wear |
| 63 | 1-4 | Dress: puts on the items of that dress set |
| 64 | 1-4 | Record Arm: saves what you hold in both hands as that arm set |
| 65 | 0 | Disarm: takes off what you hold in both hands |
| 66 | 1-4 | Arm: equips the items of that arm set |

The client keeps four dress sets and four arm sets in its macros file, so they last after a restart. A dress
set holds your clothes, armor and jewelry, not what you hold, your hair or your backpack. Undress also leaves
your hands as they are. The sets save item IDs: they work with those very items.

### Use Object

| Macro | Parameter | Description |
|---|---|---|
| 67 | 1 | Heal potion: greater, else normal, else lesser |
| 67 | 2 | Cure potion: greater, else normal, else lesser |
| 67 | 3 | Refresh potion: greater (total refresh), else normal |
| 67 | 4 | Strength potion: greater, else normal |
| 67 | 5 | Agility potion: greater, else normal |
| 67 | 6 | Explosion potion: greater, else normal, else lesser |
| 67 | 7 | Conflagration potion: greater, else normal |
| 67 | 8 | Enchanted apple |
| 67 | 9 | Petal of the Rose of Trinsic |
| 67 | 10 | Orange petals |
| 67 | 11 | Trapped box: a small crate or wooden box |
| 67 | 12 | Smoke bomb |
| 67 | 13 | Healing stone |
| 67 | 14 | Spell stone (Spell Trigger) |

The client looks for the item in your backpack, not in the bags inside it, and double-clicks it. It finds the
items by name; for the trapped box it takes any small crate or wooden box, trapped or not.

Arm/Disarm (`24`), the bandage macros (`58`, `59`) and macros `61` to `67` do nothing while you are dragging
an item.

## Spells

`event Macro 15` casts the spell with the number in these tables. *Words* are the words of power the client's
spellbook shows; the words your character says aloud come from the server, and some servers use other ones.

[`#LSpell`](/variables/lspell/) and `event Macro 16` use the client's own numbers, which differ in three schools:
Magery counts from `1` there (Clumsy is `1`, Water Elemental `64`), Bushido from `401` and Ninjitsu from `501`.
`event Macro 15` accepts Bushido and Ninjitsu either way.

### Magery

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 0 | Clumsy | Uus Jux | Bloodmoss, Nightshade |
| 1 | Create Food | In Mani Ylem | Garlic, Ginseng, Mandrake Root |
| 2 | Feeblemind | Rel Wis | Ginseng, Nightshade |
| 3 | Heal | In Mani | Garlic, Ginseng, Spiders' Silk |
| 4 | Magic Arrow | In Por Ylem | Sulfurous Ash |
| 5 | Night Sight | In Lor | Spiders' Silk, Sulfurous Ash |
| 6 | Reactive Armor | Sanct Flam | Garlic, Sulfurous Ash, Spiders' Silk |
| 7 | Weaken | Des Mani | Garlic, Nightshade |
| 8 | Agility | Ex Uus | Bloodmoss, Mandrake Root |
| 9 | Cunning | Uus Wis | Mandrake Root, Nightshade |
| 10 | Cure | An Nox | Garlic, Ginseng |
| 11 | Harm | An Mani | Nightshade, Spiders' Silk |
| 12 | Magic Trap | In Jux | Garlic, Sulfurous Ash, Spiders' Silk |
| 13 | Magic Untrap | An Jux | Bloodmoss, Sulfurous Ash |
| 14 | Protection | Uus Sanct | Garlic, Ginseng, Sulfurous Ash |
| 15 | Strength | Uus Mani | Mandrake Root, Nightshade |
| 16 | Bless | Rel Sanct | Garlic, Mandrake Root |
| 17 | Fireball | Vas Flam | Black Pearl |
| 18 | Magic Lock | An Por | Sulfurous Ash, Bloodmoss, Garlic |
| 19 | Poison | In Nox | Nightshade |
| 20 | Telekinesis | Ort Por Ylem | Bloodmoss, Mandrake Root |
| 21 | Teleport | Rel Por | Bloodmoss, Mandrake Root |
| 22 | Unlock | Ex Por | Bloodmoss, Sulfurous Ash |
| 23 | Wall of Stone | In Sanct Ylem | Bloodmoss, Garlic |
| 24 | Arch Cure | Vas An Nox | Garlic, Ginseng, Mandrake Root |
| 25 | Arch Protection | Vas Uus Sanct | Garlic, Ginseng, Mandrake Root, Sulfurous Ash |
| 26 | Curse | Des Sanct | Garlic, Nightshade, Sulfurous Ash |
| 27 | Fire Field | In Flam Grav | Black Pearl, Spiders' Silk, Sulfurous Ash |
| 28 | Greater Heal | In Vas Mani | Garlic, Ginseng, Mandrake Root, Spiders' Silk |
| 29 | Lightning | Por Ort Grav | Mandrake Root, Sulfurous Ash |
| 30 | Mana Drain | Ort Rel | Black Pearl, Mandrake Root, Spiders' Silk |
| 31 | Recall | Kal Ort Por | Black Pearl, Bloodmoss, Mandrake Root |
| 32 | Blade Spirits | In Jux Hur Ylem | Black Pearl, Mandrake Root, Nightshade |
| 33 | Dispel Field | An Grav | Garlic, Black Pearl, Spiders' Silk, Sulfurous Ash |
| 34 | Incognito | Kal In Ex | Bloodmoss, Garlic, Nightshade |
| 35 | Magic Reflection | In Jux Sanct | Garlic, Mandrake Root, Spiders' Silk |
| 36 | Mind Blast | Por Corp Wis | Black Pearl, Mandrake Root, Nightshade, Sulfurous Ash |
| 37 | Paralyze | An Ex Por | Garlic, Mandrake Root, Spiders' Silk |
| 38 | Poison Field | In Nox Grav | Black Pearl, Nightshade, Spiders' Silk |
| 39 | Summon Creature | Kal Xen | Bloodmoss, Mandrake Root, Spiders' Silk |
| 40 | Dispel | An Ort | Garlic, Mandrake Root, Sulfurous Ash |
| 41 | Energy Bolt | Corp Por | Black Pearl, Nightshade |
| 42 | Explosion | Vas Ort Flam | Bloodmoss, Mandrake Root |
| 43 | Invisibility | An Lor Xen | Bloodmoss, Nightshade |
| 44 | Mark | Kal Por Ylem | Black Pearl, Bloodmoss, Mandrake Root |
| 45 | Mass Curse | Vas Des Sanct | Garlic, Mandrake Root, Nightshade, Sulfurous Ash |
| 46 | Paralyze Field | In Ex Grav | Black Pearl, Ginseng, Spiders' Silk |
| 47 | Reveal | Wis Quas | Bloodmoss, Sulfurous Ash |
| 48 | Chain Lightning | Vas Ort Grav | Black Pearl, Mandrake Root, Bloodmoss, Sulfurous Ash |
| 49 | Energy Field | In Sanct Grav | Black Pearl, Mandrake Root, Spiders' Silk, Sulfurous Ash |
| 50 | Flame Strike | Kal Vas Flam | Spiders' Silk, Sulfurous Ash |
| 51 | Gate Travel | Vas Rel Por | Black Pearl, Mandrake Root, Sulfurous Ash |
| 52 | Mana Vampire | Ort Sanct | Black Pearl, Bloodmoss, Mandrake Root, Spiders' Silk |
| 53 | Mass Dispel | Vas An Ort | Black Pearl, Garlic, Mandrake Root, Sulfurous Ash |
| 54 | Meteor Swarm | Kal Des Flam Ylem | Bloodmoss, Spiders' Silk, Mandrake Root, Sulfurous Ash |
| 55 | Polymorph | Vas Ylem Rel | Bloodmoss, Mandrake Root, Spiders' Silk |
| 56 | Earthquake | In Vas Por | Bloodmoss, Ginseng, Mandrake Root, Sulfurous Ash |
| 57 | Energy Vortex | Vas Corp Por | Black Pearl, Bloodmoss, Mandrake Root, Nightshade |
| 58 | Resurrection | An Corp | Bloodmoss, Garlic, Ginseng |
| 59 | Air Elemental | Kal Vas Xen Hur | Bloodmoss, Mandrake Root, Spiders' Silk |
| 60 | Summon Daemon | Kal Vas Xen Daem | Bloodmoss, Mandrake Root, Spiders' Silk, Sulfurous Ash |
| 61 | Earth Elemental | Kal Vas Xen Tera | Bloodmoss, Mandrake Root, Spiders' Silk |
| 62 | Fire Elemental | Kal Vas Xen Flam | Bloodmoss, Mandrake Root, Spiders' Silk, Sulfurous Ash |
| 63 | Water Elemental | Kal Vas Xen Aqua | Bloodmoss, Mandrake Root, Spiders' Silk |

### Necromancy

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 101 | Animate Dead | Uus Corp | Daemon Blood, Grave Dust |
| 102 | Blood Oath | In Jux Mani Xen | Daemon Blood |
| 103 | Corpse Skin | In Aglo Corp Ylem | Batwing, Grave Dust |
| 104 | Curse Weapon | An Sanct Gra Char | Pig Iron |
| 105 | Evil Omen | Pas Tym An Sanct | Batwing, Nox Crystal |
| 106 | Horrific Beast | Rel Xen Vas Bal | Batwing, Daemon Blood |
| 107 | Lich Form | Rel Xen Corp Ort | Nox Crystal, Daemon Blood, Grave Dust |
| 108 | Mind Rot | Wis An Ben | Batwing, Daemon Blood, Pig Iron |
| 109 | Pain Spike | In Sar | Grave Dust, Pig Iron |
| 110 | Poison Strike | In Vas Nox | Nox Crystal |
| 111 | Strangle | In Bal Nox | Nox Crystal, Daemon Blood |
| 112 | Summon Familiar | Kal Xen Bal | Batwing, Grave Dust, Daemon Blood |
| 113 | Vampiric Embrace | Rel Xen An Sanct | Batwing, Nox Crystal, Pig Iron |
| 114 | Vengeful Spirit | Kal Xen Bal Beh | Batwing, Grave Dust, Pig Iron |
| 115 | Wither | Kal Vas An Flam | Nox Crystal, Grave Dust, Pig Iron |
| 116 | Wraith Form | Rel Xen Um | Nox Crystal, Pig Iron |
| 117 | Exorcism | Ort Corp Grav | Nox Crystal, Grave Dust |

### Chivalry

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 201 | Cleanse by Fire | Expor Flamus | — |
| 202 | Close Wounds | Obsu Vulni | — |
| 203 | Consecrate Weapon | Consecrus Arma | — |
| 204 | Dispel Evil | Dispiro Malas | — |
| 205 | Divine Fury | Divinum Furis | — |
| 206 | Enemy of One | Forul Solum | — |
| 207 | Holy Light | Augus Luminos | — |
| 208 | Noble Sacrifice | Dium Prostra | — |
| 209 | Remove Curse | Extermo Vomica | — |
| 210 | Sacred Journey | Sanctum Viatas | — |

### Bushido

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 145 or 401 | Honorable Execution | — | — |
| 146 or 402 | Confidence | — | — |
| 147 or 403 | Evasion | — | — |
| 148 or 404 | Counter Attack | — | — |
| 149 or 405 | Lightning Strike | — | — |
| 150 or 406 | Momentum Strike | — | — |

### Ninjitsu

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 245 or 501 | Focus Attack | — | — |
| 246 or 502 | Death Strike | — | — |
| 247 or 503 | Animal Form | — | — |
| 248 or 504 | Ki Attack | — | — |
| 249 or 505 | Surprise Attack | — | — |
| 250 or 506 | Backstab | — | — |
| 251 or 507 | Shadowjump | — | — |
| 252 or 508 | Mirror Image | — | — |

### Spellweaving

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 601 | Arcane Circle | Myrshalee | — |
| 602 | Gift of Renewal | Olorisstra | — |
| 603 | Immolating Weapon | Thalshara | — |
| 604 | Attunement | Haeldril | — |
| 605 | Thunderstorm | Erelonia | — |
| 606 | Nature's Fury | Rauvvrae | — |
| 607 | Summon Fey | Alalithra | — |
| 608 | Summon Fiend | Nylisstra | — |
| 609 | Reaper Form | Tarisstree | — |
| 610 | Wildfire | Haelyn | — |
| 611 | Essence of Wind | Anathrae | — |
| 612 | Dryad Allure | Rathril | — |
| 613 | Ethereal Voyage | Orlavdra | — |
| 614 | Word of Death | Nyraxle | — |
| 615 | Gift of Life | Illorae | — |
| 616 | Arcane Empowerment | Aslavdra | — |

### Mysticism

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 678 | Nether Bolt | In Corp Ylem | Black Pearl, Sulfurous Ash |
| 679 | Healing Stone | Kal In Mani | Bone, Garlic, Ginseng, Spiders' Silk |
| 680 | Purge Magic | An Ort Sanct | Fertile Dirt, Garlic, Mandrake Root, Sulfurous Ash |
| 681 | Enchant | In Ort Ylem | Spiders' Silk, Mandrake Root, Sulfurous Ash |
| 682 | Sleep | In Zu | Nightshade, Spiders' Silk, Black Pearl |
| 683 | Eagle Strike | Kal Por Xen | Bloodmoss, Bone, Spiders' Silk, Mandrake Root |
| 684 | Animated Weapon | In Jux Por Ylem | Bone, Black Pearl, Mandrake Root, Nightshade |
| 685 | Stone Form | In Rel Ylem | Bloodmoss, Fertile Dirt, Garlic |
| 686 | Spell Trigger | In Vas Ort Ex | Dragon's Blood, Garlic, Mandrake Root, Spiders' Silk |
| 687 | Mass Sleep | Vas Zu | Ginseng, Nightshade, Spiders' Silk |
| 688 | Cleansing Winds | In Vas Mani Hur | Dragon's Blood, Garlic, Ginseng, Mandrake Root |
| 689 | Bombard | Corp Por Ylem | Bloodmoss, Dragon's Blood, Garlic, Sulfurous Ash |
| 690 | Spell Plague | Vas Rel Jux Ort | Daemon Bone, Dragon's Blood, Nightshade, Sulfurous Ash |
| 691 | Hail Storm | Kal Des Ylem | Dragon's Blood, Bloodmoss, Black Pearl, Mandrake Root |
| 692 | Nether Cyclone | Grav Hur | Mandrake Root, Nightshade, Sulfurous Ash, Bloodmoss |
| 693 | Rising Colossus | Kal Vas Xen Corp Ylem | Daemon Bone, Dragon's Blood, Fertile Dirt, Nightshade |

### Masteries

| Parameter | Spell | Words | Reagents |
|---|---|---|---|
| 701 | Inspire | Uus Por | — |
| 702 | Invigorate | An Zu | — |
| 703 | Resilience | Kal Mani Tym | — |
| 704 | Perseverance | Uus Jux Sanct | — |
| 705 | Tribulation | In Jux Hur Rel | — |
| 706 | Despair | Kal Des Mani Tym | — |
| 707 | Death Ray | In Grav Corp | Black Pearl, Bloodmoss, Spiders' Silk |
| 708 | Ethereal Burst | Uus Ort Grav | Bloodmoss, Ginseng, Mandrake Root |
| 709 | Nether Blast | In Vas Xen Por | Dragon's Blood, Daemon Bone |
| 710 | Mystic Weapon | Vas Ylem Wis | Fertile Dirt, Bone |
| 711 | Command Undead | In Corp Xen Por | Daemon Blood, Pig Iron, Batwing |
| 712 | Conduit | Uus Corp Grav | Nox Crystal, Batwing, Grave Dust |
| 713 | Mana Shield | Faerkulggen | — |
| 714 | Summon Reaper | Lartarisstree | — |
| 715 | Enchanted Summoning (passive) | — | — |
| 716 | Anticipate Hit (passive) | — | — |
| 717 | Warcry | — | — |
| 718 | Intuition (passive) | — | — |
| 719 | Rejuvenate | — | — |
| 720 | Holy Fist | — | — |
| 721 | Shadow | — | — |
| 722 | White Tiger Form | — | — |
| 723 | Flaming Shot | — | — |
| 724 | Playing The Odds | — | — |
| 725 | Thrust | — | — |
| 726 | Pierce | — | — |
| 727 | Stagger | — | — |
| 728 | Toughness | — | — |
| 729 | Onslaught | — | — |
| 730 | Focused Eye | — | — |
| 731 | Elemental Fury | — | — |
| 732 | Called Shot | — | — |
| 733 | Warrior's Gifts (passive) | — | — |
| 734 | Shield Bash | — | — |
| 735 | Bodyguard | — | — |
| 736 | Heighten Senses | — | — |
| 737 | Tolerance | — | — |
| 738 | Injected Strike | — | — |
| 739 | Potency (passive) | — | — |
| 740 | Rampage | — | — |
| 741 | Fists of Fury | — | — |
| 742 | Knockout (passive) | — | — |
| 743 | Whispering | — | — |
| 744 | Combat Training | — | — |
| 745 | Boarding (passive) | — | — |

## Examples

```euo
event Macro 1 0 Hello everyone        ; say
event Macro 8 7                        ; open the backpack
event Macro 15 50                      ; cast Flame Strike
```

Dig with a shovel at a spot on the ground:

```euo
set #LObjectID %shovel
event Macro 17 0                       ; use the last object: the shovel
target 5s
set #LTargetX 1000
set #LTargetY 1000
set #LTargetZ #CharPosZ
set #LTargetKind 2
event Macro 22 0                       ; target the last target: the ground at 1000,1000
```

Swap to a saved set of clothes and back, and drink a heal potion:

```euo
event Macro 61 1                       ; save what you wear now as dress set 1
event Macro 62 0                       ; undress
wait 2s
event Macro 63 1                       ; dress set 1 again
event Macro 67 1                       ; drink the best heal potion in the backpack
```
