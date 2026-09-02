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
