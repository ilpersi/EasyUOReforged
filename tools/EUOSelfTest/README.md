# EUO SelfTest

A **client regression test** for EasyUO Reforged. When a new UO client comes out and the offset table
(`uo/uoclidata.pas`) has to be updated, run `EUOSelfTest.euo` against the new client: it tells you which
commands and `#variables` no longer work, and **which table fields are the likely cause**.

It is a plain EasyUO script, so it runs the real script path (parser, interpreter, engine). Every automatic
check makes a value known first, by a staff command, a write or an action, and compares what EasyUO reads
with what it must be; or it reads one fact from two independent places (`#CharPosX` and `finditem #CharID`'s
`#FindX`, `#Gold` and the shard's own `TotalGold`). It asks you only about what no variable can show: an
animation, a text over a head.

## Running it

1. Log a character in. A **GM or admin character on your own ModernUO shard** lets the script set up
   everything itself with staff commands (see [Staff commands](#staff-commands-modernuo)). Any character
   works: without staff commands the script asks you to prepare things, or skips the checks that need them.
2. In EasyUO Reforged open `tools\EUOSelfTest\EUOSelfTest.euo` in a tab and press **Play**.
3. The first time, *Settings* opens: staff commands on or off and their prefix, the test spot, where the
   panel goes, the report folder, and the opt-in stages. *Use where I stand* fills in the test spot.
4. The main window lists the stages. Tick the ones to run and press **Run selected** (or **Run all**).
5. While it runs, a small always-on-top panel shows the check, the stage, two progress bars (the whole run
   and the stage) and the counts. It asks the HUMAN questions with **Pass**, **Fail** (then an optional
   note of what you saw), **Skip**, **Repeat** (the same step again) and **Stop**. Stop ends the run, cleans
   up and still writes the report. An optional step that only asks whether to go on ("Pass = send it, Skip =
   skip") hides Fail and Repeat, and the two warnings before the event-hook stages show only Pass and Stop.
   A question asked again after Repeat starts with "Again (you pressed Repeat)".
6. At the end the report opens in a window you can copy from, and is written to the report folder.

The client only has your status values (name, stats, gold) once the status window has been opened since you
logged in. Stage 1 only reads, so if they are missing, 1.04 asks you to open it.

From stage 4 on the script **types into the client and moves the mouse**: don't type or touch the mouse
until the run ends (the client reads the real cursor). The panel says so and waits for you first.

**Run one check**: type its ID (`4.12`) in the main window and press *Run one check*, to re-test after a fix.
Each check sets up what it needs itself (the test weapon, the gold pile), so it runs on its own.

## Stages

They run in this order, safest first. A stage that fails nothing tells you its fields are right for this client.

| # | Stage | Checks | Needs or changes |
|---|---|---|---|
| 1 | Identity and attach | 7 | reads only. **If 1.02 to 1.06 fail the run stops**: nothing after them would mean anything |
| 2 | Read-only variables | 16 | reads only: ranges, consistency, two sources of one fact |
| 3 | Memory writes | 9 | writes client memory, reads it back, puts it back |
| 4 | Keys, clicks, msg and staff set-up | 18 | types and clicks; staff commands make values known (stats, gold, weight, skill, status letters) |
| 5 | Event hook: messages and gumps | 16 | runs client code through the event hook |
| 6 | Event hook: targeting and items | 18 | event hook; makes a test weapon, moves, equips and hides it |
| 7 | Event hook: skills, spells, macros | 15 | event hook; casts Magic Arrow, toggles war mode and Always Run, bandages a chicken it makes |
| 8 | Event hook: movement | 6 | event hook; walks two tiles each way from the test spot |
| 9 | Combat (opt-in) | 3 | **attacks** a rat it makes (or a monster you choose) |
| 10 | Vendor (opt-in) | 3 | makes a vendor, opens its buy window, **buys 3 items** |
| 11 | Pets and mount (opt-in) | 5 | makes a horse your pet, renames, mounts and dismounts it |
| 12 | Buffs (opt-in) | 5 | casts Bless and Protection (or asks you for buffs), closes and opens the buff bar |

The opt-in stages are offered in the main window only after you switch them on in *Settings*.

From stage 2 on, a run also stops when the client leaves the game during it (`#CliLogged` is `0`: the
connection was lost, or you logged out): every check after that would fail for that reason alone.

**Before the first event-hook stage** the panel warns that a wrong `E_` value can freeze or crash the client,
and waits for you. From there on the report is written before every check, so a crash loses at most that
check; the database remembers the last finished stage, and the next start offers **Resume from stage N**
and the clean-up of what the crashed run left.

Never run: `event macro 20` (quit game), anything that logs out, closes or starts a client, `shutdown`,
`terminate`, `uoXL new`, `send`. `uoXL swap` runs only when two clients are running (2.16).

### The checks

| ID | Check |
|---|---|
| 1.01 | Versions and clients |
| 1.02 | Logged in |
| 1.03 | Character ID |
| 1.04 | Character name |
| 1.05 | Position |
| 1.06 | Backpack |
| 1.07 | Shard and client language |
| 2.01 | Character state |
| 2.02 | FindItem on yourself |
| 2.03 | FindItem on the worn backpack |
| 2.04 | Status values: ranges and consistency |
| 2.05 | Client window |
| 2.06 | Facet and last shard |
| 2.07 | Skill variables |
| 2.08 | Journal variables |
| 2.09 | Last-action variables |
| 2.10 | The gump on top |
| 2.11 | Cursor and pixels |
| 2.12 | Tiles under the character |
| 2.13 | Path can where you stand |
| 2.14 | Buff bar state |
| 2.15 | Mount |
| 2.16 | uoXL swap |
| 3.01 | SysMsgCol |
| 3.02 | LObjectID |
| 3.03 | Last-target variables |
| 3.04 | Arm-disarm hands |
| 3.05 | Last spell, skill and shard |
| 3.06 | Next gump position |
| 3.07 | Game area size and position |
| 3.08 | Window title |
| 3.09 | FindIndex and FindMod |
| 4.01 | click n mc moves the cursor |
| 4.02 | Staff commands answer |
| 4.03 | Test spot |
| 4.04 | move two tiles each way |
| 4.05 | msg and the journal |
| 4.06 | findjournal rules |
| 4.07 | deletejournal |
| 4.08 | key esc and the target cursor |
| 4.09 | key with alt and a right click |
| 4.10 | Double-click on yourself |
| 4.11 | The server's values against the client's |
| 4.12 | Known stats: Str 77, Dex 63, Int 41 |
| 4.13 | Known hits, stamina and mana |
| 4.14 | Gold: exactly 1234 more |
| 4.15 | Weight: exactly 10 stones more |
| 4.16 | Known skill: Anatomy 47 |
| 4.17 | Status letters |
| 4.18 | Other known values |
| 5.01 | event SysMessage |
| 5.02 | event ExMsg over your head |
| 5.03 | Macros 8 and 9: paperdoll |
| 5.04 | Macros 10 and 11: minimize and maximize |
| 5.05 | Macros 8 and 9: skills and status gumps |
| 5.06 | The backpack gump |
| 5.07 | Moving the backpack gump |
| 5.08 | nextcpos places the next container |
| 5.09 | event ContTop |
| 5.10 | ignorecont |
| 5.11 | event StatBar and #ContHP |
| 5.12 | Speech macros 1 to 4 |
| 5.13 | event Property |
| 5.14 | Macro 57 and #BuffBarOpen |
| 5.15 | Macros 18, 19 and 21 |
| 5.16 | Macro 31 closes the gumps |
| 6.01 | target and a skill's cursor |
| 6.02 | Writing #TargCurs installs a target handler |
| 6.03 | Test weapon made through the target cursor |
| 6.04 | Ground target: #LTargetKind 2 |
| 6.05 | Static target: #LTargetKind 3 |
| 6.06 | Target Self and Last Target through the server |
| 6.07 | Last object |
| 6.08 | exevent Drag, DropG, DropC |
| 6.09 | Part of a stack |
| 6.10 | event Drag |
| 6.11 | exevent Equip and #FindLayer |
| 6.12 | Macro 24: arm and disarm |
| 6.13 | exevent DropPD |
| 6.14 | Skill bonus: #Skill with and without it |
| 6.15 | ignoreitem |
| 6.16 | hideitem |
| 6.17 | event Property of an item |
| 6.18 | exevent PopUp |
| 7.01 | Macro 6: war and peace |
| 7.02 | Macro 14: last skill |
| 7.03 | Macros 15 and 16: spells |
| 7.04 | Skill locks |
| 7.05 | Stat lock |
| 7.06 | Macro 32: Always Run |
| 7.07 | Macros 50, 51, 52: the targeting system |
| 7.08 | Macro 58: bandage yourself |
| 7.09 | Macro 12: open door |
| 7.10 | Macros 35 and 36: weapon abilities |
| 7.11 | Macro 37: equip last weapon |
| 7.12 | Macro 56: targeting system on/off |
| 7.13 | Macros this script does not run |
| 7.14 | Macro 55: current target |
| 7.15 | Macro 59: bandage target |
| 8.01 | Macro 5: walk |
| 8.02 | event PathFind |
| 8.03 | path find and path walk |
| 8.04 | path go |
| 8.05 | path step |
| 8.06 | path check: the client's own step check |
| 9.01 | Macro 27: attack last |
| 9.02 | EnemyHits falls |
| 9.03 | Macros 52 and 53: attack selected |
| 10.01 | getshopinfo and the shop variables |
| 10.02 | The shop entry is an item FindItem sees |
| 10.03 | setshopitem and buying |
| 11.01 | A pet and #Followers |
| 11.02 | exevent RenamePet |
| 11.03 | event StatBar of the pet |
| 11.04 | Mounting: #MountID and #MountType |
| 11.05 | Dismounting |
| 12.01 | Buffs on the character |
| 12.02 | Every buff through #BuffIndex |
| 12.03 | BuffTime counts down |
| 12.04 | scanbuffs with an icon ID |
| 12.05 | The buff bar closed |

Each check writes one or more report lines, each with its own ID (`4.12.str`, `4.12.dex`, ...).

## Options and saved data

Everything the script keeps between runs is in **`EUOSelfTest.db`**, an SQLite file next to
`EasyUOReforged.exe` (`sql open EUOSelfTest.db`, relative to `#CurPath`). If `sql open` fails (no SQLite on the
PC), the main window says so and the script runs without saved data: it asks for the options each time and
offers no resume and no clean-up after a crash. The unattended dry run uses `:memory:`.

| Table | Holds |
|---|---|
| `euo_vars` (`sql save` / `sql load`) | Options that are the same on every shard, named `%st_opt_...`: panel position, report folder, the stages last selected, the four opt-in stages, and the clean-up rows you chose to forget (written into the next report, then cleared). |
| `shards` | One row per `#Shard`: `staff` (0/1), `prefix`, the test spot `x`, `y`, `z`, `facet` (as `#CursKind`). |
| `runs` | One row per run: `started` (`#SysTime`), `shard`, `charid`, `cliver`, `stages`, `last_stage`, `state` (`running`, `finished`, `stopped`). A row still `running` at the next start crashed. |
| `cleanup` | What a run created or changed: `run`, `kind` (`created` / `changed`), `target`, `detail` (how to undo it), `old_value`, `done`. A changed value is written **before** the change, a created object right after `finditem` finds it. |

At start, open `cleanup` rows are listed with *Clean up now* (same shard and character), *Later* and
*Forget them*. *Reset options* in *Settings* deletes the option rows and the shard rows, never open clean-up rows.

**The test spot** must be open ground with walkable tiles two steps east and two steps south: the walking
checks use them, and check them first with `path can` (a blocked way is skipped, not failed). With staff
commands the script teleports there at the start of the first stage from 4 on; without, it asks you to walk
there, or tests where you stand.

## Staff commands (ModernUO)

Typed with `msg`, after the prefix saved in *Settings* (`[` by default). Every command, its access level and
the property names were checked in ModernUO's source (`Projects/UOContent/Commands/`: `Handlers.cs`,
`Generic/Commands/Commands.cs` and the implementors in `Generic/Implementors/`), not written from memory. What ModernUO
does that a check can see (staff, stacks, vendors, mounts, buffs...) is in `docs/modernuo-reference.md`.

| Command | Access level | What the script uses it for |
|---|---|---|
| `[self get <property>` | Counselor (most character values: GameMaster) | The shard's own value, the second source for most of stage 4: `Serial`, `Name`, `Backpack`, `Body`, `X`, `Y`, `Z`, `Direction`, `Female`, `Map`, `TotalGold`, `TotalWeight`, `Followers`, `FollowersMax`, `StatCap`, `TithingPoints`, the five `...Resistance`, `HitsMax`, `StamMax`, `ManaMax`, `Skills.Anatomy.Base/Value/Cap/Lock`, `StrLock`, `AccessLevel` (staff or not). |
| `[self set <property> <value> ...` | Counselor (the properties: GameMaster) | Known values: `Str 77 Dex 63 Int 41`, `Hits`/`Stam`/`Mana`, `Skills.Anatomy.Base 47`, `Skills.Magery.Base 100`, `TithingPoints 1234`, `StatCap 251`, `FollowersMax 6`, `Direction`, and the status letters `Warmode`, `Hidden`, `IgnoreMobiles`, `Paralyzed`, `Female`, `Blessed`. Every old value is read first and put back. |
| `[get Name`, `[get Serial` (target cursor) | Counselor | Raises a target cursor (4.08) and checks what Target Self and Last Target hit (6.06). |
| `[self addtopack <type> [amount]` | GameMaster | `Gold 1234`, `Log 5` (10 stones), `Dagger`, `GoldRing`, `Spellbook 18446744073709551615` (every spell), `BagOfReagents 20`, `Bandage 10`. |
| `[addtopack Dagger` (target cursor) | GameMaster | The test weapon, answered with `#LTargetID` = `#BackpackID` and `event macro 22` (6.03). |
| `[add Dagger` (target cursor) | GameMaster | Items on the ground and on a static, through `#LTargetKind` 2 and 3 (6.04, 6.05). |
| `[self add <type>` | GameMaster | Mobiles at your feet: `Chicken` (7.07), `Rat` (9.01), `Provisioner` (10.01), `Horse` (11.01). |
| `[serial <n> set ...` | Counselor | On what the script made: `Hue 33`, `CantWalk true`, `HitsMaxSeed 120 Hits 120`, `Controlled true ControlMaster <you>`, `SkillBonuses.Skill_1_Name Anatomy SkillBonuses.Skill_1_Value 5`, then `Attributes.Luck 77`. |
| `[serial <n> get Name` | Counselor | The pet's new name (11.02); after a delete, *That is not a valid serial* confirms it is gone. |
| `[serial <n> delete` | GameMaster | Deletes what the script made (clean-up). The serial is worked out from the EasyUO ID. |
| `[go <x> <y> <z>`, `[go <facet>` | Counselor | The test spot, and back where you were at the end. |

**Staff characters are not players.** They may be invulnerable (`Blessed`: the `D` and `C` letters of
`#CharStatus`), walk through mobiles (`E`), and the shard may treat them differently. Where that changes what
a check sees, the line says so or the check is a NOTE, not a FAIL.

**Clean-up.** Everything the script made is deleted at the end and on Stop; everything it changed on the
character (stats, skills, locks, war mode, position, the window, the title, what you held, a pet's name,
the mount you rode, Protection, the buff bar) is put back. Bless runs out by itself. The report's **CLEAN-UP** section lists each with its result; anything that failed says so.

## Without staff commands

Switch *Use staff commands* off in *Settings*. Then:

- the checks that make values known with staff commands (4.11 to 4.18, 6.04, 6.05, 6.14, 7.14, 7.15) are
  SKIPped;
- the checks that need something ask you to prepare it: a weapon in the backpack (you click it with the
  target cursor the script shows), a spellbook with reagents, bandages, a vendor's buy window, one of your
  pets, buffs on the character, a monster nearby. *Skip* skips the check;
- the test spot: the script asks you to walk there, or tests where you stand;
- nothing is created, so nothing has to be deleted; changes the script makes itself (window, title, locks,
  war mode, a pet's name) are still put back.

## Macros the self-test does not run

7.13 lists them in one INFO line instead of a SKIP each, so the skip count only shows checks that could not run:

| Macro | Why not |
|---|---|
| 20 Quit Game | it would log you out |
| 25, 28 Wait For Target, Delay | they only affect the macro sequences the client plays itself |
| 29 Circle of Transparency | a client setting no variable shows |
| 33, 34 Save Desktop, Kill Gump Open | nothing a script can check |
| 38 to 48 Update Range | they change a client setting |
| 49 Virtues | needs a virtue to invoke |
| 53 Attack Selected | stage 9 (combat) runs it |
| 54 Use Selected | double-clicks whatever is selected: nothing safe to check |
| 60 Gargoyle Fly | gargoyles only |
| 61 to 66 dress and arm sets | they overwrite your saved sets |
| 67 Use Object | not part of this self-test |

## The report

`selftest-<ReforgedVer>-<client version>-<date>-<time>.md` in the report folder (default: next to
`EasyUOReforged.exe`; `selftest-*.md` is git-ignored). It is written through `execute` (batched
`cmd /c echo` lines, so a console window flashes) at the end of every stage and, in the event-hook stages,
before every check. Every line also goes to the Output panel with `log`.

The header holds `#ReforgedVer` and the script's own revision (`script=`, the `%st_rev` line at its top:
raise it with every change), `#CliVer`, the shard, the character, date and time, the options and the stages
run. Then one line per check:

    - [PASS|FAIL|NOTE|SKIP|INFO]_<id>_<what>_[AUTO|HUMAN]_observed=<value>_expected=<value>_fields=<C_X,B_Y>

Underscores stand for spaces. `fields` are the `uoclidata.pas` fields the check depends on.

- **PASS / FAIL**: the value is, or is not, what it must be. On a client that works, a FAIL is a bug in
  this script (or a real engine bug to report), not an offset problem.
- **NOTE**: a known difference or a setting that explains the value. Known differences: `#LSpell` counts
  Magery from 1, so Magic Arrow is 5 (7.03.last), and the Cast Spell macro does not set it: only the
  spellbook and the spell icons do (7.03.lspell expects it unchanged); `#CursKind` is the facet, not a cursor (2.06); a vendor's
  `#ShopItemName` is a cliloc number when the shard sends one (ModernUO's provisioner does: 10.01.cliloc); `#CharDir` is the client's own walk
  direction, so a turn made by the shard does not change it (4.18.dir is an INFO line). With the client
  option *Offset interface windows rather than perfectly stacking them* off, containers open at the top right
  and `#NextCPos` is not used (5.08; see `docs/nextcpos-analysis.md`). ModernUO has no *Equip Last Weapon*
  (its `0xBF` `0x1E` handler is a house-design query), so 7.11 is a NOTE there. `#TP` stays 0 until the
  client gets a full status (4.11.tp is then a NOTE; 4.18.tp checks the field). client_beta's own walk can
  end next to the goal (8.02.there is then a NOTE).
- **SKIP**: not run, with the reason. `blocked_by_<id>` means a check it depends on failed: if `#CharPosX`
  fails, the walks are blocked, not failed.
- **INFO**: a value written down for comparison.
- A HUMAN line holds the values the script read, and after *Fail* what you typed.

**Check IDs are stable.** A new check gets a new ID; a removed check's ID is never reused. That is what makes
two reports line up: run it on a client that works and on the new one, and compare the files.

At the end: the counts, then **TABLE_FIELDS_WITH_FAILING_CHECKS**, one line per field with failing checks
(`C_CONTPOS:_3_of_4_checks_fail`): the list of what to fix in `uoclidata.pas`. Then the **CLEAN-UP** list.

## Which checks exercise which table field

Built from the script's field groups (`%fx_...` in `st_init`): the checks whose report lines name the field.
A field read only on some builds (the `F_JOURNALDIRECT` journal layout, the relocatable builds' `E_MACROTAB`,
`E_NEWOBJ`, `E_PATHFINDMID`, `F_PROPFAST`, ...) is exercised by the same checks on the builds that use it.

| Field | Checks |
|---|---|
| `C_BLOCKINFO` | 8.03, 8.04, 8.05, 8.06 |
| `C_CLILOGGED` | 1.02 |
| `C_CLIXRES` | 2.05, 3.07 |
| `C_ENEMYID` | 2.09, 9.01, 9.03 |
| `C_SHARDPOS` | 1.07 |
| `C_NEXTCPOS` | 2.04, 3.06, 4.11, 4.18, 5.08 |
| `C_SYSMSG` | 2.09, 5.01 |
| `C_CONTPOS` | 2.10, 2.14, 4.09, 4.10, 5.03, 5.06, 5.07, 5.08, 5.09, 5.10, 5.11, 5.14, 10.01, 10.02, 10.03, 12.01, 12.02, 12.04, 12.05 |
| `C_ENEMYHITS` | 9.02 |
| `C_LHANDID` | 1.07, 2.09, 3.02, 3.03, 3.04, 3.05, 6.01, 6.02, 6.03, 6.04, 6.05, 6.06, 6.07, 6.12, 7.02, 7.03 |
| `C_CHARDIR` | 2.01, 4.04, 4.11, 4.18, 8.01 |
| `C_CURSORKIND` | 2.06, 4.03, 4.11 |
| `C_TARGETCURS` | 2.09, 4.08, 6.01, 6.02, 6.03 |
| `C_CLILEFT` | 2.05, 3.07 |
| `C_CHARPTR` | 1.03, 1.04, 1.05, 1.06, 2.01, 2.02, 2.03, 2.04, 2.09, 2.12, 2.13, 2.15, 3.09, 4.03, 4.04, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.17, 4.18, 5.02, 5.07, 5.11, 6.03, 6.04, 6.07, 6.08, 6.09, 6.10, 6.11, 6.14, 6.16, 6.18, 7.01, 8.01, 8.03, 10.01, 11.01, 11.03, 11.04, 11.05 |
| `C_LLIFTEDID` | 2.09, 6.08, 6.10 |
| `C_LSHARD` | 2.06, 3.05 |
| `C_POPUPID` | 6.18 |
| `C_JOURNALPTR` | 2.08, 4.02, 4.05, 4.06, 4.07, 5.01 |
| `C_SKILLCAPS` | 2.07, 4.16 |
| `C_SKILLLOCK` | 2.07, 4.16, 7.04 |
| `C_SKILLSPOS` | 2.07, 4.16, 6.14 |
| `C_CLILOC` | 12.02 |
| `C_BUFFTIMERS` | 12.02, 12.03 |
| `C_MULTILIST` | 2.13, 4.03, 8.03 |
| `C_WORLDGRID` | 2.13, 4.03, 8.03 |
| `C_STATICVT` | 2.13, 4.03, 8.03 |
| `B_TARGPROC` | 6.02 |
| `B_CHARSTATUS` | 2.01, 2.02, 2.03, 2.15, 4.10, 4.17, 6.03, 6.11, 7.01, 11.04, 11.05 |
| `B_ITEMID` | 1.03, 1.04, 1.06, 2.01, 2.02, 2.03, 2.04, 2.09, 2.10, 2.15, 3.09, 4.03, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.17, 4.18, 5.02, 5.03, 5.06, 5.07, 5.11, 6.02, 6.03, 6.04, 6.07, 6.08, 6.09, 6.10, 6.11, 6.14, 6.16, 6.18, 7.01, 10.01, 10.02, 11.01, 11.03, 11.04, 11.05 |
| `B_ITEMTYPE` | 1.06, 2.01, 2.02, 2.03, 2.09, 2.13, 2.15, 3.09, 4.03, 4.10, 4.11, 4.14, 4.15, 5.06, 5.07, 6.03, 6.04, 6.07, 6.08, 8.03, 10.01, 10.02, 11.04, 11.05 |
| `B_ITEMSTACK` | 2.02, 4.14, 4.15, 6.03, 6.09, 6.10, 10.01, 10.02 |
| `B_STATNAME` | 1.04, 2.01, 2.04, 4.11, 4.12, 4.13, 4.14, 4.15, 4.17, 4.18, 6.14, 11.01 |
| `B_STATWEIGHT` | 2.04, 4.11, 4.15 |
| `B_STATAR` | 2.04, 4.11 |
| `B_STATML` | 2.04, 4.11, 4.18, 6.14, 11.01 |
| `B_CONTSIZEX` | 2.10, 5.06 |
| `B_CONTX` | 2.10, 4.09, 4.10, 5.07, 5.08, 6.08 |
| `B_CONTITEM` | 2.10, 5.03, 5.06, 5.07 |
| `B_CONTNEXT` | 2.10, 2.14, 4.09, 4.10, 5.03, 5.06, 5.07, 5.08, 5.09, 5.10, 5.11, 5.14, 10.01, 10.02, 10.03, 12.01, 12.02, 12.04, 12.05 |
| `B_ENEMYHPVAL` | 9.02 |
| `B_SHOPCURRENT` | 10.01, 10.02 |
| `B_SHOPNEXT` | 10.01, 10.02 |
| `B_BILLFIRST` | 10.03 |
| `B_SKILLDIST` | 2.07, 4.16, 6.14 |
| `B_SYSMSGSTR` | 2.09, 5.01 |
| `B_LLIFTEDTYPE` | 2.09, 6.10 |
| `B_LLIFTEDKIND` | 2.09, 6.08, 6.10 |
| `B_LANG` | 1.07 |
| `B_TITHE` | 2.04, 4.11, 4.18 |
| `B_FINDREP` | 2.02, 10.01 |
| `B_SHOPPRICE` | 10.01, 10.02 |
| `B_GUMPPTR` | 5.07, 6.08 |
| `B_ITEMSLOT` | 1.06, 4.11 |
| `B_PACKETVER` | 6.08, 6.13, 6.16 |
| `B_LTARGTILE` | 2.09, 3.03, 6.05 |
| `B_LTARGX` | 2.09, 3.03, 6.04 |
| `B_STAT1` | 2.04, 6.14 |
| `B_JCOL` | 2.08, 4.02, 4.05, 4.06, 4.07, 5.01 |
| `B_JKIND` | 2.08, 4.02, 4.05, 4.06, 4.07, 5.01 |
| `B_JNEXTPTR` | 2.08, 4.02, 4.05, 4.06, 4.07, 5.01 |
| `B_POS` | 1.05, 2.02, 2.03, 2.12, 2.13, 2.15, 3.09, 4.03, 4.04, 4.10, 4.11, 4.14, 4.15, 5.07, 6.03, 6.04, 6.08, 6.16, 8.01, 8.02, 8.03, 11.04, 11.05 |
| `B_NEXTCX` | 3.06, 5.08 |
| `B_CLITOP` | 2.05, 3.07 |
| `B_LTARGID` | 2.09, 3.03, 6.02, 6.03, 6.06 |
| `B_LTARGKIND` | 2.09, 3.03, 6.02, 6.04, 6.05, 6.06 |
| `B_LSPELL` | 2.09, 3.05, 7.03 |
| `B_LSKILL` | 2.09, 3.05, 6.01, 7.02 |
| `B_PATHPROLOGUE` | 8.02 |
| `B_PROPFLAG` | 5.13, 6.14, 6.17, 11.02 |
| `B_LHAND` | 2.09, 3.04 |
| `B_RHAND` | 3.04, 6.12 |
| `B_BUFFVEC` | 2.14, 5.14, 12.01, 12.02, 12.03, 12.04, 12.05 |
| `B_BUFFSIZE` | 2.14, 5.14, 12.01, 12.02, 12.03, 12.04, 12.05 |
| `B_STLHEAD` | 12.02, 12.03 |
| `B_CLILOCKEY` | 12.02 |
| `B_MULTINEXT` | 2.13, 4.03, 8.03 |
| `B_GRIDNEXT` | 2.13, 4.03, 8.03 |
| `B_GRIDSIZE` | 2.13, 4.03, 8.03 |
| `B_MULTIOWNER` | 2.13, 4.03, 8.03 |
| `E_REDIR` | 5.01, 5.02, 5.03, 5.04, 5.05, 5.06, 5.09, 5.11, 5.12, 5.13, 5.14, 5.15, 5.16, 6.01, 6.03, 6.04, 6.05, 6.06, 6.07, 6.08, 6.10, 6.11, 6.12, 6.13, 6.14, 6.16, 6.17, 6.18, 7.01, 7.02, 7.03, 7.04, 7.05, 7.06, 7.07, 7.08, 7.09, 7.10, 7.11, 7.12, 7.14, 7.15, 8.01, 8.02, 8.03, 8.04, 8.05, 8.06, 9.01, 9.03, 11.02, 11.03, 12.01, 12.05 |
| `E_OLDDIR` | 5.01, 5.02, 5.03, 5.04, 5.05, 5.06, 5.09, 5.11, 5.12, 5.13, 5.14, 5.15, 5.16, 6.01, 6.03, 6.04, 6.05, 6.06, 6.07, 6.08, 6.10, 6.11, 6.12, 6.13, 6.14, 6.16, 6.17, 6.18, 7.01, 7.02, 7.03, 7.04, 7.05, 7.06, 7.07, 7.08, 7.09, 7.10, 7.11, 7.12, 7.14, 7.15, 8.01, 8.02, 8.03, 8.04, 8.05, 8.06, 9.01, 9.03, 11.02, 11.03, 12.01, 12.05 |
| `E_EXMSGADDR` | 5.02 |
| `E_ITEMPROPID` | 5.13, 6.14, 6.17, 11.02 |
| `E_ITEMNAMEADDR` | 5.13, 6.14, 6.17, 11.02 |
| `E_ITEMPROPADDR` | 5.13, 6.14, 6.17, 11.02 |
| `E_ITEMCHECKADDR` | 5.13, 6.14, 6.17, 11.02 |
| `E_ITEMREQADDR` | 5.13, 6.14, 6.17, 11.02 |
| `E_PATHFINDADDR` | 8.02 |
| `E_DRAGADDR` | 6.10 |
| `E_SYSMSGADDR` | 5.01 |
| `E_MACROADDR` | 5.03, 5.04, 5.05, 5.06, 5.12, 5.14, 5.15, 5.16, 6.01, 6.03, 6.04, 6.05, 6.06, 6.07, 6.12, 7.01, 7.02, 7.03, 7.06, 7.07, 7.08, 7.09, 7.10, 7.11, 7.12, 7.14, 7.15, 8.01, 8.03, 8.04, 8.05, 9.01, 9.03, 12.01, 12.05 |
| `E_SENDPACKET` | 6.08, 6.11, 6.13, 6.16, 6.18, 7.04, 7.05, 11.02 |
| `E_SENDLEN` | 6.08, 6.11, 6.13, 6.16, 6.18, 7.04, 7.05, 11.02 |
| `E_SENDECX` | 6.08, 6.11, 6.13, 6.16, 6.18, 7.04, 7.05, 11.02 |
| `E_CONTTOP` | 5.09 |
| `E_STATBAR` | 5.11, 11.03 |
| `E_MACROTAB` | 5.03, 5.04, 5.05, 5.06, 5.12, 5.14, 5.15, 5.16, 6.01, 6.03, 6.04, 6.05, 6.06, 6.07, 6.12, 7.01, 7.02, 7.03, 7.06, 7.07, 7.08, 7.09, 7.10, 7.11, 7.12, 7.14, 7.15, 8.01, 8.03, 8.04, 8.05, 9.01, 9.03, 12.01, 12.05 |
| `E_NEWOBJ` | 5.01, 5.02 |
| `E_MSGGATE` | 5.01, 5.02 |
| `E_MSGFLAGA` | 5.01, 5.02 |
| `E_MSGFLAGB` | 5.01, 5.02 |
| `E_PATHFINDMID` | 8.02 |
| `F_EXTSTAT` | 2.04, 4.11, 4.18, 6.14, 11.01 |
| `F_EVPROPERTY` | 5.13, 6.14, 6.17, 11.02 |
| `F_MACROMAP` | 5.03, 5.04, 5.05, 5.06, 5.12, 5.14, 5.15, 5.16, 6.01, 6.03, 6.04, 6.05, 6.06, 6.07, 6.12, 7.01, 7.02, 7.03, 7.06, 7.07, 7.08, 7.09, 7.10, 7.11, 7.12, 7.14, 7.15, 8.01, 8.03, 8.04, 8.05, 9.01, 9.03, 12.01, 12.05 |
| `F_EXCHARSTATC` | 2.01, 4.17 |
| `F_PATHFINDVER` | 8.02 |
| `F_FLAGS` | 2.12, 2.13, 4.03, 8.03 |
| `F_SYSMSGDIRECT` | 2.09, 5.01 |
| `F_JOURNALDIRECT` | 2.08, 4.02, 4.05, 4.06, 4.07, 5.01 |
| `F_SENDTHISCALL` | 6.08, 6.11, 6.13, 6.16, 6.18, 7.04, 7.05, 11.02 |
| `F_DRAGFASTCALL` | 6.10 |
| `F_BLOCKINFOFAST` | 8.03, 8.04, 8.05, 8.06 |
| `F_PROPFAST` | 5.13, 6.14, 6.17, 11.02 |

The house-piece fields (`C_MULTILIST`, `C_WORLDGRID`, `C_STATICVT` and their `B_` offsets) are read by every
`path` check, but a wrong value shows only next to a player house: for those, run 2.13 and 8.03 standing by one.

### Fields no script can reach

| Field | Why |
|---|---|
| `C_TARGETCNT` | No code reads it any more (only `uoclidata.pas` declares it). |
| `B_EVSKILLPAR` | No code reads it: the skill-lock event is sent as a packet (`exevent SkillLock`, through `C_SKILLLOCK`). |
| `B_MEMBASE` | No code reads it: the event cave's base is the image base + `$600` (`uoevents.pas`, `uovariables.pas` keep the old line as a comment). |
| `E_SLEEPADDR` | `event Sleep` has no handler in EasyUO Reforged, so nothing calls it. |
| `E_SKILLLOCKADDR` | `event SkillLock` is forwarded to `exevent SkillLock`, a packet: nothing calls it. |
| `F_PACKETVER` | No code reads it: the drop packets read `B_PACKETVER`. |

## Developer switches and dry runs

The `set` lines at the top of the script are developer switches, not options:

| Switch | Effect |
|---|---|
| `%ST_UNATTENDED 1` | No windows; every HUMAN check is answered SKIP; `:memory:` database. |
| `%ST_SIM_REPEAT 1` | With `ST_UNATTENDED`: every HUMAN check is answered Repeat once, then Pass. |
| `%ST_REPORT 0` | No report file (`execute` is not used); every line still goes to `log`. |
| `%ST_NOSTOP 1` | Go on after stage 1 fails, to walk every stage without a client. |
| `%ST_FAST 1` | Every wait and timeout is 0. |
| `%ST_STAGES` | The stages an unattended run runs, one digit per stage. |
| `%ST_ONE_CHECK` | An unattended run of one check (`4.12`). |

A dry run without a client, from a copy with `ST_UNATTENDED 1` and `ST_REPORT 0`, must end with `halt`:

    EUOCli check tools\EUOSelfTest\EUOSelfTest.euo --strict
    EUOCli run <the copy> --timeout 120

It stops after stage 1, as it must with no client. With `ST_NOSTOP 1`, `ST_FAST 1` and `ST_STAGES
111111111111` it walks every stage (about 35 s) and logs a `DEV:` line if a stage's check count in
`st_counts` is out of date: the progress bar's total comes from that table.

One stage on a client, while you fix a table value: a copy with `ST_UNATTENDED 1`, `ST_REPORT 0` (so it needs
no `execute`) and `ST_STAGES` set to that stage (`000100000000` for stage 4), run on the client:

    EUOCli run <the copy> --client 1 --timeout 600

The report lines come out as `log` lines, and the HUMAN checks are SKIPs. The copy uses a `:memory:`
database, so a run that crashes leaves no clean-up rows behind: to keep them, make its `sql open` open
`EUOSelfTest.db`.

## Keeping it complete

- `tests\tools\CheckSelfTestCoverage.ps1` (run by `tests\run_tests.ps1`) fails when a variable or command of
  the interpreter is mentioned neither here nor in `tests\euo\all-commands-test.euo`. The language, menu,
  namespace, `sql` and `str` cases live there.
- `tests\DocsLintTests.pas` runs the script checker over this file: `EUOCli check --strict` must report nothing.
- A new client command or `#variable`: add a check with a new ID, its fields, and a row in this README.
  Keep the count in `st_counts` right.

## Notes for authors

- Everything lives in one file: a called script cannot `gosub` the caller's subs. Tool variables start with
  `st_`, table-field groups with `fx_`.
  Variable names ignore case, so a developer switch (`%ST_...`) must not share its name with a tool
  variable (`%ST_ONLY` was `%st_only`).
- Every check sub takes three words (`id what fields`) and reads `%st_a` (observed) and `%st_e` (expected):
  a value with spaces survives as one `gosub` parameter, but a `what` must not start with `#` (a word that
  starts with `#` is read as a variable).
- An observed `N/A` never passes, except in `st_eqna` (a check that expects `N/A`).
- A text the script searches the journal for comes from `st_token` and is never shown in the panel.
- A condition for `st_ok` is set with `#true` / `#false` or a comparison: `set %st_c 1` reads as false.
- A `+` line joins the line before it with everything after the `+`, its space too: a prompt goes on with
  `+$...` or `+_...`, never `+ $...` (that makes a second word, and `set` keeps only the first one).
- Everything the client says goes through `st_pace` first: the client queues speech once its spam meter
  reaches the `SpamLimit` option (30 by default; each line adds its length, and the meter drains by 30 a
  second, but only in the game tick and rounded down: 20 to 26 a second on client.exe 7.0.117.33, 13 or less
  on client_beta 7.0.117.31, whose two tick functions both run the drain), and a queued staff command answers
  late ("[Spam detected, speech queued for N seconds]"). The script paces at 12 characters a second and slows
  down by itself when the client still queues a staff command; the SUMMARY says how often
  (`speech_queued_by_the_client`). A long clean-up takes a few minutes. A new `msg` or speech macro needs the same call. The clean-up
  reads every staff-set value back: with speech queued, an earlier command's "Property has been set" had
  passed for the restore.
- Keep each staff command short: the client cut a 104-character line (`[serial ... set` with three
  properties lost its last one), so set many properties with several commands.
- The client refuses an item move soon after another one with its own "You must wait to perform another
  action" (seen with `event macro 24`, several seconds after a disarm): wait, and try again while the
  journal says so (`st_arm_try`).
- A click sent by `click` does not answer the target cursor that writing `#TargCurs` shows, and Target
  Self (`event macro 23`) clears it without calling its handler: 6.02 asks you to click.
- `exevent Drag` only asks the server: the client's `#LLifted...` values change only with `event Drag`.
- On ModernUO, lifting part of a stack leaves the lifted part with the old ID and the rest as a new pile;
  dropped into a container without a position, it joins a pile of the same kind again.
- A skill bonus stops at the skill's cap (ModernUO `Skill.Value`): 6.14 lowers a base near the cap first.
- ModernUO NPCs don't hear a hidden character (a GM is often hidden): stage 10 unhides you until the
  clean-up. Staff buy from vendors for free there, so 10.03 counts what arrives in the backpack; the gold is
  checked only for a character without staff commands.
- The shard refuses a second mount ("Please dismount first"). When stage 11 begins with you riding, 11.04
  gets you off first and the end of the stage gets you on that mount again (the object new next to you
  after the dismount; an ethereal mount goes to the backpack, and the CLEAN-UP line then asks you to mount it
  by hand). Not found by `#FindRep`: it read 255 for every mobile on client_beta 7.0.117.31. 11.05
  runs only after 11.04 put you on the horse: a double click on yourself also dismounts your own mount, or
  opens the paperdoll, and `#MountID` is `N/A` either way.
- Protection is a toggle: it stays on until it is cast again, even after logging out or dying. 12.01 counts
  the buffs before and after casting it: one more means the cast turned it on (the end of stage 12 casts it
  again), one fewer means it was on already (cast again at once, after the cast recovery). The INFO line
  12.01.prot says which. The buff bar is closed again at the end if the stage opened it.
