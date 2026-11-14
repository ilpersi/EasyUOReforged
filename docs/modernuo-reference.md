# ModernUO reference for EasyUO probes and tests

Status: written on 2026-11-14 from ModernUO's source and the self-test hand test (2026-11-13/14). No code was
changed. Its purpose: someone (or an agent) building a probe (`tests/tools/*.euo`) or a feature test against a
ModernUO shard should not have to rediscover how the shard behaves.

## How to use this

Find the behaviour your check depends on before you write the check. Every claim says where it comes from:

- **src**: ModernUO's source, as `path` `Type.Member`. Paths are relative to `D:\ModernUo\modernuo\Projects\`
  (checkout at commit `c9875e7f`, 2026-08-31). The owner's shard build was **not** compared with this checkout.
- **live _id_**: seen on the owner's client.exe 7.0.117.33 on the local shard, in self-test check _id_ (the report
  lines are in the self-test session's transcript; the IDs are those of `tools/EUOSelfTest/README.md`).
- **inferred**: follows from the two above, but nobody saw it directly.
- **client**: belongs to the client, not to ModernUO (section 6).

The test set-up those live results come from: a local ModernUO shard, a staff character with serial 1 (so
`#CharID` = `XC`) whose `AccessLevel` is **Owner** (live 4.02; everything this page says of "GameMaster or
above" applies to it), test spot 1057/520/-90 on Malas (facet 3), a giant beetle the character rides (3
control slots). Most results below hold only for a staff character; section 3.1 lists what changes for a
player.

Two house rules for anything that runs on the owner's client: a script handed over for a hand test ends with
`halt` (reaching the end restarts it), and nothing runs on the live client without the owner's yes for that
script.

## 1. Staff command cookbook

### 1.1 How the shard reads a command line

| Fact | Source |
|---|---|
| The prefix is `[` by default; a shard can change it with the setting `commandsystem.prefix`. | src `UOContent/Commands/Handlers.cs` `CommandHandlers.Configure`; `Server/Commands.cs` `CommandSystem.Prefix` |
| The command name ignores case. Arguments are split on spaces; `"two words"` is one argument. | src `Server/Commands.cs` `CommandSystem.Entries` (`OrdinalIgnoreCase`), `CommandSystem.Split` |
| A command the shard handles is **not spoken**: nothing of it reaches the journal, only the answer. | src `Server/Mobiles/Mobile.cs` `Mobile.DoSpeech` (returns when `CommandSystem.Handle` is true) |
| From a **Player** the shard does not handle the line (`BadCommandIgnoreLevel` = Player): it is **said aloud** like any speech. Check the access level before sending commands (the self-test's `st_staff_probe`). | src `Server/Commands.cs` `CommandSystem.Handle` |
| The shard drops a speech line longer than 128 characters, whole and without an answer. | src `UOContent/Network/Packets/IncomingMessagePackets.cs` `UnicodeSpeech` (`text.Length is <= 0 or > 128`) |
| A typed line of 104 characters reached the shard **without its end** (`[serial ... set` with three pairs: the third was lost), so it was cut before the shard, at about 100 characters. Keep each command under about 90 characters; set many properties with several commands. | live 6.14 (2026-11-13: the ring got no luck); where it is cut is open (section 7) |
| Answers are system messages: serial `0xFFFFFFFF`, name `System`, hue `0x3B2`. `#Journal` shows the bare text. | src `Server/Mobiles/Mobile.Messages.cs` `Mobile.SendMessage`; live 6.12 (journal lines `You must wait to perform another action.` and `1 object generated in ...`) |
| One command gives one batch of answers. Equal lines are merged with a count: `Property has been set. (3)` for three pairs. At most 10 different lines. | src `UOContent/Commands/Generic/Commands/BaseCommand.cs` `BaseCommand.AddResponse`, `MessageEntry.ToString` |
| **If any part succeeded, the failures are not shown at all.** `[self set Str 77 Dex abc` answers only `Property has been set.`: the count is the only sign one pair failed. Check the count, or `get` each value afterwards. | src `BaseCommand.Flush` (sends the failures only when there are no responses) |

### 1.2 Access levels

The levels are `Player`, `Counselor`, `GameMaster`, `Seer`, `Administrator`, `Developer`, `Owner`
(src `Server/Mobiles/Mobile.cs` `enum AccessLevel`).

The `self` and `serial` modifiers and the `get` and `set` commands need only Counselor, but **each property has
its own read and write level**, and most of a mobile's need GameMaster even to read (src `Server/Attributes.cs`
`CommandPropertyAttribute`: one level means read = write). A Counselor's `[self get Str` answers
`You must be at least a game master to get the property 'Str'.` (src `UOContent/Commands/Properties.cs`
`Properties.GetPropertyInfoByName`, `Mobile.GetAccessLevelName`). In practice a probe needs a GameMaster;
`st_staff_probe` accepts any level above Counselor.

| Read with Counselor | Need GameMaster |
|---|---|
| `Serial`, `X`, `Y`, `Z`, `Location`, `Map`, `AccessLevel`, `Alive`, `Criminal`, `Kills`, `PhysicalResistance`, `StrLock`, `Skills.<Skill>.Base/Value/Cap/Lock` (read only; `Base` and `Cap` are written with GameMaster) | `Name`, `Body`, `Hue`, `Backpack`, `Str`, `Dex`, `Int`, `Hits`, `Stam`, `Mana`, `HitsMax`, `StamMax`, `ManaMax`, `TotalGold`, `TotalWeight`, `Hidden`, `Blessed`, `Warmode`, `IgnoreMobiles`, `Paralyzed`, `Frozen`, `Female`, `Direction`, `Followers`, `FollowersMax`, `StatCap`, `TithingPoints`, `Mounted`, `Mount`, `CantWalk`, `Karma`, `Fame`, `Title`; on a creature `HitsMaxSeed`, `Controlled`, `ControlMaster`; on an item's `SkillBonuses.Skill_N_Name/Value` |

src: the `[CommandProperty]` attributes in `Server/Mobiles/Mobile.cs`, `Server/Skills.cs` (`Skill`),
`UOContent/Mobiles/BaseCreature.cs`, `UOContent/Misc/AOS.cs` (`AosSkillBonuses`). Changing `AccessLevel` itself
needs Administrator or more (`Properties.SetDirect`), and nobody may change a mobile of a higher level
(`You cannot modify a higher privileged mobile.`).

**`[self get Luck` does not work**: `PlayerMobile.Luck` has no `[CommandProperty]`, so the answer is
`Property 'Luck' not found.` (src `UOContent/Mobiles/PlayerMobile.cs` `PlayerMobile.Luck`; live 4.11.luck SKIP
"the shard did not answer the get"). The character's luck can only be read from the status (`#Luck`). An item's
`Attributes.Luck` works (live 6.14.luck).

### 1.3 Commands that worked

Each line was sent with `msg <line>$` (the self-test's `st_staff` types the prefix, the words and Enter, then
waits 10 ticks). "Live" names a check that used it on 7.0.117.33.

| Command | Access | Answer in the journal | Live |
|---|---|---|---|
| `[self get AccessLevel` | Counselor | `AccessLevel = Owner` (the level's name) | 4.02 (`st_staff_probe`) |
| `[self get <Prop>` | Counselor + the property's level | `<Prop> = <value>` (format in 1.4) | 4.11 |
| `[self set <Prop> <v> [<Prop> <v> ...]` | Counselor + the property's level | `Property has been set.` (merged, see 1.1) | 4.12 to 4.18 |
| `[self set Skills.Anatomy.Base 47` | GameMaster (`Skill.Base`) | `Property has been set.` | 4.16 |
| `[get Name`, `[get Serial` (no modifier) | Counselor + property | a target cursor; then `Name = "Boydon"` for the target | 4.08, 6.06.self |
| `[self add <Type>` | GameMaster | `1 object generated in 0.00 seconds.` The mobile or item stands on your tile. | 7.07 (`Chicken`), 9.01 (`Rat`), 10.01 (`Provisioner`), 11.01 (`Horse`) |
| `[add <Type>` | GameMaster | a target cursor; the object appears where you target (an item's top, a mobile's tile, the ground, a static) | 6.04, 6.05 |
| `[self addtopack <Type> [ctor args]` | GameMaster | `1 object generated in ...` | 4.14 `Gold 1234`, 4.15 `Log 5`, 6.14 `GoldRing`, 7.08 `Bandage 10`, 5.08 `Bag`, 6.10 `Dagger`, 7.03 and 12.01 `BagOfReagents 20` and `Spellbook 18446744073709551615` |
| `[addtopack <Type>` | GameMaster | a target cursor; target a container (`#BackpackID`) | 6.03 |
| `[serial <n> get <Prop>` | Counselor + property | `<Prop> = <value>`, or `That is not a valid serial.` | 11.02.server, clean-up |
| `[serial <n> set <Prop> <v> ...` | Counselor + property | `Property has been set.` | `CantWalk true`, `HitsMaxSeed 120 Hits 120` (9.02), `Controlled true ControlMaster 1` (11.01), `SkillBonuses.Skill_1_Name Anatomy SkillBonuses.Skill_1_Value 5`, `Attributes.Luck 77` (6.14); `Hue 33` (6.03.col) |
| `[serial <n> delete` | GameMaster | `The item has been deleted.` / `The mobile has been deleted.` / `That cannot be deleted.` (a player) | clean-up of every stage |
| `[self dismount` | GameMaster | `They have been dismounted.` / `They were not mounted.` | - (4.10's fallback when its double click mounted something; not seen run) |
| `[go <x> <y> <z>` | Counselor | none; you stand there | 4.03, clean-up (position `restored`) |
| `[go <map name>` (`Felucca`, `Trammel`, `Ilshenar`, `Malas`, `Tokuno`, `TerMur`) | Counselor | none; same X/Y on that map | - (used when the facet differs; not seen run) |

Sources: `UOContent/Commands/Generic/Commands/Commands.cs` (`GetCommand`, `SetCommand`, `AddCommand`,
`AddToPackCommand`, `DeleteCommand`, `DismountCommand`), `UOContent/Commands/Generic/Implementors/`
(`SelfCommandImplementor`, `SerialCommandImplementor`, `SingleCommandImplementor`: a command without a modifier
raises a target cursor), `UOContent/Commands/Object Creation/Add.cs` `Add.Invoke`, `UOContent/Commands/Handlers.cs`
`Go_OnCommand` (also `[go <serial>` to an object, `[go <region name>`).

Details that matter:

- `Delete` supports items and NPCs, not `self`, and never deletes a player (src `DeleteCommand.Execute`). On a list
  of more than one object it asks for confirmation in a gump.
- `[self add` puts the new object at your feet because `Self` makes you the target (src `AddCommand.Execute`,
  `SelfCommandImplementor.Compile`).
- The words after the type are constructor arguments: `Gold(int amount)`, `Log(int amount)`,
  `BagOfReagents(int amount = 50)`, `Bandage(int amount = 1)`, `Spellbook(ulong content = 0)` where
  `18446744073709551615` (`ulong.MaxValue`) sets all 64 Magery spells (src the `[Constructible]` constructors in
  `UOContent/Items/...`).
- `[add <Type> ... set <Prop> <v> ...` sets properties while it makes the object (src `Add.Invoke`, the `set`
  keyword). Not tried live: it would save the separate `[serial ... set CantWalk true`.
- An unknown type: `No type with that name was found.` (src `Add.Invoke`, `AddCommand.ValidateArgs`).

### 1.4 Reading an answer

`get` answers one line per property: the property path as the shard spells it (not as you typed it), ` = `, the
value (src `Properties.InternalGetValue`):

| Kind | Example |
|---|---|
| integer | `Str = 77 (0x4D)` |
| double | `Skills.Anatomy.Base = 47` |
| string | `Name = "Boydon"` (live 6.06.self) |
| enum, bool | `Map = Malas`, `Direction = East`, `AccessLevel = GameMaster`, `Female = False` |
| serial | `Serial = 0x00000001` |
| item, mobile | `Backpack = 0x40000005 "Backpack"`, `ControlMaster = 0x00000001 "Boydon"` |
| null | `Mount = null` |

The self-test reads it this way (`st_sget_read`): search the journal since the bookmark for `<Prop>_=_`, take
the part after ` = `, and its first word for numbers:

```euo
set %j #JIndex
msg [self get Str$
findjournal %j * 3s Str_=_
if #JFound > 0
{
  str part #Journal _=_ 2
  str part #StrRes _ 1
  set %str #StrRes
}
halt
```

A hexadecimal value (`Serial`, `Body`, `Backpack`) needs its `0x` taken off and the rest read as a number
(`st_hex`). A failure answer (`Property 'X' not found.`, `... is read only.`, `You must be at least ...`) has no
` = `, so the search simply finds nothing: say so in the report instead of reading `N/A`.

### 1.5 Serials and EasyUO IDs

- `[serial` takes decimal or `0x` hexadecimal (src `Server/Commands.cs` `CommandEventArgs.GetUInt32`,
  `Server/Utilities/Utility.cs` `Utility.ToUInt32`). A property that holds an object (`ControlMaster`) takes a
  serial the same way and looks it up (src `UOContent/Utilities/Types.cs` `Types.TryParse`, `World.FindEntity`).
- Mobiles are `1` to `0x3FFFFFFF`, items `0x40000000` to `0x7EEEEEEE` (src `Server/Serial.cs` `IsMobile`,
  `IsItem`; `Server/World/World.cs` `ItemOffset`, `MaxItemSerial`).
- EasyUO writes a number n as `(n xor 69) + 7` in base 26, `A` = 0, lowest digit first. Serial 1 is `XC`. The
  self-test converts both ways with `st_id2ser` and `st_num2id`; item types use the same code (`st_num2id` of
  3922 is the dagger's type).

## 2. Making test objects and cleaning up

| Step | How | Source |
|---|---|---|
| Find what you made | The answer carries **no serial**: `Add` writes the serials only to the shard's command log. Take a list of the IDs first (`finditem <types> CA_ , #BackpackID`, or `finditem * G_3` for mobiles), make the object, list again, and keep the ID that is new (`st_newitem_begin` / `st_newitem_end`). Record it for the clean-up at once. | src `Add.Build` (`CommandLogging.WriteLine(from, "Serials: ...")`) |
| A pile in the backpack | `[self addtopack Gold 1234` always makes a **new** pile: it is dropped with `Container.DropItem`, which never stacks. | src `Server/Items/Container.cs` `Container.DropItem`; live 4.14.stack (1234) |
| A mobile held in place | `[serial <n> set CantWalk true` right after making it. A `CantWalk` mobile cannot step on land or on a dry static. | src `UOContent/Engines/Pathing/Movement.cs` (`cantWalk` blocks land and statics); `st_spawn` |
| Known hits | `[serial <n> set HitsMaxSeed 120 Hits 120`: a creature's `HitsMax` is `HitsMaxSeed` plus its strength bonus; `-1` (the default) means its `Str`. | src `UOContent/Mobiles/BaseCreature.cs` `HitsMax`, `HitsMaxSeed`; live 9.02 |
| A damaged target | `[serial <n> set Hits 1` (or `[self set Hits 30`): bandages refuse a mobile at full health. | src `Bandage.BeginHeal` (500955); live 7.15 |
| A pet | `[serial <n> set Controlled true ControlMaster <your serial>`. Setting `ControlMaster` adds the creature's `ControlSlots` to your `Followers`, without checking `FollowersMax`. Horse 1 slot, beetle 3. Its tooltip then shows `(tame)`. | src `BaseCreature.ControlMaster`, `AddFollowers`, `GetProperties` (502006); `UOContent/Mobiles/Animals/Mounts/Horse.cs`, `Beetle.cs`; live 11.01 (4 = 3 + 1), 11.02.prop |
| Known item bonuses | `[serial <ring> set SkillBonuses.Skill_1_Name Anatomy SkillBonuses.Skill_1_Value 5`, then `[serial <ring> set Attributes.Luck 77` (two commands: see 1.1), then equip it. | live 6.14 |
| Delete | `[serial <n> delete`, then `[serial <n> get Name` must answer `That is not a valid serial.` (`st_cl_undo`). Deleting a pet takes its slots off your `Followers`. | src `SerialCommandImplementor.Execute`, `BaseCreature.OnDelete` (`SetControlMaster(null)`) |
| Put a value back | `get` it first and record it, then `[self set <Prop> <old>` and look for `Property has been set.` | `st_cl_undo` (`staffset`) |
| Put gold back | `[self addtopack Gold <amount>` (only when gold was really spent). | `st_cl_undo` (`gold`) |
| Put the character back | `[go <map name>` if the facet changed, then `[go <x> <y> <z>`, and wait for `#CharPosX/Y`. | `st_cl_undo` (`pos`) |

The self-test keeps every created object and changed value in its `cleanup` table **before** the change
(`tools/EUOSelfTest/README.md`, "Options and saved data"), so a crashed run can still be cleaned up. A probe that
makes objects should at least log their IDs.

## 3. Behaviours that change what a check sees

### 3.1 Staff are not players

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| A double click (`0x06`) from Counselor or above is never throttled; from a player it waits `Mobile.ActionDelay` (500 ms) after the last one, else `You must wait to perform another action.` (500119). Lifting an item: GameMaster or above skip both the delay and the 2-tile range. Dropping into a container: GameMaster skip the range. Bandage-target requests: Counselor skip the delay. | src `UOContent/Network/Packets/IncomingEntityPackets.cs` `UseReq`; `Server/Mobiles/Mobile.cs` `Mobile.Lift`, `SendActionMessage`; `Server/Items/Item.cs` `Item.DropToItem`; `IncomingExtendedCommandPackets.BandageTarget` | - | A check that passes with a GM may fail with a player. Wait at least 0.5 s between item actions, and stay within 2 tiles. |
| With a GM, `You must wait to perform another action.` still appeared when `event macro 24` re-armed right after a disarm. The three places the shard sends it all skip staff, so this was the **client's** own message. | inferred from the row above | 6.12, 7.11 (2026-11-13) | Retry while the journal says so (`st_arm_try`). |
| Staff stay hidden when they cast, fight or use a bandage: `RevealingAction` unhides only a Player. | src `Server/Mobiles/Mobile.cs` `Mobile.RevealingAction`; `PlayerMobile.RevealingAction` | 12.02.b1 (the Hidden buff was still there after Bless and Protection) | Don't expect an action to unhide a GM; a player is unhidden by it. |
| An NPC does not hear a mobile it cannot see, and a Player-level mobile (every NPC) cannot see a hidden one. | src `Mobile.DoSpeech` (`heard.CanSee(this)`), `Mobile.CanSee` | 10.01: no shop while hidden (12:28), 53 entries after `[self set Hidden false` (12:29) | Unhide before speaking to an NPC, record it, hide again in the clean-up. |
| A hidden character has the `Hidden/Stealthing` buff (cliloc 1075655), staff too. | src `PlayerMobile.OnHiddenChanged` | 12.02.b1 (icon 30053, time -1, "You are hidden.") | Count it when you count buffs. |
| GameMaster and above buy for free; the vendor says `I would not presume to charge thee anything.  Here are the goods you requested.` | src `UOContent/Mobiles/Vendors/BaseVendor.cs` `BaseVendor.OnBuyItems` (`bought = buyer.AccessLevel >= AccessLevel.GameMaster`) | 10.03 (gold did not move; 3 salvage bags arrived) | Count the items that arrive, not the gold. |
| GameMaster and above ride any mount. | src `UOContent/Mobiles/Animals/Mounts/BaseMount.cs` `OnDoubleClick` (`canAccess`) | 11.04 | - |
| Staff use a door from any distance and open locked doors (`That is locked, but you open it with your godly powers.`, 502502). | src `UOContent/Items/Construction/Doors/BaseDoor.cs` `OnDoubleClick`, `Use` | - | A door check with a GM proves nothing about range or locks. |
| A target of staff level reads notoriety 3 (`CanBeAttacked`); a creature whose master is staff reads 3 to any player-type viewer, its master included (so a GM sees their own pet as 3). On AOS and later a `Blessed` mobile reads 7. | src `UOContent/Misc/Notoriety.cs` `NotorietyHandlers.MobileNotoriety` | - (source only) | Don't use a GM's pet to test the pet notoriety. |
| GameMaster and above may rename any mobile of a lower level, so every NPC's status bar has the rename field for them. | src `Mobile.CanBeRenamedBy` | - | - |

### 3.2 What the shard sends, and when

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| **Other mobiles' hits are sent out of 100**: `0xA1`, `0x2D` and the short status `0x11` carry 100 and `cur * 100 / max`. Your own pet and party members too. Only your own full status carries real values. | src `Server/Network/Packets/OutgoingMobilePackets.cs` `AttributeMaximum = 100`, `WriteAttribute`, `SendMobileStatus` (version 0 for others); `Mobile.ProcessDelta`; `UOContent/Engines/Party/Party.cs` | 9.02: 384/376 before `f895fa0` (96/94 times 4), 99/92 after; 11.03 (`#ContHP` /100) | `#EnemyHits` and health bars are percentages here; RunUO sends 25 (section 5). Test with a damaged mobile, never only at full health. |
| Your own full status (`0x11`) is sent again only when strength, dexterity, intelligence, weight, gold, armour, resistances, weapon damage, stat cap, followers, tithing points or race change. **Not** for `Female`, luck or `Blessed`. | src `Mobile.ProcessDelta` (`sendPrivateStats`) | 4.17.female.sex NOTE (`#Sex` stayed 0); 6.14.luck (read only after the status window was reopened) | Reopen the status window (`event macro 9 2`, `event macro 8 2`): the client asks for the status (`0x34`) and gets it. |
| `Blessed` sends only the yellow health bar packet, not the mobile's flags, so the client's own flags (letter `D` of `#CharStatus`) change only with the next flags update. `Paralyzed` (which also says `You cannot move!` 502381 / `You can move!` 502382), `Frozen`, `Warmode`, `IgnoreMobiles`, `Female` send the flags; `Hidden` resends the mobile. | src `Mobile.Blessed` (`Delta(MobileDelta.HealthbarYellow)`), the other setters (`Delta(MobileDelta.Flags)`), `Mobile.OnHiddenChanged`, `Mobile.GetPacketFlags` | 4.17.blessed NOTE (`HEC`, no `D`) | Read `D` after something else sends the flags (war mode on and off), or make it a NOTE. |
| `#Weight` is `TotalWeight` plus `Mobile.BodyWeight` (11). | src `OutgoingMobilePackets.CreateMobileStatus`, `Mobile.BodyWeight` | 4.11.weight: 198 against `TotalWeight` 187 | Compare differences, or allow the 11. |
| Gold weighs `0.02 / 3` stone a coin on ML and later (0.02 before), a log 2.0. | src `UOContent/Items/Misc/Gold.cs`, `Log.cs` `DefaultWeight` | 4.15 (5 logs = 10 stones) | Use logs, not gold, for a known weight. |
| A vendor's buy list (`0x74`) carries the name its shop entry gives, and on ModernUO that is often a **cliloc number as text**; an entry without a name gets `1020000 + ItemID`. The provisioner's salvage bag is `new GenericBuyInfo("1079931", typeof(SalvageBag), 1255, 20, ...)`. | src `UOContent/Mobiles/Vendors/SBInfo/SBProvisioner.cs`, `GenericBuy.cs` `GenericBuyInfo`; `Server/Network/Packets/OutgoingVendorBuyPackets.cs` `SendVendorBuyList` | 10.01: `#ShopItemName` 1079931, price 1255, stock 20 | `#ShopItemName` is a number on this shard; this is the shard's data, not only a client trait. |
| A full status is sent at login, and `vendor buy` sends it again ("make sure their gold amount is sent"). | src `UOContent/Network/Packets/IncomingAccountPackets.cs` (`SendMobileStatus`); `BaseVendor.VendorBuy` | - | Status values missing after login are the client's doing (section 6). |

### 3.3 Items and stacks

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| Lifting part of a stack: **the lifted part keeps the old serial**; the rest becomes a new item with a new serial, left where the pile was. | src `Mobile.Lift`, `Mobile.LiftItemDupe` | 6.09.split (100 and 1134) | After a split, the original ID is the part you hold. |
| Dropped into a container **without a position**, the item joins a pile of the same kind there: the pile already there keeps its serial and the dropped item is deleted. With a position (`exevent dropc <bag> 40 40`) it never stacks. | src `Item.DropToItem` (`p.m_X != -1` chooses), `Container.OnDragDrop`, `Container.TryDropItem`, `Item.StackWith` (`dropped.Delete()`) | 6.09 (drops at 40 40 to keep two piles) | Drop at a position when you need two piles; after a merge, look for the pile's ID, not the one you dropped. |
| `addtopack` never stacks (3.2 above). | src `Container.DropItem` | 4.14 | - |

### 3.4 Skills

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| Item skill bonuses stop at the skill's cap: `AosSkillBonuses` makes its mods `ObeyCap`, and `Skill.Value` caps them. `Base` stays as it was. | src `UOContent/Misc/AOS.cs` `AosSkillBonuses.AddTo`; `Server/Skills.cs` `Skill.Value`, `Skill.NonRacialValue` | 6.14 (Anatomy at 100 got no bonus; lowered to 50 it read 55.0, base 50.0) | Lower `Skills.<Skill>.Base` well under the cap first, and put it back. |

### 3.5 Spells and buffs

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| Staff pay mana and reagents like players (only NPC casters are free). | src `UOContent/Spells/Base/Spell.cs` `ConsumeReagents` (`!Caster.Player`), `Spell.Cast`, `CheckSequence` | 12.01 (the stage makes a spellbook and reagents, fills mana) | Give reagents (`BagOfReagents`) and mana (`[self set Mana <max>`). |
| A second spell too soon fails: while one is being cast, `You are already casting a spell.` (502642); within the cast recovery after it, `You have not yet recovered from casting a spell.` (502644). The recovery on AOS and later is `(6 - FCR) / 4` seconds: 1.5 s with no Faster Cast Recovery. A new cast while a spell's target cursor is up cancels that spell (AOS). | src `Spell.Cast`, `Spell.GetCastRecovery` | - | Wait for the cast to end plus 1.5 s (more without the cast delay known) before the next cast. |
| `Insufficient mana` (502625) and `More reagents are needed for this spell.` (502630) are shown over your head to you only (`LocalOverheadMessage`). | src `Spell.Cast`, `Spell.CheckSequence` | - | Whether the client puts them in the journal was not checked (section 7). |
| **Protection (AOS) is a toggle**: a cast turns it on, the next cast turns it off. The state lives in a table in memory, so it stays through logout and death, and is lost when the shard restarts. | src `UOContent/Spells/Second/Protection.cs` `ProtectionSpell.Toggle`, `EndProtection` (only a talisman calls it) | 12.01.prot ("it was on: the cast turned it off then on again") | Count the buffs before and after the cast; cast again in the clean-up if the probe turned it on. |
| Bless (AOS) lasts `6 * EvalInt / 5` seconds and adds `1 + EvalInt / 10` per cent: it depends on Evaluating Intelligence, not Magery. | src `UOContent/Spells/Base/SpellHelper.cs` `GetDuration`, `GetOffsetScalar`; `UOContent/Spells/Third/Bless.cs` | 12.02.b3 (115 s left, "+11% Strength"), 12.03 (115 then 100) | Set `Skills.EvalInt.Base` for known numbers. |
| The buff numbers the shard sends are its own (`BuffIcon` HidingAndOrStealth 1012, Protection 1029, Bless 1048); the client turns them into the icon numbers `#BuffID` shows. | src `UOContent/Engines/BuffIcons/BuffIcon.cs`; `Protection.cs`, `Bless.cs`, `PlayerMobile.OnHiddenChanged` | 12.02: icons 30053, 30050, 30018 | Match `#BuffID` against the client's icon numbers (section 4), not the shard's. |

### 3.6 Bandages, doors, context menus, renaming

| Behaviour | Source | Live | How a probe copes |
|---|---|---|---|
| A bandage needs a damaged (or poisoned, bleeding) patient, else `That being is not damaged!` (500955); range 2 on AOS and later (1 before); the start is `You begin applying the bandages.` (500956). | src `UOContent/Items/Skill Items/Misc/Bandage.cs` `Bandage.Range`, `BandageContext.BeginHeal` | 7.15 (macro 59 on a chicken at 1 hit) | Lower the hits first. |
| Macro 58 (bandage self): the first journal line was `Who will you use the bandages on?` (500948), and one bandage was used. | src `Bandage.OnDoubleClick` | 7.08.journal, 7.08.used | Match `bandage`, as `st_c708` does, or wait for 500956. |
| Macro 12 (Open Door) sends `0x12` type `0x58`; the shard looks **only at the tile in front of you** (your facing) and answers `Opening door...` (500024) when it finds a door there. An open door moves aside, so a second macro finds none. | src `UOContent/Network/Packets/IncomingPlayerPackets.cs` (case `0x58`), `BaseDoor.OpenDoorMacroUsed` | 7.09 (`Opening door...`) | Face the door; no answer means no door in front. |
| A context menu (`exevent popup`) opens for anything you can see within the update range. | src `UOContent/Context Menus/ContextMenuSystem.cs` | 6.18 (HUMAN) | - |
| Renaming (`exevent renamepet`, packet `0x75`): allowed for the owner of a controlled pet or for a GameMaster above it, within 12 tiles; the name must be 1 to 16 **letters** (no digits, no spaces), else `That name is unacceptable.`; success is `Pet ~1_OLDPETNAME~ renamed to ~2_NEWPETNAME~.` (1072623). | src `UOContent/Network/Packets/IncomingMobilePackets.cs` `RenameRequest`; `UOContent/Misc/RenameRequests.cs`; `NameVerification.ValidatePetName`; `BaseCreature.CanBeRenamedBy` | 11.02 (`EuotestB`; tooltip `EuotestB / tame /`) | Build the new name from letters only. |

### 3.7 Mounts

| Behaviour | Source | Live |
|---|---|---|
| A double click mounts only from 1 tile (`That is too far away to ride.`, 500206). | src `BaseMount.OnDoubleClick` | 11.04 |
| While you ride, another mount answers `Please dismount first.` (1005583). | src `BaseMount.OnDoubleClick` | 11.04 (the stage gets you off the beetle first) |
| A double click on yourself while riding dismounts you instead of opening the paperdoll (unless the shard sets `DisableDismountInWarmode` and you are in war mode; off by default). A paperdoll request (high bit set in `0x06`) never dismounts. | src `Mobile.OnDoubleClick`, `Mobile.DisableDismountInWarmode`; `IncomingEntityPackets.UseReq` | 11.05, 4.10 (the check is skipped while riding) |
| On dismount the creature comes back on the rider's tile, facing the rider's way, with the **same serial** (while ridden it is kept off the map, not deleted). An ethereal mount goes to the backpack. | src `BaseMount.Rider` setter; `UOContent/Mobiles/Animals/Mounts/Ethereals.cs` | 11.04/11.05 (the stage remounts the beetle it found on your tile) |
| `[self dismount` (GameMaster) frees the mount the same way and **deletes** anything else left on the mount layer. | src `DismountCommand.Execute` | - |
| The rider wears a mount item on layer 25 (`Layer.Mount`). | src `BaseMount` (`InternalItem`) | 11.04.layer |

### 3.8 Requests the shard does not answer

| Behaviour | Source | Live |
|---|---|---|
| **Equip Last Weapon** (macro 37): ModernUO has no such logic (no `LastWeapon` anywhere in its source). The `0xBF` sub-command `0x1E`, which the self-test takes to be the client's request, is registered to `HouseFoundation.QueryDesignDetails`, which reads a house serial and does nothing for anything else. | src `UOContent/Network/Packets/IncomingExtendedCommandPackets.cs` (the `RegisterExtended` list), `UOContent/Multis/Houses/HouseFoundation.cs` `Initialize`, `QueryDesignDetails` | 7.11 NOTE (the weapon stayed in the backpack) |

### 3.9 Speaking to vendors

| Behaviour | Source | Live |
|---|---|---|
| `vendor buy` (keyword `0x3C`) works within 1 tile on AOS and later (4 before), and only if the vendor sees you (3.1). `vendor sell` is `0x14D`; `<name> buy` also works. | src `UOContent/Mobiles/AI/VendorAI.cs` `OnSpeech`, `HandlesOnSpeech` | 10.01 (the vendor stands on your tile) |
| Accepting the buy list (`0x3B`) works within 10 tiles. | src `UOContent/Network/Packets/IncomingVendorPackets.cs` `VendorBuyReply` | 10.03 |
| Vendors are invulnerable (notoriety 7) when the shard setting `vendor.isInvulnerable` is on; its default is "LBR or later". | src `BaseVendor` (`_vendorInvulnerable`), `NotorietyHandlers.MobileNotoriety` | 10.01.rep (`#FindRep` 7) |

## 4. Journal texts worth matching

`findjournal` matches anywhere in the line, ignoring case, with `_` for a space. Shard texts are quoted from the
source; the cliloc numbers' English text is the comment next to them there.

| Text | Number | Sent by (src) | Live |
|---|---|---|---|
| `Property has been set.` (`(n)` when merged) | - | `Properties.SetDirect`, `BaseCommand.AddResponse` | 7.05, clean-up |
| `<Prop> = <value>` | - | `Properties.InternalGetValue` | 4.11, 6.06.self |
| `Property '<Prop>' not found.`, `Property '<Prop>' is read only.`, `You must be at least <level> to get the property '<Prop>'.` | - | `Properties.GetPropertyInfoByName` | 4.11.luck (not found) |
| `That is not a valid serial.` | - | `SerialCommandImplementor.Execute` | clean-up |
| `That is not a valid command.`, `You do not have access to that command.`, `That is either an invalid command name or one that does not support this modifier.` | - | `CommandSystem.Handle`, `BaseCommandImplementor.Execute` | - |
| `1 object generated in 0.00 seconds.` | - | `Add.Invoke` | 6.12 journal |
| `No type with that name was found.` | - | `Add.Invoke` | - |
| `The item has been deleted.`, `The mobile has been deleted.`, `That cannot be deleted.` | - | `DeleteCommand.Execute` | clean-up |
| `They have been dismounted.`, `They were not mounted.` | - | `DismountCommand.Execute` | - |
| `You must wait to perform another action.` | 500119 | `Mobile.SendActionMessage` (players); the client sends its own (3.1) | 6.12 |
| `Who will you use the bandages on?` | 500948 | `Bandage.OnDoubleClick` | 7.08 |
| `That being is not damaged!` | 500955 | `BandageContext.BeginHeal` | - |
| `You begin applying the bandages.` | 500956 | `BandageContext.BeginHeal` | 7.15 |
| `Opening door...` | 500024 | `BaseDoor.OpenDoorMacroUsed` | 7.09 |
| `Please dismount first.` | 1005583 | `BaseMount.OnDoubleClick` | - |
| `That is too far away to ride.` | 500206 | `BaseMount.OnDoubleClick` | - |
| `Pet ~1_OLDPETNAME~ renamed to ~2_NEWPETNAME~.` | 1072623 | `RenameRequests.RenameRequest` | - |
| `(tame)` (tooltip) | 502006 | `BaseCreature.GetProperties` | 11.02.prop |
| `You are already casting a spell.` | 502642 | `Spell.Cast` | - |
| `You have not yet recovered from casting a spell.` | 502644 | `Spell.Cast` | - |
| `Insufficient mana ...` (over your head) | 502625 | `Spell.Cast`, `CheckSequence` | - |
| `More reagents are needed for this spell.` (over your head) | 502630 | `Spell.CheckSequence` | - |
| `I would not presume to charge thee anything.  Here are the goods you requested.` (the vendor says it; two spaces) | - | `BaseVendor.OnBuyItems` | - |
| `Begging thy pardon, but thou canst not afford that.` (the vendor) | 500192 | `BaseVendor.OnBuyItems` | - |

Buff clilocs (`#BuffCliloc`) with the icons the client showed (`#BuffID`, live 12.02):

| Buff | Cliloc (title / description) | Icon on 7.0.117.33 | Shard `BuffIcon` |
|---|---|---|---|
| Hidden/Stealthing | 1075655 | 30053 | 1012 |
| Protection | 1075814 / 1075815 | 30050 | 1029 |
| Bless | 1075847 / 1075848 | 30018 | 1048 |

## 5. RunUO and official servers

| Difference | Source |
|---|---|
| Other mobiles' hits: RunUO sends them out of **25** (`AttributeNormalizer.Maximum = 25`), ModernUO out of 100. EasyUO 1.5 and 1.6 multiplied by 4, right on RunUO only; Reforged reads `cur * 100 / max` since `f895fa0`, right on both. | src RunUO `Server/Network/Packets.cs` `AttributeNormalizer` (github.com/runuo/runuo, master, read 2026-11-14); ModernUO `OutgoingMobilePackets.AttributeMaximum`; side-session note `enemyhits-fix.md` |
| ServUO's own `0xBF` list (`Server/Network/PacketHandlers.cs`) has no Equip Last Weapon handler either. | src github.com/ServUO/ServUO, read 2026-11-14 |
| Vendor invulnerability depends on the expansion and a setting on ModernUO (3.9); a shard on an older expansion shows other notoriety. | src `BaseVendor` |

Nothing else here was compared with RunUO, ServUO or official (OSI) servers. Official servers have no staff
commands, so none of sections 1 and 2 applies there, and the throttles and ranges of 3.1 are what a player meets.

## 6. Facts about the client, not ModernUO

Listed so nobody looks for them in the shard:

- `#NextCPosX/Y` are used only with the client option *Offset interface windows rather than perfectly stacking
  them* on (`docs/nextcpos-analysis.md`).
- The status values are there only while a status gump (status window or your own health bar) is open. The shard
  sends a full status at login (3.2), so this is the client.
- `#CharDir` is the client's walk direction: `[self set Direction East` turns the character on the shard (the
  shard sends the new direction, src `Mobile.ProcessDelta`), but `#CharDir` stays (live 4.18.dir INFO).
- The cut of a typed line at about 100 characters (1.1) happens before the shard: in the client, or in EasyUO's
  typing.
- A vendor's `#ShopItemName` being a number is **not** only the client: the shard sends the number (3.2).
- The client's own `You must wait to perform another action.` for item moves in a row (3.1).

## 7. Open questions

- Which `0xBF` sub-command (if any) does client 7.0.117.33 send for Equip Last Weapon? The `0x1E` in the
  self-test was not checked in client.exe; ModernUO uses `0x1E` for the house design query.
- Where the ~100-character cut happens (the client's input line, or EasyUO's typing) and its exact length.
- Whether `c9875e7f` matches the owner's shard build.
- Not seen live: the merged `Property has been set. (3)`; `[add ... set ...`; the notoriety of a GM's own pet (3);
  Protection lost at a shard restart; whether the client journals `LocalOverheadMessage` lines (502625, 502630)
  and spell words; what follows 500948 in macro 58's journal.
- Which other ModernUO differences from RunUO matter to a check (free buying for staff, the cast recovery, the
  status resend rules) was not looked up.
