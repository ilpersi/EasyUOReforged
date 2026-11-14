# Variables that misread on client_beta 7.0.117.31

Status: static analysis done on 2026-11-14; the owner agreed to the four fixes the same day and they are
made (see "Changes made" at the end). Live probes in `tests/tools/` are written; their results go below as
they are run. It answers the 14 failures of the self-test run of 2026-11-14 on the beta (394 pass, 14 fail),
where the same script passes on `client.exe` 7.0.117.33.

## Sources

| Build | File | Identity |
|---|---|---|
| beta 7.0.117.31 | `client_beta.exe` | stamp `6AD6CEB3`, relocatable, layout `SysVarModernLayout` + `SysVarModernAddrs_6AD6CEB3` |
| 7.0.117.33 | `client.exe` | stamp `6AD994F1`, fixed base, floors to milestone 0 (7.0.117.1) |

Both in `D:\Program Files (x86)\Electronic Arts\Ultima Online Classic\`. Read with capstone through
`tools/EUOMigrate/euomig` (`pe.py`, `disasm.py`). All addresses are link-time addresses. No live read was
made, nothing was sent to a client. The self-test outputs are the `beta*.out` files of the run, and the .33
reports are `selftest-*-7.0.117.33-*.md`. Shard facts come from ModernUO (`D:\ModernUo\modernuo`).

## Summary

| Self-test check | Cause | Proposed change |
|---|---|---|
| 2.09, 6.08.free, 6.10 (`#LLiftedKind/Type/ID`), and `event Drag` | wrong `B_LLIFTEDKIND` / `B_LLIFTEDTYPE`; `event Drag` then never lifts | `B_LLIFTEDKIND $44`, `B_LLIFTEDTYPE $FFFFFFD0` for `6AD6CEB3` |
| 2.02.rep, 10.01.rep (`#FindRep` 255) | notoriety moved 8 bytes | `B_FINDREP $214` for `6AD6CEB3` |
| 5.11.hp, 11.03 (`#ContHP`) | status gump hits moved +$90 | modern builds: read at `B_STATNAME+$26` (no new field) |
| 9.02 (`#EnemyHits` N/A) | `C_ENEMYHITS` finds the targeting system's gump, not the bar the attack opens | new scan pattern for the attack bar; `B_ENEMYHPVAL $154` |
| 7.03.lspell (`#LSpell` 0) | client behaviour on **both** builds | none (self-test expectation) |
| 6.01 `#LSkill` 2 | the value the script wrote | none |
| 9.03.attack (`#EnemyID` N/A) | the shard sent 0xAA 0 (only writer of the field) | none known: live probe needed |
| 7.08, 7.15 (bandages) | same client code on both builds | none (not a table problem) |
| 8.02 (PathFind one short) | the beta's own walk (`docs/pathfinding.md`) | none |

## 1. `#LLiftedKind`, `#LLiftedType`, `#LLiftedID`, `event Drag`

**Cause.** `#LLiftedKind` reads the dword at `C_LLIFTEDID + $34` = `$B5B734`. On .31 that is the lifted
amount (word, 0 when nothing is lifted) followed by an options byte at `$B5B736` that is 1, hence 65536.
`TUOEvent.Drag` (`uo/uoevents.pas`) exits when `#LLiftedKind > 0`, so **`event Drag` never called the
client**. `#LLiftedID` stayed 0 (`YC`) during the "lift" because nothing was lifted. 6.10.dropped passed
only because the dagger never left the backpack.

**Evidence.**
- `C_LLIFTEDID` is right: both scan patterns resolve to `$B5B700`, the only writer is the pick-up function
  `$5AAE90` (`E_DRAGADDR`, fastcall item/amount), `mov [B5B700],[item+$118]`.
- That function stores the item's type `word [item+$70]` (`B_ITEMTYPE`) at `$B5B730` (id **+$30**), the
  amount at `$B5B734`, and sets `dword [$B5B744] = 1` (id **+$44**).
- .33's pick-up `$5BE9B0` does the same with its own table: id `$A59110`, type `word [item+$3A]` at
  `$A5910C` (id-4 = its `B_LLIFTEDTYPE 4`), `dword [$A59148] = 1` (id+$38 = its `B_LLIFTEDKIND $38`).
- The macro executor tests the flag before every item macro: .31 `$570B80` tests `[$B5B744]` 19 times,
  .33 `$596980` tests `[$A59148]` 19 times, in the same cases. The drop/clear code zeroes `$B5B744`
  (`$4ED913`, `$5A8099`, `$5C09FB`, `$5C0AE9`, `$60D3F3`).

**Proposed change.** In `SysVarModernAddrs_6AD6CEB3`: `B_LLIFTEDTYPE $FFFFFFD0` (type $30 after the id) and
`B_LLIFTEDKIND $00000044`. The old beta's `$24` / `$34` stay in the layout (measured there, exe gone).
EUOMigrate kb `7.0.117.31-6AD6CEB3`: the same two values.
**Test.** `CstDbModernBuildTests`: stamp `6AD6CEB3` gives the two values. Live: `tests/tools/LiftProbe.euo`
(kind 0 before, `event Drag` a dagger, id/type/kind 1 during, drop, kind 0 after).

## 2. `#FindRep`

**Cause.** The notoriety is a dword in the mobile at `+$32C` = id `+$214`; `B_FINDREP` `$20C` (measured on
the old beta) reads 8 bytes too early.

**Evidence.** .33's notoriety getter `$5BD600`: `mov eax,[ecx+$25C]; cdq; idiv 100; mov eax,edx`, and
`$25C` = its `B_ITEMID $A8` + `B_FINDREP $1B4`. .31 inlines the same getter on `[obj+$32C]` (`$4F8FC7`,
`$5A0BCF`, `$604334`), each `mod 100` and indexing the notoriety hue table (`$7EFE50`, the same values as
.33's `$715BC4`). The setters (.31 `$5A6560` / `$5A6580`, .33 `$5BD5B0` / `$5BD5D0`) write those offsets.
No code of .31 uses a byte at `+$324`.

**Proposed change.** `B_FINDREP $00000214` in `SysVarModernAddrs_6AD6CEB3`. FindItem still reads one byte, as
the original does. The read buffer (`$400`) covers `$32C`. kb: the same value.
**Test.** Table test as above. Live: `tests/tools/FindRepProbe.euo` (your character 1..7, a vendor 7).

## 3. `#ContHP`

**Cause.** `TUOCmd.GetCont` reads the hits of a "status gump" at `Buf + B_CONTNEXT + $92` (from EasyUO 1.5,
no table field). On .31 the status gump keeps them `$90` further on.

**Evidence.**
- The hits update handler walks the gump list and, for status gumps (the mobile at `+$4C` or its serial at
  `+$50`), writes the current and the maximum hits: .31 `$5C0FF8`/`$5C1022` words `+$17C` (max) / `+$17A`
  (current); .33 `$46E4CB`/`$46E4D7` words `+$EC` / `+$EA`. The .33 status gump constructor `$524C10` sets
  `+$EA`/`+$EC` to 0, the .31 one `$5DE890` writes `+$17C`.
- The status gump is also the object `#Hits` reads: both constructors store the gump in the mobile at id
  `+$10` (.31 `[mobile+$128]`, .33 `[mobile+$B8]`), which is `GetStat`'s pointer, and clear the name buffer
  at `B_STATNAME` (.31 `+$154`, .33 `+$C4`). `#Hits` reads `B_STATNAME+$26`.
- So `B_STATNAME+$26` is the current hits word on both: .33 `$C4+$26 = $EA`, .31 `$154+$26 = $17A`. On every
  fixed-base milestone from 4.0.0c on, `B_STATNAME - B_CONTNEXT = $6C`, so `B_CONTNEXT+$92 = B_STATNAME+$26`.
  (2.0.0 to 4.0.0b differ by 8, which is why the change below is for the modern builds only.)

**Proposed change.** In `GetCont`: modern builds read at `Buf+Cst.BSTATNAME+$26`, every other build keeps
`Buf+Cst.BCONTNEXT+$92` byte for byte. No new field. (Alternative: a new layout field; not proposed.)
The old beta read 0 here too (October self-test, INFO); this change covers it.
**Test.** A fake-client test in `CstDbModernBuildTests` (status gump with hits at `+$17A`). Live:
`tests/tools/ContHPProbe.euo` (`event StatBar #CharID`, `#ContHP` = `#Hits` in percent).

## 4. `#EnemyHits` (N/A during combat)

**Cause.** .31 has two health-bar gumps for other mobiles:
- the **targeting system's** bar, `$194` bytes (constructor `$612D90`), held in `[$CB2F90]`. It opens when
  a mobile is *selected* (macros 50 to 52, `$5758C0`, `$6125B0`). Serial `+$150`, max `+$154`, current `+$158`.
- the **attack** bar, `$160` bytes (constructor `$610420`), opened by the 0xAA "change combatant" handler
  `$5D1730` -> `$6129F0` for every new enemy, held in `[$CB2FA0]`, tagged `+$14C = 2`. Serial `+$158`,
  current `+$154`, max `+$150` (the constructor sets both to 1, the 0x2D/0xA1 handler `$5C0F84` updates them).

`C_ENEMYHITS`'s scan patterns find `$CB2F90`. In 9.02 no mobile had been selected in that run, so the global
was 0 and `#EnemyHits` read N/A for the 15 s. The `$158` set on 2026-11-14 (`f895fa0`) is right for the
targeting bar, which is not the enemy's bar.

**Evidence that the attack bar is the one EasyUO means.** .33's 0xAA handler `$474C10` stores `C_ENEMYID`
(`$8D69A4`) and opens the bar `C_ENEMYHITS` (`$9A564C`) points to (`$544A80`); .31's `$5D1730` stores
`C_ENEMYID` (`$B5B7EC`, the scan's value, same shape) and opens the attack bar. Neither client clears its
global when the bar closes (.33 writes `$9A564C` only there and in an init routine; .31 writes `$CB2FA0` only
there), so the `$FEEDBEEF` check guards both the same way. The base gump constructor `$54D290` writes the
`$FEEDBEEF`.

**Proposed change.**
- `ScannerTable_Modern`: one more `C_ENEMYHITS` pattern, last of its field (so it decides), from `$6129F0`:
  `A111111111890D11111111C7416400000000C7415C0000000089415885C0740389485CA11111111185C0890D111111110F44C1C7814C01000002000000`,
  joker `$11`, Mode 3, AddOffset1 7. One match in .31, resolving to `$CB2FA0`. The kind-1 twin (`$6128C0`, the
  last-target bar at `$CB2F9C`) differs in the `+$14C` value and order, so it doesn't match. The same line goes in
  `tools/EUOUpdater/EUO Updtr Strings modern.txt`.
- `SysVarModernLayout`: `B_ENEMYHPVAL $154` (current; the getter takes the maximum at `-4` = `$150`).
- kb `6AD6CEB3`: `C_ENEMYHITS $CB2FA0`, `B_ENEMYHPVAL $154`.
- Unknown: whether the pattern also matches the old beta `6AC94360` (its exe is gone). Its explicit
  `C_ENEMYHITS $C8B858` was found while a dragon was selected, so it was the targeting bar there too.

**Test.** Table test (scan of a synthetic code buffer with the pattern if the suite has one for patterns;
otherwise layout value). Live: `tests/tools/EnemyHitsProbe.euo` (attack a rat, `#EnemyHits` 0..100, falls).

## 5. `#LSpell` stays 0 after `event macro 15 4` — client behaviour

Both builds' macro executor casts with "remember as last spell" off: .31 case 15 `$570F42` calls the cast
function `$45CD80` with `push 0`, which stores `[$B291D8]` only when that argument is set (`$45CE51`,
`$45CEDA`). .33 case 15 `$596D4F` calls `$5E6230(spell, 0, 0)`, which stores `[$A01DE4]` only when its
second argument is set (`$5E6306`, `$5E6394`). The spellbook and spell-icon callers pass 1 (.31 `$479C01`,
`$482DD6`). The .33 PASSes were left over from the previous run's `set #LSpell 5` (7.03.last): its first run
(2026-11-13 16:16) read 0. **For the self-test session:** 7.03.lspell expects what neither client does.

`#LSkill` after `event macro 13 1`: the script writes `set #LSkill 2` just before (6.01), so 2 is "unchanged",
as on .33.

## 6. `#EnemyID` N/A one second after `event macro 53` — not settled

The only writer of `$B5B7EC` is the 0xAA handler, so the shard sent 0xAA with serial 0 (ModernUO sends it
when the combatant becomes null). Macro 53 is the same code on both builds (.31 `$575540`, .33 `$595FD0`:
attack the selected mobile). On .31 stage 9.02 fought for the full 15 s (`#EnemyHits` never fell), on .33 it
stopped at the first hit. A probe can tell whether the rat is still alive and what `#EnemyID` reads after
macro 53. Not a table problem by this evidence.

**Probe (2026-11-14):** not reproduced. With the same steps but war mode off and no 15 s fight before,
`#EnemyID` stayed the rat for 4 s after macro 53. The difference from the self-test run is that 15 s
fight in war mode (9.02 waited the full time because `#EnemyHits` never fell). With the `#EnemyHits` fix 9.02
ends at the first hit as on .33, so the next self-test run on the beta will show whether 9.03 still fails.

## 7. Not table problems

- **Bandages (7.08, 7.15).** Macros 58 and 59 are the same code on both builds: find a bandage, then send
  0xBF 0x2C (bandage serial, target serial): .31 `$575690` -> `$5AACF0`, .33 `$596130` -> `$5BE8D0`. "Who will
  you use the bandages on?" is ModernUO's own answer to 0xBF 0x2C (`BandageTargetRequest`), so the packet
  reached the shard on .31. Why no bandage was used is not settled (one guess: the client picked another
  bandage stack than the one the script counts).
- **PathFind one tile short (8.02).** `docs/pathfinding.md`: the beta's own walk ends 1 or 2 tiles short near
  its target.

## Not settled

- `#EnemyID` after macro 53 (section 6): not reproduced by the probe; the next self-test run will show.
- Whether the new `C_ENEMYHITS` pattern matches the old beta `6AC94360` (no exe).
- Bandages: why the count stayed 10.

## Changes made (2026-11-14, owner's yes)

- `uo/uoclidata.pas`: `SysVarModernAddrs_6AD6CEB3` + `B_LLIFTEDTYPE $FFFFFFD0`, `B_LLIFTEDKIND $44`,
  `B_FINDREP $214`; `SysVarModernLayout` `B_ENEMYHPVAL $154`; `ScannerTable_Modern` one more `C_ENEMYHITS`
  pattern (last of its field).
- `uo/uocommands.pas`: `GetCont` reads `#ContHP` at `B_STATNAME+$26` on the modern builds.
- `tools/EUOUpdater/EUO Updtr Strings modern.txt`: the same `C_ENEMYHITS` line.
- `tools/EUOMigrate/kb/7.0.117.31-6AD6CEB3.json.gz`: the five values, and the `C_ENEMYHITS` signature replaced
  by the new one; `7.0.117.1-6AC94360.json.gz`: `B_ENEMYHPVAL` back to `$154` (byte for byte as before
  `f895fa0`).
- Tests (`tests/CstDbModernBuildTests.pas`): the beta's table values, `C_ENEMYHITS` found by scanning (with
  the kind-1 twin and the targeting bar present), the lifted item read through a scanned `C_LLIFTEDID`,
  `#ContHP` on a fixed-base and on a modern client, `#EnemyHits` on the attack bar's layout.
- `CHANGELOG.md` (Fixed: `event Drag` / `#LLifted*`, `#FindRep`, `#ContHP`, the `#EnemyHits` entry), site
  `variables/enemyhits.md` (its beta note).
- Read-only check after the rebuild: `EUOCli vars #LLiftedKind --client 1` = 0 on the beta (was 65536).

## Live probes

| Probe | What it checks | Result |
|---|---|---|
| `tests/tools/LiftProbe.euo` | `event Drag`, `#LLiftedKind/ID/Type` before, during, after | 2026-11-14: 6 pass, 0 fail. Kind 0 before; `event Drag` lifted the new dagger (kind 1, id = the dagger, type `WSF`); after the click kind 0 and the dagger back in the backpack; dagger deleted |
| `tests/tools/FindRepProbe.euo` | `#FindRep` of you, a Provisioner (7), a Rat (3) | 2026-11-14 first run: Provisioner 7 PASS, Rat 3 PASS, "you" 104 FAIL. The 104 was the probe's mistake: `finditem #CharID` (`XC` = 1) also matches by type, three graphic-1 ground items lay near the character, and the probe read the first match without checking `#FindID`. A read-only memory read then showed the character's notoriety dword (+$32C) = 3, the three vendors nearby 7, and 104 at that offset of one graphic-1 item (items have no notoriety). Probe corrected to pick the match that is you |
| `tests/tools/ContHPProbe.euo` | `#ContHP` of your health bar at full and half hits | 2026-11-14 first run: full PASS (100 at 100 of 100; the self-test read 0 there). Half FAIL with 0: after `[self set Hits 50` a `normal_gump` was on top, and `#ContHP` reads the top gump. Probe corrected to skip gumps on top of the health bar with `ignorecont`. Re-run: 2 pass, 0 fail (100 at 100 of 100, 50 at 50 of 100, after skipping the `normal_gump`) |
| `tests/tools/EnemyHitsProbe.euo` | `#EnemyHits` in combat; logs `#EnemyID` after macro 53 | 2026-11-14: 2 pass, 0 fail. After `event macro 27` on the rat (120 of 120) `#EnemyHits` 100; after `[set Hits 60` 50 (the shard sends 50 of 100). After macros 52/50 selected the rat and `event macro 53` attacked it, `#EnemyID` stayed the rat for 4 s (`#EnemyHits` 50, then 51 as it regenerated); war mode stayed off the whole run |
