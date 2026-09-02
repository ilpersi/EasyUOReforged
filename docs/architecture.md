# Architecture

How the codebase is laid out and the design decisions that aren't obvious from
reading it. For build instructions see the README; for the scripting language see
the EasyUO wiki.

## Layers

The source is organised bottom-up. Each layer only depends on the ones below it.

```
easyuo/   GUI shell  (EasyUOReforged.exe)
   |
parser/   the EasyUO scripting language  ── package: euoparser
   |
uo/       the UO client automation engine  ── package: uoengine
   |
common/   OS-facing primitives  ── package: uocommon
```

- **`common/`** — process-memory access (`ReadMem` / `WriteMem` — a
  binary-search retry loop around `ReadProcessMemory` / `WriteProcessMemory`
  that tolerates partially-unreadable pages — and `SearchMem`, a byte-pattern
  scanner), shared types, and a generic sorted-list container.
- **`uo/`** — everything needed to fingerprint, read/write, and hook a running
  UO client: version detection (`uoscanver`), the per-version memory-offset
  table (`uoclidata`), the client-window selector (`uoselector`), named state
  reads/writes (`uovariables`), higher-level actions like FindItem/Click
  (`uocommands`, with `tiles` + `uopfile` for tile data), event synthesis via
  code-caving (`uoevents`), the Lua-C-API-style stack machine + name-dispatch
  tables (`stack`, `tables`), and the flat external API surface (`uodef`,
  `uowrap`).
- **`parser/`** — EasyUO's own scripting language, unrelated to the stack
  machine above. `EuoInterpreter` (`TEuoInterpreter`) is the line-cursor
  execution engine — one private method per script command. Around it:
  tokeniser/expression evaluator (`EuoTokens`, `EuoExpression`), value
  conversion (`EuoConversion`), thread-safe script variables (`EuoVariables`),
  the loaded-script / call-return model (`EuoScriptStack`), the `MENU` command
  driving real LCL controls (`EuoMenu`), `Send` (`EuoComm`), and the background
  execution state machine with breakpoints and stepping (`EuoExecutor`,
  `EuoBreakCondition`, `EuoCallStackFormat`).
- **`easyuo/`** — the GUI: a multi-tab `TSynEdit` editor, the syntax
  highlighter, a live variable-inspector tree, and the menu/toolbar that drive
  `TExecutor`. The whole window is built in code (see below).
- **`tools/`** — `EUOUpdater/` (a standalone utility for deriving offsets for a
  new client version; keeps its own forked copies of a couple of units) and
  `gen-version.ps1` (the version generator).

## Three build targets, shared through packages

| Project | Output | Purpose |
|---|---|---|
| `EasyUOReforged.lpi` | `EasyUOReforged.exe` | The GUI script editor/runner end users run. |
| `uo.lpi` | `uo.dll` | The `uo/` engine exposed as a generic, stack-based external API. |
| `EUOUpdtr.lpi` | `EUOUpdtr.exe` | Offset-derivation dev tool. |

`common/`, `uo/`, and `parser/` are Lazarus packages (`uocommon.lpk`,
`uoengine.lpk`, `euoparser.lpk`) so all three projects — and the test project —
resolve the shared code the same way instead of each carrying its own unit
search paths. `lazbuild --add-package-link common/uocommon.lpk uo/uoengine.lpk
parser/euoparser.lpk` registers them once.

**`EasyUOReforged.exe` does not load `uo.dll` at runtime.** The GUI links the
`uoengine` package directly. `uo.dll` exists only for *other* programs that want
to drive a UO client through the generic stack API; nothing in this repo consumes
it except the DLL smoke test.

## Key decisions

### 64-bit host, 32-bit client

EasyUO Reforged is built `x86_64-win64` only. The classic UO client it automates
is a 32-bit process.

- `ReadProcessMemory` / `WriteProcessMemory` work across the bitness boundary, so
  `common/access.pas` is bitness-agnostic. Handles that used to be `Integer` in
  the DLL ABI are now `PtrInt` (`uo/uodef.pas`) because a 64-bit process's object
  handles are real 64-bit pointers.
- `uo/uoevents.pas` ("code caving") writes raw **x86-32** machine-code bytes into
  an unused executable page of the client and points the client at them to
  synthesize events the UO protocol doesn't expose. Those bytes run *inside the
  client*, so they stay 32-bit regardless of this host being 64-bit — but it does
  mean this layer assumes a 32-bit client process. It is plain data (byte/string
  literals), not a Pascal `asm` block, so nothing about it needed porting beyond
  two mechanical unit-reference fixes.

### One real inline-assembly block

`common/access.pas`'s `FindPos` (the inner loop of `SearchMem`) is the only
genuine x86 `asm` block in the codebase. It is Intel-syntax and compiles under
`{$ASMMODE INTEL}`. Everything else that looks like machine code (`uoevents`) is
data.

### The GUI is built entirely in code

There is no `.lfm` form file. The original `main.dfm` embedded its icon and image
list as Delphi-format binary property streams, which don't translate cleanly to
LCL's streaming format. Rather than risk a subtly-broken hand-converted `.lfm`,
`easyuo/main.pas` constructs and wires every control in code. The toolbar/menu
icons are reconstructed at runtime by `mainicons.pas` from the original DFM's
(standard-format underneath) bitmap and icon streams.

### Syntax highlighter

The original drove `TSynUniSyn` from an XML rule file (`EUOSyn.hlr`) using the
Delphi-era UniHighlighter schema. Lazarus's bundled `SynUniHighlighter` uses a
different, thinly-documented schema and won't load that file. `easyuo/eusyntax.pas`
instead builds the same `TSynRange` / `TSynSymbolGroup` object model the file
loader would have built, directly in code, transcribed from `EUOSyn.hlr`'s
keyword/colour/range data. Two narrow, cosmetic gaps versus the original are
documented in that unit's header.

### `uoclidata.pas` — milestone/delta model

The original was a flat table: one ~80-field record per client version, ~220
versions. The port stores it as sparse **milestones** — one small delta array per
point where the resolved offsets actually changed — applied cumulatively at
runtime by `TCstDB.Update`. `Update` can also take a live process handle and
layer a dynamic signature scan on top, for fields a not-yet-milestoned client
needs. The re-encoding was done mechanically (`tests/tools/DeriveCstDbMilestones.ps1`)
and is verified end-to-end against a golden fixture (see *Testing*).

Adding a new client version is the most common maintenance task — see
[`adding-client-support.md`](adding-client-support.md).

### `uo.dll` export names

`uo.lpr` still hand-specifies decorated stdcall names (`name '_UOOpen@0'`, …) as
literal aliases for continuity with any hypothetical existing consumer. On Win64
there is no stdcall name-decoration convention, so the `@N` suffixes carry no
calling-convention meaning — they're inert historical strings. `uo.lpi` sets
`ExecutableType = Library` so lazbuild emits `uo.dll` rather than `uo.dll.exe`.

### Execution model

`parser/EuoExecutor.pas` runs one `TEuoInterpreter` on a background `TThread`
(`TExeThread`) with Play / Pause / Stop / StepInto / StepOver / StepOut control.
The GUI creates one `TExecutor` per open script tab (`easyuo/insthandler.pas`).
Script variables (`EuoVariables`) are guarded by a critical section because the
GUI thread polls them for the inspector while the script thread mutates them.

### Preserved quirks

The porting rule is: the outward contract does not change. Tick timing (50 ms
everywhere except `SLEEP`), boolean encoding (Int64 `-1`/`0`), `GOTO`/`GOSUB`
resolution order, `EXIT` at the outermost frame restarting rather than stopping,
Sys26 ID encoding, and more are ported behaviour-for-behaviour. `EuoInterpreter.pas`'s
header comment inventories them; each has a matching test.

## Versioning

`tools/gen-version.ps1` writes `common/ReforgedVersion.pas` (git-ignored):

```pascal
const REFORGED_VERSION = 'YY.MM.DD.<short git commit>';
```

It runs before every build (wired into `uocommon.lpk` as an *Execute Before*
command; every target depends on `uocommon`) and again in CI, and only rewrites
the file when the value changes. `REFORGED_VERSION` feeds the title bar, `Help ->
About`, and the `#ReforgedVer` script variable. `#EUOVer` is left at the original
`1_50_00` for script compatibility.

## Testing

`tests/` is an FPCUnit suite (`RunTests.lpi`, run via `tests/run_tests.ps1`,
gated in CI):

- **Unit tests** for the interpreter, tokeniser/expression evaluator, conversion,
  the stack machine and dispatch tables, `access` (against a fake target), UOP/MUL
  tile parsing (against synthetic fixtures generated independently in PowerShell),
  and more.
- **Golden-master** check: `TestAllVersionsAgainstGoldenFixture` resolves all ~220
  client versions through the real `TCstDB` and compares every getter against
  `tests/fixtures/uoclidata_golden.json`, which is extracted straight from the
  *original* Delphi source by `tests/tools/VerifyCstDbData.ps1` — an independent
  implementation, so a bug in the port is unlikely to be mirrored in the fixture.
- **`LiveClientTests.pas`** exercises a real running client if one is detected and
  reports its tests as *ignored* otherwise. Nothing that needs a live client has
  automated coverage beyond this; that layer is hand-verified.

## Build modes

Both `.lpi` build modes target `x86_64-win64`:

- **Default** — debug info, no optimisation. What the IDE and plain `lazbuild` use.
- **Release** — smart-linking + strip + `-O3`, separate `lib\...-release\` output
  dir. ~10x smaller binaries. Used by CI and the release workflow
  (`lazbuild --build-mode=Release`).
