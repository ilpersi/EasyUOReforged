# Architecture

How the codebase is laid out and the design decisions that aren't obvious from
reading it. For build instructions see
[Build from source](https://ilpersi.github.io/EasyUOReforged/developers/building/); for the
scripting language see the [documentation site](https://ilpersi.github.io/EasyUOReforged/).

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
  (`uocommands`, with `tiles` + `uopfile` for tile data), the pathfinder
  behind the `PATH` command (`walkmap` world model from the map files,
  `walkrules` step rules ported from ClassicUO, `pathplan` A* planner; see
  [pathfinding.md](pathfinding.md)), event synthesis via
  code-caving (`uoevents`), the Lua-C-API-style stack machine + name-dispatch
  tables (`stack`, `tables`), and the flat external API surface (`uodef`,
  `uowrap`).
- **`parser/`** — EasyUO's own scripting language, unrelated to the stack
  machine above. `EuoInterpreter` (`TEuoInterpreter`) is the line-cursor
  execution engine — one private method per script command. Around it:
  tokeniser/expression evaluator (`EuoTokens`, `EuoExpression`), value
  conversion (`EuoConversion`), thread-safe script variables (`EuoVariables`),
  the loaded-script / call-return model (`EuoScriptStack`), the `MENU` command
  driving real LCL controls in two logics, EasyUO 1.5's (`EuoMenu`) and
  EasyUO 1.6's (`EuoMenu16`), chosen per script (`EuoMenuSelect`; see
  [Two MENU logics](#two-menu-logics) below), `Send` (`EuoComm`), the `SQL`
  command's SQLite engine (`EuoSql`, a port addition that loads Windows'
  `winsqlite3.dll` lazily through FPC's `sqlite3dyn`; see
  [`sql.md`](sql.md)), and the background execution state machine with
  breakpoints and stepping (`EuoExecutor`, `EuoBreakCondition`,
  `EuoCallStackFormat`). Beside the interpreter sit pure units that read a
  script without running it, each built on the interpreter's own rules: the
  block structure (`EuoBlocks`), how a line becomes words (`EuoScriptWords`),
  where a `gosub` or `goto` leads (`EuoJumpTarget`), the sub-command table
  (`EuoVocabulary`) and the script checker (`EuoLint`; see
  [The script checker](#the-script-checker) below).
- **`easyuo/`** — the GUI: a multi-tab `TSynEdit` editor, the syntax
  highlighter, a live variable-inspector tree, and the menu/toolbar that drive
  `TExecutor`. The whole window is built in code (see below).
- **`tools/`** — `EUOUpdater/` (a standalone utility for deriving offsets for a
  new client version; keeps its own forked copies of a couple of units),
  `EUOMenuDesigner/`, `EUOCli/` (the command-line program) and
  `gen-version.ps1` (the version generator).
- **`agent/`** — the hand-written part of the agent pack: what AI coding agents
  read to write scripts. `tools/docs/gen-agent-pack.mjs` adds the documentation
  site's pages as plain markdown and writes the pack into a release zip and into
  the site. Plan and state: [agent-support.md](agent-support.md).

## Five build targets, shared through packages

| Project | Output | Purpose |
|---|---|---|
| `EasyUOReforged.lpi` | `EasyUOReforged.exe` | The GUI script editor/runner end users run. |
| `uo.lpi` | `uo.dll` | The `uo/` engine exposed as a generic, stack-based external API. |
| `EUOUpdtr.lpi` | `EUOUpdtr.exe` | Offset-derivation dev tool. |
| `EUOMenuDesigner.lpi` | `EUOMenuDesigner.exe` | The MENU Designer (see [The MENU Designer](#the-menu-designer)). |
| `EUOCli.lpi` | `EUOCli.exe` | The command-line program: `check` (see [The script checker](#the-script-checker)), `run`, `vars`, `clients` (see [Running a script with nobody watching](#running-a-script-with-nobody-watching)). |

`common/`, `uo/`, and `parser/` are Lazarus packages (`uocommon.lpk`,
`uoengine.lpk`, `euoparser.lpk`) so the projects — and the test project —
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
icons are in the MENU Designer's style: `easyuo/make_toolbar_icons.py` writes them
into `mainiconsdata.pas` as base64 PNGs. The application icon keeps the original's
emblem: `easyuo/make_app_icon.py` writes `appicon.ico`, `appicon.res` (the
executables' icon, and the taskbar's) and `appicondata.pas` (the windows' copy).

### Syntax highlighter

The original drove `TSynUniSyn` from an XML rule file (`EUOSyn.hlr`) using the
Delphi-era UniHighlighter schema. Lazarus's bundled `SynUniHighlighter` uses a
different, thinly-documented schema and won't load that file. `easyuo/eusyntax.pas`
instead builds the same `TSynRange` / `TSynSymbolGroup` object model the file
loader would have built, directly in code, transcribed from `EUOSyn.hlr`'s
keyword/colour/range data. Two narrow, cosmetic gaps versus the original are
documented in that unit's header.

Code folding (a port addition) needs a `TSynCustomFoldHighlighter`, which
`TSynUniSyn` is not. `easyuo/eufoldsyn.pas`'s `TSynEUOSyn` is a fold highlighter
that wraps a private `TSynUniSyn` built by the same `BuildEUOHighlighter` and
forwards every token call to it, so colouring is unchanged. Where blocks start and
end comes from `parser/EuoBlocks.pas`, a pure unit that encodes the interpreter's
own block rules (`GetCmd`, `ScanForBlock`, `SubProc`, `UNTIL`, `+` continuation
lines); *Edit → Format Script* indents by the same rules, so folds and indentation
always agree.

### `uoclidata.pas` — milestone/delta model

The original was a flat table: one ~80-field record per client version, ~220
versions. The port stores it as sparse **milestones** — one small delta array per
point where the resolved offsets actually changed — applied cumulatively at
runtime by `TCstDB.Update`. `Update` can also take a live process handle and
layer a dynamic signature scan on top, for fields a not-yet-milestoned client
needs. The re-encoding was done mechanically (`tests/tools/DeriveCstDbMilestones.ps1`)
and is verified end-to-end against a golden fixture (see *Testing*).

Adding a new client version is the most common maintenance task — see
[Add a new client](https://ilpersi.github.io/EasyUOReforged/developers/adding-a-client/) on the documentation site.

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

Stop is the one transition that differs from the original on purpose: it marks the
script stopped *before* it breaks the wait the script is in. The original broke the
wait first, and the line after a `wait` could then run once more, about one stop in
four. `TestStopDuringAWaitRunsNothingMore` stops twenty times in a row.

### Two MENU logics

EasyUO 1.5, the published source this port starts from, and EasyUO 1.6, closed builds from
about 2017, have different `menu` systems, and scripts depend on either. They conflict (how names
work, what `#MenuButton` says, what starting a script does to the windows), so Reforged keeps them
as two separate implementations and runs a script under one of them:

- `parser/EuoMenu.pas` (`TMenuObj`, dispatched by `TEuoInterpreter.MenuProcSync`) is the 1.5
  port, unchanged by the split.
- `parser/EuoMenu16.pas` (`TMenu16`, with its own dispatcher, `TMenu16.Run`) ports what EasyUO
  1.6.0.337 does, read from the binary. Golden values recorded from the real program pin it:
  `tests/tools/Record16MenuGolden.py` runs the probes in `tests/fixtures/menu16` and writes what
  1.6 showed next to them, and `EuoMenu16GoldenTests` replays them against the port.
- `parser/EuoMenuCommon.pas` holds what both need because of LCL and Windows: the window and
  button classes, Symbol-font remapping, the image primitives, colour conversion.
- `parser/EuoMenuSelect.pas` chooses one when a stopped script starts (`TEuoInterpreter.Clear`):
  `menu reforge mode` in the script, otherwise any of the nine 1.6-only sub-commands, otherwise
  1.5. `TExecutor.LoadScript` puts the new text in place before that `Clear`, since Play does not
  reliably run a second one.

Both logics run on the main thread through `TThread.Synchronize`, like any LCL work. The editor's
status bar shows the logic of each tab's run. The analysis of 1.6, the plan, the design decisions
and the evidence are in [menu-1.6-analysis.md](menu-1.6-analysis.md).

### The MENU Designer

`EUOMenuDesigner.exe` (`tools/EUOMenuDesigner/`) lays out 1.6 MENU windows and reads them back
from scripts. It reuses the 1.6 logic instead of a second copy of its rules:

- **The canvas, the Preview and the importer run a real `TMenu16`.** The canvas runs each form's
  generated sub and hosts the form's Surface in a tab, with every hosted window answering
  `WM_NCHITTEST` with `HTTRANSPARENT` so the designer gets the mouse. The importer replays a
  script's `menu` lines in a hidden `TMenu16` and reads the controls back with `getprop`
  (read-only registry and property-table accessors on `EuoMenu16` make that possible).
- **Lines are read with the interpreter's code:** `parser/EuoScriptWords.pas` holds the `+`
  continuation, the `.`/`,` glue with its substitution hook, `IsVar` and the `TParList` fill, moved
  out of `TEuoInterpreter.ParseLine`, which calls them.
- **Table-driven:** `mdtypes.pas` has a row per 1.6 control type; `CheckDocsCoverage.ps1` fails when
  the 1.6 logic gets a type, property or sub-command the designer does not cover.

The plan, its decisions and the file layout are in [menu-designer.md](menu-designer.md).

### The script checker

The interpreter reports no errors: a line it cannot understand is skipped. `parser/EuoLint.pas`
(`TEuoLinter`) reports what it would skip or misread, without running anything, and
`EUOCli.exe check` (`tools/EUOCli/`) is that as a command, for people and for AI coding agents
([agent-support.md](agent-support.md), phase 2).

- **Nothing is copied from the interpreter.** The command and variable names come from it
  (`TEuoInterpreter.GetCommandNames` / `GetVariableNames`, two read-only views of the registry and of
  `VarNamesR` / `VarNamesRW`); lines, blocks and jumps are read with `EuoScriptWords`, `EuoBlocks`,
  `EuoJumpTarget` and `EuoMenuSelect`; sub-commands come from `EuoVocabulary`, the table the editor's
  autocomplete offers. `CheckDocsCoverage.ps1` fails when that table's first level, or its list of the
  commands that calculate, differs from the handlers.
- **It only warns.** Old scripts rely on odd behaviour. A word that only exists at run time (held in a
  variable, glued with `,` or `.`) is never reported, and plain text in `set` and `if` lines is left alone.
- **It is checked against the project's own scripts.** `tests/DocsLintTests.pas` runs it over every `euo`
  example of the site and the self-test scripts and fails on a warning; deliberate mistakes are in its
  `Excepted` table with the reason.
- **`EUOCli.exe` ends with `TerminateProcess`.** Linking the engine starts `uoselector.pas`'s client scan
  at program start, and its finalization stops that thread with `TerminateThread`. A program that is done
  in milliseconds reaches the finalization while the thread still holds locks, and hung about every other
  run. `EUOCli.lpr`'s header has the details.

### Running a script with nobody watching

`EUOCli.exe run` (`tools/EUOCli/clirun.pas`) runs a script on the same `TExecutor` the editor uses, for
a program or an AI coding agent that cannot click, press Stop or look at the game
([agent-support.md](agent-support.md), phase 3). The main thread pumps the LCL message loop (MENU builds
its windows there) and prints what the script's thread queues. Everything it needs from the engine is a
hook that is off unless a host turns it on, so the editor and `uo.dll` run scripts exactly as before:

| Hook | Where | What a host gets |
|---|---|---|
| `OnDisplay` | `TStdCmd`, through `TEuoInterpreter.OnDisplay` | It answers `display` itself; no message box opens. |
| `BlockCommands` | `TEuoCommandRegistry.SetBlocked` | Named commands stop the run instead of running (`BlockedCmd`, `BlockedLine`). |
| `Restarts` | `TEuoInterpreter.ExitProc` | A count of how often the main script started over; the restart itself is untouched. |
| `StopOnRestart`, `OnLine` | `TExecutor` | The run stops when the script starts over; each line is announced before it runs. |
| `ClientSkips` | `TEuoCommandRegistry.Dispatch` | How many lines were skipped for lack of a client. |

Three rules of `run` are safety rules, decided with the project's owner: a script runs **without a client
unless the command line says `--client N`** (the editor attaches to client 1 by itself, `run` never does);
`execute`, `shutdown`, `terminate`, `uoxl` and `send` are blocked unless `--allow` names them, and a blocked
command **stops** the run; and a run always ends (a timeout, and the restart of a script without `halt`).

The **`log` command** is the one addition to the language here: a line of text for whoever runs the script.
The interpreter queues it (`TakeLog`, its own lock, the newest 10,000 lines) and the host empties the queue:
`EUOCli run` prints it, and the editor's 100 ms timer moves it to the Output panel (`easyuo/euoutput.pas`
formats and bounds the panel's text).

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
- **Golden values from EasyUO 1.6**: `EuoMenu16GoldenTests` runs each probe script in
  `tests/fixtures/menu16` under the 1.6 MENU logic and compares its reports, window geometry and
  image pixels with what the closed EasyUO 1.6.0.337 showed when
  `tests/tools/Record16MenuGolden.py -Exe <easyuo.exe>` recorded them.
- **`LiveClientTests.pas`** exercises a real running client if one is detected and
  reports its tests as *ignored* otherwise. Nothing that needs a live client has
  automated coverage beyond this; that layer is hand-verified.

## Build modes

Both `.lpi` build modes target `x86_64-win64`:

- **Default** — debug info, no optimisation. What the IDE and plain `lazbuild` use.
- **Release** — smart-linking + strip + `-O3`, separate `lib\...-release\` output
  dir. ~10x smaller binaries. Used by CI and the release workflow
  (`lazbuild --build-mode=Release`).
