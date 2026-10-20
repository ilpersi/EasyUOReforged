# EUO SelfTest

A guided test of **every `#variable`, `event`/`exevent`, `event macro` and client command** of EasyUO
Reforged against a running UO client. It is a plain EasyUO script, so it exercises the real script path
(parser, interpreter, engine) and works with any client version.

## Running it

1. Start the UO client and log a character in. (No client is fine too: the client stages are skipped and the
   language stage still runs.)
2. In EasyUO Reforged open `tools\EUOSelfTest\EUOSelfTest.euo` in a tab and press **Play**.
3. A small always-on-top panel appears (move it with `%ST_PANEL_X/Y` so it does not cover the game).
   The script performs each step, checks what the engine can read by itself (**AUTO**) and asks you only about
   what a script cannot see (**HUMAN**: journal text, an animation, an item in a hand). Buttons:
   `Pass` `Fail` `Skip` `Repeat` (send the same step again) `Stop` (ends the run, the report is still written).
4. At the end the report is written and shown in a copyable memo.

The UO window stays fully usable while the panel is open.

## Stages and switches

Edit the `%ST_DO_*` flags at the top of the script (1 = on):

| Stage | Flag (default) | What it covers |
|---|---|---|
| 1 | `ST_DO_VARS` (1) | every read-only `#variable`: N/A without a client, range/consistency checks, one confirmation per group against the game's own gumps |
| 2 | `ST_DO_WRITES` (1) | every read/write variable: write, read back, restore; visible effects (window size, gump position, target cursor, client title) confirmed by you |
| 3 | `ST_DO_MACROS` (1) | `event macro` numbers from the wiki table with an AUTO check wherever a variable shows the result; optional steps (door, bandage, always run, abilities, targeting system) ask first with Pass/Skip |
| 4 | `ST_DO_EVENTS` (1) | `event` / `exevent` family: sysmessage, exmsg, property, pathfind, skill/stat locks, popup, statbar, drag/drop/equip and `event macro 24` (need `ST_ITEM_ID`), renamepet (needs `ST_PET_ID`); an optional, warned `hideItem` step that leaves the test item hidden on the ground until you walk about 20 tiles away and back |
| 5 | `ST_DO_CMDS` (1) | `msg`, `key`, `target`, `click` (right-click closes a gump; double-click on yourself is confirmed by you), `move`, `tile`, `getUOTitle`, `uoXL swap`, journal commands, `onHotKey` (you press F9) |
| 6 | `ST_DO_SHOP` (0) | `getShopInfo` / `setShopItem` (open a vendor BUY window first) |
| 7 | `ST_DO_COMBAT` (0) | `event macro 27` / `53` - **attacks a monster**, asks first |
| 8 | `ST_DO_LANG` (1) | language, menu, namespace and the rest through `tests\euo\all-commands-test.euo` (run in its embedded mode) |
| 9 | `ST_DO_BUFFS` (0) | `scanBuffs` and the `#buff...` variables (port addition). Open the buff bar and put 2-3 buffs on the character, one with a timer (Bless, Curse, Strength; Hiding has none). AUTO checks on every field of every buff, the time counting down over 12 s, `scanBuffs <icon id>`, and the bar closed with `event macro 57`; you confirm names and times against the in-game tooltips |

Stages 1 and 2 also list the buff variables (read-only `#buffCnt` ... `#buffTime`, and a write/restore of
`#buffIndex`, and `#buffBarOpen`); they need no buffs. Stage 9 is off by default, like the vendor stage, because it needs buffs on the
character; the report lines of the buffs it found (`9.01_b1.buff` ...) show icon id, cliloc number and seconds left.

Never run by the tool: `event macro 20` (quit game), `terminate uo`, `uoXL new`, `shutdown`.

`%ST_ITEM_ID` / `%ST_PET_ID` are EasyUO ids (the base-26 letters you see in `#findID`, e.g. `IPJRJMD`), not the
numbers the server uses. Pick any item from your backpack; for the equip test use a wearable one (e.g. a dagger).
`%ST_UNATTENDED 1` never shows the panel and answers every HUMAN question `SKIP` (dry runs).

## The report

`selftest-<ReforgedVer>-<client version>-<date>-<time>.md`, written next to the folder EasyUO was started from
(the full path is shown at the end; `selftest-*.md` is in `.gitignore`, so reports are never committed by accident). One line per item:

    - [PASS|FAIL|NOTE|SKIP|INFO] <id> <what> [AUTO|HUMAN] observed=<value>

Underscores stand for spaces (EasyUO tokens are space-delimited). `NOTE` marks a **known difference between the
old wiki and the real client** (for example `#lSpell` numbers Magic Arrow 5, `#cursKind` is the facet,
`#shopItemName` is a cliloc number). Run it on `client.exe` and on `client_beta.exe` and diff the two files.

The file is written through the existing `Execute` command (batched `cmd /c echo` lines, so a console window
flashes briefly); every text goes through a sanitizer first because `& | < > ^ " %` would break `cmd`. The memo at
the end always holds the same text if the file could not be written.

## Keeping it complete

`tests\tools\CheckSelfTestCoverage.ps1` (called by `tests\run_tests.ps1`) reads the variable and command lists from
`parser\EuoInterpreter.pas` and fails when a name is not mentioned by `EUOSelfTest.euo` or `all-commands-test.euo`.
Add a case here when you add a variable or a command.

## Notes for authors

- Everything lives in one file: a CALLed script cannot `gosub` the caller's subs. Tool variables start with `st_`.
- A variable is only expanded when it is a separate, space-delimited word; booleans are `-1`/`0` (never compare to 1);
  ids are base-26 strings, not numbers.
- Dry-run it without a GUI with a small `TExecutor` harness (see `tests\LiveClientTests.pas` for the pattern) and
  `%ST_UNATTENDED 1` (and `%ST_LANG_NOMENU 1` for stage 8, whose menu checks need the real window).
