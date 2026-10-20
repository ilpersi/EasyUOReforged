# Adding support for a new UO client version

`uo\uoclidata.pas`'s `TCstDB` is a table of raw memory offsets. This is the only file that needs
to change to support a new client build — everything else in `uo\`/`parser\`/`easyuo\` reads
exclusively through `Cst.XXXXX` accessors, never a hardcoded offset. This doc is the step-by-step
process, written up after adding support for client 7.0.108.0 and 7.0.99.1 during the Lazarus/FPC
migration, and updated when the file was re-architected from a flat one-block-per-version table
into a **milestone/delta model** (see `uoclidata.pas`'s own header comment for the full rationale):
one small delta array per point where the resolved state actually *changed*, applied cumulatively
at runtime, rather than every version independently restating its own full ~87-field table. Steps
1-5 (finding, scanning, and researching a new client's data) are unchanged by that redesign — only
step 6 (where the results actually get written into the file) is different.

## The automatic route: `tools\EUOMigrate`

Try this first. `tools\EUOMigrate` (Python + Capstone, see its [README](../tools/EUOMigrate/README.md))
does steps 2-6 below mechanically, for old and new builds alike:

```
pip install -r tools/EUOMigrate/requirements.txt
python tools/EUOMigrate/euomigrate.py migrate "<path>\client.exe"
python tools/EUOMigrate/euomigrate.py verify tools/EUOMigrate/out/<id>/candidates.json
python tools/EUOMigrate/euomigrate.py probe  tools/EUOMigrate/out/<id>/candidates.json
```

- `migrate` locates every `C_*`/`E_*` field of the new exe from the **knowledge base**
  (`tools\EUOMigrate\kb\`, fingerprints of builds whose tables are already verified -- no old exe
  needed), using function matching, global-variable voting, instruction windows for hook sites and
  the known builds' own signatures. It also reads the `F_*` calling-convention flags and the
  global-relative `B_*` distances from the code, and writes, in `out\<version>-<stamp>\`: a report
  with a confidence and the evidence for every value, the `uoclidata.pas` snippet (a milestone delta
  for a fixed-base build, a `ModernBuilds` entry for a relocatable one), and fresh signatures (an
  `EUO Updtr Strings` file and `ScannerTable` rows) so the *next* build of that compiler is covered
  by the runtime scan.
- `verify` (read-only, client running and logged in) checks the values in memory -- the player
  object behind `C_CHARPTR`, 58 sane skill values, a gump chain behind `C_CONTPOS`, the shard name
  from the window title, the tick function on the main thread's stack -- and swaps in a runner-up
  when the first choice fails. `probe` finds the object / gump / status-gump offsets (`B_ITEMID`,
  `B_ITEMTYPE`, `B_ITEMSLOT`, `B_POS`, `B_CONTNEXT`, `B_STATNAME`) by walking the client's lists.
- Unverified values are written as 0 (the feature stays off rather than reading garbage or patching
  the wrong code), and so is every member of a feature group with one unusable member.
- Then paste the snippet, rebuild, run `tests\run_tests.ps1` and `tools\EUOSelfTest`. Once the build
  is in `uoclidata.pas`, `euomigrate.py fingerprint <exe>` adds it to the knowledge base -- commit
  the `kb\*.json.gz` file so the next migration can start from it.

What it cannot decide alone: a hook whose *meaning* changed between compilers (on the beta the
message wrappers were inlined, so `E_SYSMSGADDR` names a constructor instead, see `E_NEWOBJ`), a
layout it has no probe for (journal node, shop, status flags -- inherited, listed in the report),
and which of two identical copies of a function the client actually runs, when it is not running.
The manual steps below remain the reference for those cases.

## 0. Check it isn't already supported

```
grep -n "'7.0.99.1'" uo\uoclidata.pas
```

If that finds a `ClientList` row, you're done — nothing to add.

## 1. Confirm the exact version

Don't trust a filename. Check the file's own embedded version resource (Windows Explorer →
Properties → Details, or `Get-Item <path> | Select VersionInfo` in PowerShell). This matters:
a mislabeled file gets you a data block filed under the wrong version string, silently never
matched by a real client reporting its true version.

## 2. Get a copy of the target client

Two paths, depending on what you have:

- **A live, running client** — the normal case, and the only one the original tool
  (`tools\EUOUpdater`) was ever designed for.
- **Only the `.exe` file, not currently running** — still workable. This entire client
  generation loads at a fixed, non-relocated `ImageBase=$400000` (the same reason
  `common\access.pas`'s `SearchMem` gets away with a hardcoded `$400000`-`$650000` scan window
  in the first place). That means the *on-disk* section bytes at their mapped virtual addresses
  are identical to what a live process's memory would show at those same addresses — so you can
  reconstruct the address space directly from the PE file's own section table and run the exact
  same byte-pattern scans against that, with no need to actually launch an unfamiliar
  executable. This is how 7.0.99.1's support was derived (see step 4b). Ask an AI assistant with
  Python + `pefile`/manual struct parsing available to do this for you if you don't want to write
  the PE-parsing code by hand.

## 3. Pick the right scan-string file

`tools\EUOUpdater\"EUO Updtr Strings *.txt"` has two brackets, split by client build number
(`200 - 6061` and `6062 and newer`). Try the one that looks closest to your target version's
neighbors in `uoclidata.pas`'s `ClientList` first. If most lines come back `N/A`, the client is
old enough (or new enough) that the patterns don't apply — try the other bracket, or accept that
some fields (like `C_SYSMSG` on 7.0.108.0/7.0.99.1) need a fallback pattern derived fresh, the
same way this migration added one (see that file's own comments for a worked example, including
the `{SYSMSGSTR_CHECK}` diagnostic for one specific known structural gotcha).

## 4. Run the scan

### 4a. Against a live client

1. Build `EUOUpdtr.lpi` (`lazbuild --cpu=x86_64 --os=win64 EUOUpdtr.lpi`).
2. Start the target client, then launch `EUOUpdtr.exe` — it auto-detects and selects the running
   client on its own timer.
3. Paste the appropriate scan-string file's contents into the left editor, press **Start**.
4. Read the `$XXXXXXXX  {FIELDNAME}` results out of the right editor.

### 4b. Against a file that isn't running (static analysis)

Reconstruct a virtual address space from the PE section table (`ImageBase` + each section's
`VirtualAddress`/raw file data), then run the *same* byte-pattern-with-wildcard search the real
`GetAddr`/`SearchMem` (`tools\EUOUpdater\main.pas` / `common\access.pas`) does, against that
reconstructed image instead of a live process's memory. The scan-string file's own format
(`<hex pattern>;<joker byte, hex>;<offset, decimal>;<C/B mode>;<adjustment, decimal>;{NAME}`) is
exactly what `GetAddr` parses — replicate its logic (or drive the real `TUOSel`/`access.pas` code
directly against a live client if one becomes available later, for an even more rigorous check —
see `tests\LiveClientTests.pas` / `tools\EUOUpdater\uoselector.pas` for how this project's own
code does exactly that against a real running process).

Either way, you want the same output shape: one resolved `$XXXXXXXX` (or `N/A`) per field name.

## 5. Handle what the scan can't cover

The scan strings only ever derive `C_*` (variable addresses) and `E_*` (event/hook addresses).
They never cover `B_*` (struct-layout byte offsets) or `F_*` (capability/feature flags) — by
long-standing convention, those are hand-copied forward from the closest already-known version
instead, on the assumption that struct layouts and capability flags change far less often than
absolute addresses. That's a *reasonable* default, not a *verified* fact for the specific version
you're adding — treat it as your starting point, not your answer.

A few fields need extra care beyond straight copy-forward:

- **`C_TARGETCNT`**: not covered by any scan string at all, and reads `$00000000` for every known
  version including the two closest to whatever you're adding. Almost certainly vestigial — set
  it to `$00000000` and move on.
- **`B_SYSMSGSTR`/`F_SYSMSGDIRECT`**: run the `{SYSMSGSTR_CHECK}` diagnostic line from
  `"EUO Updtr Strings 6062 and newer.txt"` (see that file's own comments for what the result
  means). Don't assume `$100`/`F_SYSMSGDIRECT=0` just because that's what's already in the table —
  as of this writing, *every* version actually checked (7.0.99.1, 7.0.108.0) reads the newer
  `$800`/`1` layout; `$100` has never actually been confirmed correct for any real client, it's
  only ever been the inherited default.
- **Anything else that behaves visibly wrong in testing** (a stat layout, a packet-format flag,
  journal/system-message text) — the copied-forward `B_*`/`F_*` fields are the first place to
  look. This is exactly what happened with 7.0.108.0's journal layout: `C_JOURNALPTR` resolved
  correctly from the ordinary scan, but the *node structure* it points at had silently changed
  shape, and only live disassembly (watching real chat traffic go through `ReadProcessMemory`)
  caught it — see `uoclidata.pas`'s `SysVar701080` and `SysVar70991` comments for the full story,
  including a case (7.0.99.1) where this **couldn't** be fully resolved from a non-running file
  alone and was deliberately left as an honest, flagged gap rather than a guess. If you can't
  verify something with real confidence, say so in the comment rather than presenting an
  assumption as settled — a wrong value with false confidence is worse than a documented gap.

## 6. Write the new milestone in `uoclidata.pas`

The question to answer first: **is this version's resolved state actually different from its
nearest newer neighbor's?** (Newer, not older — `Update`'s floor lookup means a version with no
milestone of its own inherits whatever the nearest newer-or-equal milestone already resolved to,
same as `2.0.3` inheriting `2.0.0`'s milestone today whenever nothing changed in between.)

- **If nothing changed** (rare for a brand-new client build, but real — see `docs`/git history for
  examples of two build numbers sharing one milestone): you only need a `VersionIndex` row, no new
  delta array at all. Add `(Cli: '<new version>'; Milestone: <same index as the nearest newer
  neighbor>)` and bump `VersionIndex`'s own `array[0..N]` bound by one.
- **If something changed** (the normal case for a genuinely new build — addresses drift on almost
  every recompile): write a new delta array containing **only the fields that changed** relative
  to the nearest newer milestone's cumulative state — not a full ~87-field table. Compare your
  fresh scan results against the nearest existing neighbor's already-resolved values (a quick
  standalone program per step 7 below) to see what actually differs.
  - **Naming**: `SysVarMSn`, where `n` is the new milestone's own position once inserted (matches
    this file's generated milestones' own naming; check `grep -n "SysVarMS" uo\uoclidata.pas` for
    the next free/appropriate index — milestones are ordered **newest-first**, so a brand-new
    client version's milestone goes at index 0, and every existing milestone's own array name and
    every `Milestones`/`VersionIndex` row referencing an index `>=` the insertion point shifts up
    by one. This is mechanical but easy to get subtly wrong by hand — see the note at the end of
    this section on using the derivation script instead of hand-editing for anything beyond a
    single trivial addition).
  - **Shape**: `(Expr: FIELDNAME; Val: $XXXXXXXX),` rows, `LISTEND`-terminated, same as any other
    `TSysVarList` array in this file. Only list fields that actually changed — a field NOT going
    from set to unset should simply not appear at all (it stays whatever the older, still-applied
    milestones already set it to); a field going from a real value BACK to unset must be listed
    explicitly as `Val: $00000000` (omitting it would leave the old nonzero value in place, since
    application is cumulative).
  - **`NormVer`**: the new milestone's `Milestones[]` entry needs a zero-padded, dot-joined
    `NormVer` key (e.g. `'007.000.200.000'` for `'7.0.200.0'`) — pad each dot-separated segment to
    exactly 3 digits, keep any trailing single-letter suffix as a literal `.x` appended after. This
    is only ever consulted for a version string with no exact `VersionIndex` row (the floor-lookup
    path) — getting it slightly wrong for a version that DOES have its own exact row is harmless,
    since the exact-match pass never looks at it. See `TryNormalizeVersion` in `uoclidata.pas` for
    the precise algorithm if you want to double-check by hand.
  - **`ClientList`/`VersionIndex`**: add one `(Cli: '7.0.99.1'; Milestone: <new index>)` row.
- **Array bounds**: `Milestones`/`VersionIndex`'s own `array[0..N]` bounds both need bumping by one
  whenever you add a new milestone; a brand-new delta array's own bound is the row count you wrote
  *including* the trailing `LISTEND` row. FPC errors at compile time on a miscounted bound
  ("Expected another N array elements") — but count carefully rather than trial-and-error-ing it.
- **The client-picker gate**: `CliVerSupported` (what actually gates which clients the app will
  even attempt to attach to, via `uoselector.pas`) is **floor-based**, not an exact list — a
  version newer than the newest known milestone is already automatically selectable with no
  `VersionIndex` row at all. Adding one anyway (as this section describes) is still the right move
  whenever you've actually verified real data for that exact version, since floor-matching only
  ever gives you the *nearest older* milestone's data, which may not be correct for a version that
  changed something.
- **For anything beyond a single trivial addition** (more than one new version at once, or
  inserting in the middle of the list rather than at the newest end), hand-editing the shifted
  indices across `Milestones`/`VersionIndex`/every `SysVarMSn` name is error-prone — prefer
  re-running `tests\tools\DeriveCstDbMilestones.ps1` after adding your new version's *raw* full
  table as a normal, temporary flat entry (matching this file's pre-redesign shape), letting the
  script re-derive the whole milestone/delta model fresh (it re-validates all 222+ versions
  against themselves before emitting anything — see that script's own header comment), then
  re-splicing the generated block back in. Slower per single change, but eliminates the whole class
  of hand-editing mistakes.
- **Document your reasoning inline**, the same way every other version-specific block in this
  file does: what came from a real scan vs. what was copied forward vs. what's a deliberately
  flagged unknown. The next person (possibly a future you) needs to be able to tell those apart
  at a glance.
- **Dynamic scanning** (`ScannerTable_Pre6062`/`ScannerTable_Post6062`, also in `uoclidata.pas`):
  a separate, optional, additive mechanism — signature-scans a *live* attached client's own memory
  for a field's address at runtime, overriding whatever the milestone data resolved. Currently only
  covers `C_BLOCKINFO`/`C_SYSMSG` on the Post-6062 table, deliberately (see that table's own
  comment for why). Extending it needs a validated byte pattern (Mode 1/2/3 + offsets) for a field
  whose address-finding *instruction shape* stays stable across a whole client generation even as
  the address itself drifts per build — worth pursuing for fields you find yourself re-deriving
  by hand release after release, but not a substitute for the milestone data above.

## Relocatable ("modern") builds -- same version number, different binary

A client can share its **version number** with an older build and still be a different
program. The 7.0.117.1 beta (`client_beta.exe`) is the example: built with a newer compiler and
linked `DYNAMIC_BASE`, the loader puts it somewhere other than `$400000` (e.g. `$E10000`), its
code is ~10% larger, and none of the fixed-base 7.0.117.1 addresses, byte signatures or object
layouts apply. The symptom is every variable reading `N/A` / 0 although attaching "works" --
the file version matches, so the milestone data for the *other* build gets used.

How this port tells them apart and copes (all in `uo\uoclidata.pas`, `common\access.pas`):

- `ReadImageInfo` reads the target's PE header: real load address (WOW64 PEB), `TimeDateStamp`,
  `DllCharacteristics` and the executable section range. `DYNAMIC_BASE` (`$40`) marks a modern build.
  (The header's own `ImageBase` field is useless here -- the loader rewrites it to the new base.)
- Every `C_*`/`E_*` value is a **link-time address** (as if loaded at `$400000`). The getters add
  `ImageDelta = load address - $400000`, so one table serves any load address. It is 0 for the
  fixed-base builds, which are therefore unchanged.
- `uoevents.pas` / `uovariables.pas` put their code cave and target handler in the header page at
  `TCstDB.IMAGEBASE + $600` instead of the literal `$400600`.
- A `ModernBuilds` entry has a **Layout** list (`B_*`/`F_*`, applied to any modern build) and an
  **Addrs** list (`C_*`/`E_*`, applied only when the PE `TimeDateStamp` matches). An unknown modern
  build starts with every `C_*`/`E_*` at zero rather than inheriting another build's addresses, and
  only `ScannerTable_Modern` fills anything in. Every event in `uoevents.pas` refuses to run
  while its address is zero.
- Scans for a modern build use `SearchMemRange` over its code section, not the legacy
  `$400000-$650000` window; `tools\EUOUpdater` does the same and prints link-time addresses.

### Deriving a modern build's table

The byte signatures in `EUO Updtr Strings *.txt` do **not** match a modern build (different
codegen), so the data has to be derived by comparing code and checking against the live client:

1. Load both executables' PE section tables and disassemble `.text` (Capstone works well).
   Instruction streams are only ~0.5% different in length, so functions can be paired by their
   string references, imported-function names and magic constants (`0x3b2`, `0xd1b71759`, `0x80c`...).
2. Find a variable by the *shape of the code that touches it*, then confirm it in the running
   client. Examples that worked: the add-message routine (`mov reg,[HEAD]; ...; mov [HEAD],reg`)
   gave `C_SYSMSG`; the journal add-entry routine (`cmp dword [node+$80C],0`) gave `C_JOURNALPTR`;
   the skill-array init loop gave `C_SKILLLOCK/CAPS/SPOS`; strings the client holds (`TestReforged`,
   the character name) gave `C_SHARDPOS` and the status-gump layout.
3. Walk the client's own lists in memory to learn struct layouts (item list from `C_CHARPTR`,
   gump list from `C_CONTPOS`, journal chain) instead of guessing offsets from the old build.
4. The event hook is the part to be most careful with: `E_REDIR` must be a 5-byte `call rel32` that
   runs every frame on the client's main thread, and `E_OLDDIR` its original target. On the beta
   that is the `call __alldiv` in the per-frame tick function (the old build hooks `call __allmul`
   in the same function -- find it by the shared `0xd1b71759` / `0x1f4` / `0x4c` constants).
5. Compare calling conventions before wiring an event: on the beta `CNetwork::Send` is a thiscall
   that pops its argument (`F_SENDTHISCALL`), and the macro executor reads its table from globals
   (`E_MACROTAB`) instead of taking arguments. Events whose functions were inlined or changed
   shape (SysMessage, ExMsg, BlockInfo, Drag, Pathfind, item properties) get their own cave code
   (`NewMessageObject`, `BlockInfoFastCode`, ... in `uoevents.pas`), selected by the `F_*`/`E_*`
   flags above; with their address at zero the event refuses to run instead of calling into the
   client. `tests\CstDbModernBuildTests.pas` checks every offset and jump inside that generated code.
   Useful facts for checking a build against the EasyUO wiki
   (`github.com/ilpersi/easyuo-wiki-archive`): `#CursKind` is the **facet** the character is in
   (0 Felucca ... 4 Tokuno), not the cursor type; `Event Macro 1` (Say) needs its text as the third
   argument; macro 8/9 open/close gumps by number (8 4 = Skills). On the beta the vendor lines are
   item-like objects whose name pointer leads to a **cliloc number** ('1041060'), not the name text.
   The older clients return the same number for `#shopItemName` (checked with
   `tests\tools\ShopNameProbe.euo`), so that is kept as is -- no cliloc lookup.

6. Turn the findings into signatures so the next rebuild of the same compiler needs no manual work:
   take an instruction that touches each global (or the first ~12 instructions of a function),
   wildcard every address-like operand, rel32 branch target and ebp/esp displacement, pick a joker byte
   that is not among the fixed bytes, and keep the smallest window that is **unique** in the code
   section and resolves to the address you derived (check it against the file *and* the live process).
   `tools\EUOUpdater\EUO Updtr Strings modern.txt` and `ScannerTable_Modern` were produced this way
   (75 patterns, 46 fields); `tests\CstDbModernBuildTests.pas` covers the hook signature on a fake
   client, and a scan-only run against the beta reproduced every hand-derived value.

### The buff bar (`ScanBuffs`)

`ScanBuffs` / `#BuffCnt` ... `#BuffTime` read the client's buff bar, which needs two scanned addresses
and four layout constants per client generation. A client is "supported" only when `B_BUFFVEC` and both
addresses are non-zero; anything else leaves the command a no-op (`N/A`), so an unverified build never
reads garbage.

| Field | Meaning | Beta (VS2015+) | Fixed-base clients (VS2008-ish) |
|---|---|---|---|
| `C_CLILOC` | global holding the pointer to the cliloc manager (a `std::map<int,char*>`) | scanned (`$7ED970` on the beta) | scanned (`$A01B9C` on `client.exe`) |
| `C_BUFFTIMERS` | the buff-timer `std::map` (key = timer id; the double at node +`$28` = seconds left) | scanned; the global holds the head node | scanned; the address is the map object itself |
| `B_BUFFVEC` | offset in the `BuffIcons Gump` of the icon vector's begin pointer (end = next dword) | `$15C` | `$D0` |
| `B_BUFFSIZE` | size of one icon entry (`id +0`, duration +4, timer id +8, title cliloc +`$C`, title args +`$10`, description cliloc +`$DC`, description args +`$E0`) | `$1B0` | `$1B0` |
| `B_STLHEAD` | offset of the tree head pointer inside the map objects | 0 | 4 (the old STL puts a proxy in front) |
| `B_CLILOCKEY` | key offset in a cliloc map node; the text pointer follows it | `$10` | `$0C` |

How these were found, for a new generation: the client logs its buff-gump code (`CBuffIconsGump::AddIcon`,
`RemoveIcon`, `GetToolTipString` ... are in the string table), so find those strings, follow the references to
the functions, and read the field offsets and the two `std::map` lookups off the disassembly -- the tooltip
function shows the entry fields, the timer map (`time left = %d for timer id %d`) and the cliloc lookup in
one place. Then confirm in a live client with a few buffs on (Hiding, Bless, Curse are enough): the vector
holds one `B_BUFFSIZE` entry per icon, the cliloc map returns the tooltip text, and the timer double counts
down. `tools\EUOSelfTest` stage 9 checks all of it on the real client. The two address patterns are in the
strings files (`{CLILOC}`, `{BUFFTIMERS}`); the layout constants are not scannable.

Always diff results against a live client: `tests\LiveClientTests.pas`, or read the variable
getters through `TUOVar` and compare with a `client.exe` var dump of the same character.

## 7. Verify

- **Build**: `lazbuild --cpu=x86_64 --os=win64 uo.lpi` at minimum (fastest feedback on the data
  block itself); ideally also `EasyUOReforged.lpi` and `EUOUpdtr.lpi`.
- **Check the new entry resolves correctly**: `tests\CstDbTests.pas`'s golden-fixture test only
  covers the ~220 versions from the *original* Delphi 7 source — it can't catch a mistake in a
  version you just added. Write a small standalone program instead:
  ```pascal
  program verify;
  {$mode delphi}{$H+}
  uses SysUtils, uoclidata;
  var Cst : TCstDB;
  begin
    Cst := TCstDB.Create;
    Cst.Update('7.0.99.1');
    WriteLn('SYSMSG = $', IntToHex(Cst.SYSMSG, 8));
    // ...one line per field you care most about, comparing against the scan output...
    Cst.Free;
  end.
  ```
  Compile it against `common\` and `uo\` on the `-Fu` search path and run it — confirm every
  field matches what the scan produced, and (important) that switching back to an
  already-supported neighboring version afterward still resolves correctly too (catches any
  accidental cross-contamination from a copy-paste mistake in the new block).
- **Run the full suite** (`tests\run_tests.ps1`) to confirm nothing else regressed.
- **Live-test if you can**: attach the real `EasyUOReforged.exe` to a genuinely running instance of the
  new client version and exercise a representative sample of features (see the migration plan's
  "Tier 4" testing notes) — everything above gets you a plausible, internally-consistent data
  block, but only a real client can confirm the *behavior* is actually correct end to end.
