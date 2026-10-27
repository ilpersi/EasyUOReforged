---
title: EUOMigrate reference
description: "Every EUOMigrate command and option, the output files, the field statuses, the knowledge base, how the matching works and its limits."
sidebar:
  order: 6
---

The command-by-command reference for `tools/EUOMigrate`. For a guided first run, see
[Using EUOMigrate](/developers/euomigrate/).

All commands run from the repository root:

```powershell
python tools/EUOMigrate/euomigrate.py <command> [arguments]
```

## Commands

| Command | Needs the client running | What it does |
|---|---|---|
| [`migrate <exe>`](#migrate) | No | Derives the `C_` / `E_` values of an unknown build, plus the `F_` flags and `B_` distances it can read from the code. |
| [`verify <candidates.json>`](#verify) | Yes, logged in | Checks the values in the running client and marks them `verified` or `rejected`. |
| [`probe <candidates.json>`](#probe) | Yes, logged in | Finds object, gump, journal, message and buff-bar layouts (`B_`, `F_`) in the running client. |
| [`emit <candidates.json>`](#emit) | No | Rewrites the report, the snippet and the signatures, for example after you changed a status by hand. |
| [`fingerprint <exe>`](#fingerprint) | No | Adds a build with known values to the knowledge base. |
| [`selftest <exe> <exe>...`](#selftest) | No | Migrates each known build from the others and compares the result with its real table. |
| [`kb`](#kb) | No | Lists the knowledge base. |

`verify` and `probe` only **read** the client's memory. They never write to it and never send it input.

**Global option:** `--kb <folder>` uses another knowledge-base folder instead of `tools/EUOMigrate/kb`.
It goes before the command: `euomigrate.py --kb D:\mykb migrate client.exe`.

### migrate

```text
migrate <exe> [--out <folder>] [--ref <id>]...
```

Reads the exe (it does not need to run), matches it against every build in the knowledge base and writes
the [output files](#output-files) to `<out>/<version>-<PE stamp>/`.

| Option | Default | Meaning |
|---|---|---|
| `--out <folder>` | `tools/EUOMigrate/out` | Where to put the result folder. `out` is git-ignored. |
| `--ref <id>` | every build in the knowledge base | Use only this knowledge-base build as a reference. Repeat it for several. The ids are the ones [`kb`](#kb) lists. |

If `uoclidata.pas` already has a table for the exact build, `migrate` says so, works as if it did not, and
the snippet compares its result with the existing table instead of producing one to paste.

### verify

```text
verify <candidates.json> [--pid <process id>]
```

Attaches to the running client, which must be the **same exe** the migration was made from (checked by
its SHA-256), and runs a plausibility check on every `C_` and `E_` value:

- `C_CHARPTR` must lead to a player object with a serial and a class name.
- The skill arrays must hold 58 plausible values, and the base and with-bonuses arrays must be told apart.
- `C_CONTPOS` must head a chain of `…Gump` objects.
- `C_SHARDPOS` must equal the shard name in the window title.
- The function around `E_REDIR` must be running: it is looked for on the client's thread stacks.
- `C_CLIXRES` must hold a screen resolution; imported functions and code bytes must match the exe.
- `C_CLILOC` must lead to the cliloc table: cliloc 1075847 ("Bless") must resolve to text.
- `C_BUFFTIMERS` must be a consistent `std::map` of timer ids and seconds. An empty map only counts as
  `weak`: put a timed buff such as Bless on and verify again.

A value that passes becomes `verified`. A value that fails is replaced by its first runner-up that does
not fail, or becomes `rejected`. A value with nothing to check (no enemy, nothing on the cursor) keeps its
status. `verify` saves `candidates.json` and rewrites the other output files.

| Option | Meaning |
|---|---|
| `--pid <process id>` | Which client to attach to, when more than one is running. |

### probe

```text
probe <candidates.json> [--pid <process id>]
```

Finds layout offsets in the running client by searching for the offset that makes a whole list of
objects consistent at once:

| Values | Found from | Have this open or done first |
|---|---|---|
| `B_ITEMID`, `B_ITEMTYPE`, `B_ITEMSLOT`, `B_POS` | The object list (anchors: a player with a human body, a backpack on layer 21). | Logged in, with a backpack. |
| `B_CONTNEXT` | The gump list. | A few gumps open. |
| `B_STATNAME` | The status gump (anchor: the character name in the window title). | The status gump open. |
| `F_JOURNALDIRECT`, `B_JNEXTPTR`, `B_JCOL`, `B_JKIND` | The journal chain. | A few journal lines. |
| `F_SYSMSGDIRECT`, `B_SYSMSGSTR` | The newest system message. | A recent system message. |
| `B_BUFFVEC`, `B_BUFFSIZE`, `B_STLHEAD`, `B_CLILOCKEY` | The `BuffIcons Gump` and the cliloc table. | The buff bar open, with a buff on. |

A value that matches the table becomes `verified`; a different one becomes `probed` and replaces it. The
console shows each as `verified` or `CHANGED`.

### emit

```text
emit <candidates.json> [--out <folder>]
```

Rewrites `report.md`, `uoclidata-snippet.pas` and the signature files from `candidates.json`. Use it after
you edited a status or a value by hand. The signatures are only rewritten if the exe is still where it was
and unchanged. `--out` writes the files somewhere else (default: next to `candidates.json`).

### fingerprint

```text
fingerprint <exe> [--candidates <candidates.json>] [--set FIELD=VALUE]...
```

Stores a build in the knowledge base, so later migrations can start from it. It writes
`kb/<version>-<PE stamp>.json.gz`.

| Form | Takes the values from |
|---|---|
| `fingerprint <exe>` | `uoclidata.pas`, which must already have the exact build. |
| `fingerprint <exe> --candidates out/<id>/candidates.json` | A migration: only its usable values (`accepted`, `verified`, `derived`, `probed`). |
| `--set FIELD=VALUE` (repeatable) | A value you checked in the running client that `uoclidata.pas` cannot hold for this build. The fixed-base buff bar addresses, which only the runtime scan provides, were added this way: `--set C_CLILOC=0x00A01B9C`. |

### selftest

```text
selftest <exe> <exe> [<exe>...] [-v]
```

For each exe that `uoclidata.pas` knows exactly, migrates it from the **other** exes alone and compares
the result with its real table. It needs at least two such builds. Each field is reported as `right`,
`right-unsure` (right, but below the confidence threshold), `runner-up` (the real value is among the
runners-up), `missing`, `wrong-unsure` or `WRONG`. `-v` lists the right ones too. Use it to measure a
change to the matcher.

### kb

Lists the knowledge base:

```text
> python tools/EUOMigrate/euomigrate.py kb
7.0.117.1-6A8E6F9D       7.0.117.1 (fixed base, stamp 6A8E6F9D, uoclidata.pas + C_CLILOC from the live client + C_BUFFTIMERS from the live client + C_WORLDGRID from the live client + C_STATICVT from the live client)  22379 functions, 54 located fields
7.0.117.1-6AC94360       7.0.117.1 (relocatable, stamp 6AC94360, uoclidata.pas)  34138 functions, 58 located fields
7.0.117.31-6AD6CEB3      7.0.117.31 (relocatable, stamp 6AD6CEB3, migrated by EUOMigrate (0 values verified live) + C_MULTILIST from the live client)  38546 functions, 59 located fields
```

## Output files

`migrate` writes one folder per build, named `<version>-<PE stamp>`. `verify`, `probe` and `emit` update
the files in it.

| File | What it is |
|---|---|
| `report.md` | Every field: value, confidence, status, the evidence, the runners-up. Start here. |
| `uoclidata-snippet.pas` | What to paste into `uoclidata.pas`: a milestone list with its `Milestones` and `VersionIndex` rows (fixed-base), or a `SysVarModernAddrs_<stamp>` list with its `ModernBuilds` row (relocatable). For a build `uoclidata.pas` already has, a comparison instead. |
| `EUO Updtr Strings <id>.txt` | Signatures for every usable value, in the EUOUpdater format, each unique in this build. |
| `scanner-table.pas` | The same signatures as `TScannerEntry` rows for a `ScannerTable_…` list. |
| `candidates.json` | The full result, passed from one command to the next. |

### candidates.json

One entry per field. You can edit `status` and `value` by hand, then run [`emit`](#emit):

```json
"C_SKILLSPOS": {
  "value": 32279440,
  "conf": 0.76,
  "status": "verified",
  "how": "7.0.117.1-6A8E6F9D: votes 3.3 from 4 functions 0.96; 7.0.117.1-6A8E6F9D: signature",
  "alts": [[32279560, 0.073, "7.0.117.1-6AC94360: votes 2.5 from 3 functions 0.70"]],
  "checks": ["pass: 01EC8B90 ..."]
}
```

| Key | Meaning |
|---|---|
| `value` | The value, as a decimal number (`32279440` is `$01EC8B90`). |
| `conf` | Confidence from the static evidence, 0 to 1. |
| `status` | See [Statuses](#statuses). |
| `how` | The evidence, per reference build. |
| `alts` | Runners-up: value, confidence, evidence. |
| `checks` | What `verify` or `probe` found. |

## Statuses

| Status | Meaning | In the snippet |
|---|---|---|
| `accepted` | Static evidence above confidence 0.50. | The value. |
| `verified` | Passed its check in the running client. | The value. |
| `derived` | Read from the code: the `F_` calling conventions, `B_` distances between two globals. | The value. |
| `probed` | A layout offset found in the running client, different from before. | The value. |
| `candidate` | The best guess, below the threshold and not verified. | **`0`**, with the guess in a comment. |
| `rejected` | Failed its check, and no runner-up passed. | **`0`**. |
| `unused` | The closest reference build does not use this field (it has the feature in another form). | `0`. |
| `n/a` | No reference build has this field at all. | `0`. |
| `inherited` | A `B_` / `F_` value taken over from the older milestone or the modern layout. | Not repeated. |

### Feature groups

Some features need several values at once. When one member of a group is not usable, the whole group is
written as `0`, so the feature is off rather than half-working:

- the event hook (`E_REDIR`, `E_OLDDIR`);
- item properties;
- messages;
- pathfind;
- macros;
- send packet;
- the buff bar.

The snippet says which groups were zeroed and why.

## The knowledge base

`tools/EUOMigrate/kb/` holds one file per known build, `<version>-<PE stamp>.json.gz`. It contains
**derived data only**: hashed strings, the shape of the call graph, masked instruction shapes and short
signatures of the kind the EUOUpdater strings files already hold. It contains no part of the executable
and no game assets, so it can be committed. **Never commit a client executable.**

Each build in it is a reference: a new build is matched against all of them, and the closest one counts
most. Add every build you support with [`fingerprint`](#fingerprint), so the next build of the same
generation is matched against it rather than against an older relative.

Capstone is pinned to one version (`capstone==5.0.7` in `requirements.txt`): the knowledge base stores
instruction shapes in Capstone's text form, and another version may print some operands differently.

The disassembly, the function starts and the fingerprints of each exe are cached (keyed by its SHA-256) in
`%LOCALAPPDATA%\EUOMigrate\cache`, so a cached exe loads in a fraction of a second. Set the
`EUOMIGRATE_CACHE` environment variable to put the cache somewhere else. The cache file names carry
`TOOL_VERSION` from `euomig/__init__.py`: if you change how the disassembly, the function starts or the
fingerprints are computed, raise it (or empty the cache), or old results will be served.

## How it works

1. **Fingerprints.** Each function of an exe is described by what survives a recompile: the strings,
   imported functions, class names and unusual constants it uses; the functions it calls, in order; the
   globals it reads and writes. Each field of a known build is stored as a way to recognise it: the
   function it starts, a ±12-instruction window around a hook site, the global it is, an import slot, or
   "the target of the call at field X".
2. **Matching.** The reference's functions are paired with the new build's, strongest evidence first:
   tokens unique on both sides, vtable slots, rare-token similarity, aligned call sequences, matched
   callers and callees, shared globals, address order. A pair needs a clear best match in both directions.
   The steps that build on existing pairs repeat in rounds until a round adds nothing; then pairs that
   most of their neighbours contradict are dropped and the rounds resume, at most three times. The
   result does not depend on Python's hash seed: the same inputs give the same pairs in every run.
3. **Resolution.** A global is found by voting over the matched functions' aligned accesses; a hook site by
   aligning its instruction window inside the matched function. A field EasyUO only uses as a base
   (`C_LHANDID`) is located through the member it reads at a fixed distance from it, and so is its
   signature. Every field gets a ranked list of candidates, not just one value.
4. **Consensus.** Every knowledge-base build is matched on its own, and their candidates are pooled with
   the hits of each build's signatures. The closest build decides which form of a feature applies. On a
   fixed-base build, a value equal to the neighbouring milestones counts as confirmation.
5. **Flags and offsets from the code.** The `F_` flags come from the matched functions' entry code (which
   registers they read, how many bytes they pop). Distances such as `B_SKILLDIST` or `B_CLITOP` are found
   as globals in their own right.
6. **Signatures.** For every usable value, the smallest window that matches exactly once and resolves to
   the value, with addresses, branch targets and stack offsets wildcarded.

## How well it works

Measured on the builds at hand:

- **An older build it had never seen** (7.0.29.97, stamp `515F178B`): all 38 fields accepted. 30 of them
  can be checked against the hand-made scan strings, and all 30 agree.
- **A known build treated as unknown** (7.0.108.0, seeing only the older milestone): all 38 addresses and
  the 14 flags and offsets read from the code equal the verified table. After `verify` and `probe` on the
  running client, all 114 fields equal it.
- **Across a compiler change** (the fixed-base 7.0.117.1 and the first beta, each migrated from the other
  alone): most fields come out right or are flagged as unsure. Hooks whose meaning changed with the
  compiler cannot be inferred; see [Limits](#limits).
- **Speed.** Migrating the 7.0.117.31 beta (38,546 functions) against both knowledge-base builds takes
  28 seconds with an empty cache and 10 seconds with a warm one.

## Limits

- **A feature in another form.** When the closest known build implements a feature differently (an inlined
  constructor instead of a wrapper function, register instead of stack arguments), the fields of the new
  form cannot be inferred. The report flags them, and the `E_` comments in `uoclidata.pas` say what each
  form needs. Do these [by hand](/developers/manual-derivation/).
- **Layouts without a probe** stay inherited and are listed as such in the report: shop and bill,
  `B_CHARSTATUS`, `B_FINDREP` and the stat-gump fields. The self-test exercises all of them.
- **Live checks need something to look at.** Many globals are empty until something happens (no enemy,
  nothing on the cursor, no popup). `verify` then has nothing to confirm and leaves the static status.
- **Identical copies of a function.** When the client has two copies (the beta has two tick functions),
  only a running client shows which one is used.

## Source files

| File | What it does |
|---|---|
| `euomigrate.py` | The command line. |
| `euomig/pe.py` | PE reader: sections, imports, relocations, version resource, strings, class names. |
| `euomig/disasm.py` | Disassembly (Capstone), function starts, operand helpers. |
| `euomig/features.py` | Per-function fingerprints, hashed for the knowledge base. |
| `euomig/tables.py` | Reads `uoclidata.pas` (milestones, `ModernBuilds`) the way `TCstDB.Update` resolves them. |
| `euomig/fields.py` | Field descriptors; the `B_` distances treated as fields. |
| `euomig/match.py` | Function matching, global votes. |
| `euomig/resolve.py` | Descriptors to ranked candidates, for one reference. |
| `euomig/consensus.py` | All references to one result per field. |
| `euomig/sigs.py`, `euomig/siggen.py` | The EUOUpdater signature format; the signature generator. |
| `euomig/conv.py` | Calling conventions to `F_` flags. |
| `euomig/live.py`, `euomig/oracles.py`, `euomig/probe.py` | Read-only process access, the `verify` checks, the `probe` searches. |
| `euomig/emit.py` | `candidates.json`, the report and the Pascal snippet. |
| `euomig/kb.py` | Knowledge-base files. |

Its tests run on small synthetic executables, so they need no game files:

```powershell
python -m unittest discover -s tools/EUOMigrate/tests
```

CI runs them on every push.
