# EUOMigrate

Derives the `uo\uoclidata.pas` tables for a UO client build EasyUO Reforged does not know yet: the
`C_*` / `E_*` addresses, the `F_*` calling-convention flags and the `B_*` structure offsets. It works
for newer and older builds alike, from a **knowledge base** of builds whose tables are already
verified. You don't need the old executables any more, only their fingerprints, which live in `kb\`.

It never edits the repository's sources. It writes a report, a Pascal snippet to review and paste,
and fresh signatures.

## Setup

Python 3.10 or newer (developed on 3.14), and Capstone:

```
pip install -r tools/EUOMigrate/requirements.txt
```

## Supporting a new build

```
python tools/EUOMigrate/euomigrate.py migrate "D:\...\Ultima Online Classic\client.exe"
```

It matches the build against each knowledge-base build in turn. For each one it prints a line per
matching phase and per round: the functions matched so far, the change, and the time since that
reference started.

```
matching against 7.0.117.1 (relocatable, stamp 6AC94360, uoclidata.pas)
  anchors: 899 matched (+899), 0s
  vtables: 2751 matched (+1852), 0s
  similarity: 2999 matched (+248), 0s
  round 1: 9270 matched (+6271), 1s
  ...
  round 5: 11043 matched (+0), 3s
  pruned: 11023 matched (-20), 3s
  ...
  11051 of 34138 reference functions matched (closeness 0.88), 43 of its signatures hit, 5s
```

Rounds stop when one adds nothing; then contradicted matches are pruned and the rounds resume, at
most three times.

The results go to `tools\EUOMigrate\out\<version>-<PE stamp>\` (git-ignored):

| file | what |
|---|---|
| `report.md` | every field: value, confidence, status, the evidence, runners-up |
| `uoclidata-snippet.pas` | a milestone delta + `Milestones`/`VersionIndex` rows (fixed-base build), or a `SysVarModernAddrs_<stamp>` list + `ModernBuilds` row (relocatable build) |
| `EUO Updtr Strings <id>.txt`, `scanner-table.pas` | signatures for the usable values, unique in this build: the next build of the same compiler is then found by the runtime scan (`ScannerTable_*`, EUO Updtr) with no tool at all |
| `candidates.json` | the hand-over between the steps below |

Then start that client, log in, and check the values in the running process. Both commands are
read-only: they never write to the client or send it input.

```
python tools/EUOMigrate/euomigrate.py verify tools/EUOMigrate/out/<id>/candidates.json
python tools/EUOMigrate/euomigrate.py probe  tools/EUOMigrate/out/<id>/candidates.json
```

- **`verify`** applies a plausibility check ("oracle") to each value:
  - `C_CHARPTR` must lead to a player object with a serial and an RTTI class.
  - The skill arrays must hold 58 sane values, with the base array tracking the real one.
  - `C_CONTPOS` must head a chain of `...Gump` objects.
  - `C_SHARDPOS` must equal the shard name in the window title.
  - The `E_REDIR` function must be on a thread stack, i.e. running.
  - `C_CLIXRES` must be a resolution, and imports and code bytes must match the exe.
  - `C_CLILOC` must lead to the client's cliloc table: a known number (1075847, "Bless") must resolve to text.
  - `C_BUFFTIMERS` must be a consistent `std::map` whose nodes hold plausible timer ids and seconds
    (an empty map is only `weak`: apply a timed buff such as Bless and verify again).

  A value that fails is replaced by its first runner-up that does not fail, or is marked `rejected`.
- **`probe`** finds the layout offsets by searching for the offset that makes one of the client's
  whole lists consistent at once:
  - `B_ITEMID`, `B_ITEMTYPE`, `B_ITEMSLOT`, `B_POS` from the object list (anchors: a player with a
    human body, a backpack on layer 21);
  - `B_CONTNEXT` from the gump list, `B_STATNAME` from the status gump (anchor: the character name
    in the window title);
  - the journal layout (`F_JOURNALDIRECT`, `B_JNEXTPTR`, `B_JCOL`, `B_JKIND`) from the journal chain
    (kind $12 on exactly the UTF-16 lines);
  - `F_SYSMSGDIRECT` / `B_SYSMSGSTR` from the newest system message;
  - `B_BUFFVEC`, `B_BUFFSIZE` from the `BuffIcons Gump` (open the buff window with a buff on): the
    pointer pair in the gump whose span is whole icon entries that decode, and `B_STLHEAD`,
    `B_CLILOCKEY` from resolving those entries' title cliloc numbers through `C_CLILOC`.

To finish:

1. Paste the snippet into `uo\uoclidata.pas`, and the scanner rows if you want them.
2. Rebuild, then run `tests\run_tests.ps1` and `tools\EUOSelfTest` in the client.
3. Add the build to the knowledge base, so the next migration can start from it:

   ```
   python tools/EUOMigrate/euomigrate.py fingerprint "<exe>"          # once it is in uoclidata.pas
   python tools/EUOMigrate/euomigrate.py fingerprint "<exe>" --candidates out/<id>/candidates.json
   ```

   The first form applies once the build is in `uoclidata.pas`. The second form adds a migrated build
   straight from its usable values. Then commit the new `kb\<version>-<stamp>.json.gz`.

`fingerprint` also takes `--set FIELD=VALUE` (repeatable) for a value checked in the live client that
`uoclidata.pas` cannot hold for that exact build -- the fixed-base buff bar addresses `C_CLILOC` /
`C_BUFFTIMERS`, which only the runtime scan provides, went into the `client.exe` entry this way.

`emit <candidates.json>` regenerates the report and snippet after you have edited statuses by hand.
`kb` lists the knowledge base.

### Statuses

| status | meaning | in the snippet |
|---|---|---|
| `accepted` | static evidence above confidence 0.50 | the value |
| `verified` | passed its oracle / probe in the running client | the value |
| `derived` | read from the code: `F_*` conventions, `B_*` distances between two globals | the value |
| `probed` | layout offset found in the running client, different from before | the value |
| `candidate` | best guess below the threshold, not verified | **0**, with the guess in a comment |
| `rejected` | failed its oracle, no runner-up passed | **0** |
| `unused` | the closest reference build does not use this field (another form of the feature) | 0 |
| `inherited` | `B_*`/`F_*` taken over from the floor milestone / the modern layout | not repeated |

A zero `C_*`/`E_*` turns a feature off: `uoevents.pas` refuses to run an event whose address is 0.
A wrong value would instead read garbage or patch the wrong machine code. So whole **feature
groups** go to 0 together when one member is not usable:
- the event hook (`E_REDIR` + `E_OLDDIR`);
- item properties;
- messages;
- pathfind;
- macros;
- send packet;
- the buff bar.

## How it works

1. **Fingerprints** (`features.py`). Each function of an exe gets these, which survive recompilation:
   - the strings, imported APIs, RTTI classes and unusual constants it references;
   - its direct calls and code-pointer references, in order;
   - its global-variable accesses (address, read/write/indexed, size).

   The knowledge base stores these with strings hashed, plus, for every field, a descriptor of how
   to recognise it:
   - the function it starts;
   - for a hook site, a ±12-instruction window of masked instruction shapes;
   - the global it is;
   - the import slot;
   - or "the target of the call at field X".

   It also stores the build's validated signatures.
2. **Matching** (`match.py`). The reference's functions are paired with the target's, strongest
   evidence first:
   - tokens unique on both sides;
   - RTTI vtable slots;
   - rare-token similarity;
   - aligned call sequences of matched pairs;
   - matched callers and callees;
   - functions touching the same mapped globals;
   - the address order within a gap.

   Every acceptance needs a mutual best with a margin. Matches that most of their matched neighbours
   contradict are pruned.
3. **Resolution** (`resolve.py`). Globals come from voting over the aligned access sequences of
   matched functions. A target global already claimed by another field is excluded, and evidence
   from a single function is capped. A field EasyUO only uses as a base (`C_LHANDID`) is located
   through the member it reads at a fixed distance (`fields.ANCHOR`), and so are its signatures.
   Hook sites come from window alignment inside the matched function and its twins. Every field
   gets a ranked candidate list, not just one value.
4. **Consensus** (`consensus.py`). Every knowledge-base build is matched on its own:
   - Hits of each build's signatures are pooled with the matcher's candidates.
   - The closest build (by matched-function coverage) decides each field's form.
   - On a fixed-base build, a value equal to the neighbouring milestones counts as corroboration.
5. **Code-derived flags and offsets** (`conv.py`, `fields.RELATIVE`):
   - The `F_*` flags come from the matched functions' entry code (ecx/edx inputs, `ret N`).
   - `B_PATHPROLOGUE` comes from the walk-to function's SEH prologue.
   - Offsets like `B_SKILLDIST`, `B_CLITOP` and `B_LTARGX` are located as globals in their own right
     ("base + offset").
6. **Signatures** (`siggen.py`). These wildcard in-image operands, rel32 targets and ebp/esp
   displacements, with a joker byte per pattern. A window is kept only if it is the smallest one that
   matches exactly once and resolves to the value.

Disassembly, function starts and fingerprints are cached per exe (by SHA-256) in
`%LOCALAPPDATA%\EUOMigrate\cache`; set `EUOMIGRATE_CACHE` to put the cache elsewhere. A cached exe
loads in a fraction of a second. The cache keys carry `TOOL_VERSION` (`euomig/__init__.py`): after
changing how the sweep, the function starts or the fingerprints are computed, bump it or empty the
cache.

## How well it works (measured on the builds at hand)

- **An older, unknown build, migrated from the knowledge base:** client 7.0.29.97, stamp `515F178B`,
  not in `uoclidata.pas`.
  - All 38 fields are accepted.
  - 30 of them can be checked against the hand-made `EUO Updtr Strings 6062 and newer.txt`, and all
    30 agree, 0 disagree.
  - The other 8 rest on both the matcher and a signature.
  - Signatures generated on 7.0.117.1 resolve 29 of 30 fields on 7.0.29.97, 0 wrong.
- **Signatures on known builds:** generated from the verified tables, they reproduce all 46 fields of
  the beta and all 38 of `client.exe` (static scan of the generated file).
- **Across a compiler change**, the hardest case (`selftest client.exe client_beta.exe`, each build
  migrated from the other alone):
  - Most fields come out right or correctly flagged as unsure.
  - It cannot infer hooks whose meaning changed with the compiler. On the beta, the message wrappers
    are inlined (so `E_SYSMSGADDR` names a constructor), Pathfind enters mid-function, and the tick
    hook moved from `__allmul` to `__alldiv`. Those builds remain the knowledge base's job: once the
    beta is in it, a later beta build is matched against the beta, not against `client.exe`.
- **A known build treated as unknown:** client 7.0.108.0 (stamp `67F4AA95`, which `uoclidata.pas`
  has verified but the knowledge base does not contain), migrated while seeing only the older
  milestone 7.0.99.1. All 38 addresses and the 14 flags and offsets read from the code equal the
  verified table, with nothing wrong. Only the inherited journal layout differed (7.0.108.0 changed
  it). Then `verify` and `probe` on the running client (logged in on a live shard) rejected nothing,
  confirmed 8 addresses and 6 layout offsets, and corrected the four journal values: the final
  result equals the verified table in all 114 fields.
- **Live (read-only, on `client.exe`):**
  - Every verified value passes or is neutral, and deliberately corrupted values fail.
  - `probe` reproduces `B_ITEMID`, `B_ITEMTYPE`, `B_ITEMSLOT`, `B_POS`, `B_CONTNEXT`, `B_STATNAME`
    and the journal layout (`F_JOURNALDIRECT`, `B_JNEXTPTR`, `B_JCOL`, `B_JKIND`).

## Limits

- **Feature forms.** When the closest known build implements a feature in another form (wrapper
  vs. inlined constructor, stack vs. register arguments), fields of the new form cannot be inferred.
  The report flags them; the `E_*` docs in `uoclidata.pas` say what each form needs.
- **Layouts without a probe** stay inherited and are listed in the report as such:
  - shop and bill;
  - `B_CHARSTATUS`;
  - `B_FINDREP`;
  - the stat-gump fields.

  `tools\EUOSelfTest` exercises all of them.
- **Live checks need state.** Many globals are null until something happens (no enemy, nothing on
  the cursor, no popup). `verify` then has nothing to confirm and leaves the static status.
- **Identical copies of a function.** When two copies exist (the beta has two tick functions), only a
  running client tells which one is live.

## Files

```
euomigrate.py        CLI
euomig/pe.py         PE reader: sections, imports, relocations, version resource, strings, RTTI
euomig/disasm.py     linear sweep (capstone), function starts, operand helpers
euomig/features.py   per-function fingerprints (FuncDB), hashed for the knowledge base
euomig/tables.py     uoclidata.pas reader (milestones, ModernBuilds), as TCstDB.Update resolves them
euomig/fields.py     field descriptors, global-relative B_* pseudo fields
euomig/match.py      function matching, global votes
euomig/resolve.py    descriptors -> ranked candidates for one reference
euomig/consensus.py  all references -> one result per field
euomig/sigs.py       EUOUpdtr signature format: parse, scan
euomig/siggen.py     signature generator, strings file, ScannerTable rows
euomig/conv.py       calling conventions -> F_* flags, B_PATHPROLOGUE
euomig/live.py       read-only process access (32-bit client from 64-bit Python), thread stacks
euomig/oracles.py    per-field live checks
euomig/probe.py      live layout probes
euomig/emit.py       candidates.json, report, Pascal
euomig/kb.py         knowledge-base files
kb/                  one fingerprint file per known build (derived data only: hashed tokens, call
                     graph shape, instruction shapes, and short masked signatures of the kind the
                     EUO Updtr Strings files already hold -- no executable, no assets)
tests/               unittest suite on synthetic executables (tests/synth.py)
```

Tests: `python -m unittest discover -s tools/EUOMigrate/tests` (CI runs them too).
