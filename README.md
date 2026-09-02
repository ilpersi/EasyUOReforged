# EasyUO Reforged

An in-progress port of **EasyUO** — a scripting tool for automating the *Ultima Online* game
client — from Delphi 7 to [Lazarus](https://www.lazarus-ide.org/)/Free Pascal, targeting modern
64-bit Windows.

EasyUO lets you write small scripts ("macros") that read and write a running UO client's process
memory, and patch small runtime hooks into it, to automate gameplay actions. This repository is
**not** the original project. The original Delphi 7 codebase, written by Cheffe, is what this port
is derived from.

## Goal

The original EasyUO only builds under Delphi 7, which is long out of support and increasingly
awkward to keep running on current Windows. The goal of this port is to get the same tool — same
scripting language, same commands, same behavior scripts already depend on — building and running
under the free, actively-maintained Lazarus/FPC toolchain instead, as a native 64-bit Windows
application.

This is deliberately **not** a 1:1 mechanical translation. Where FPC/Lazarus offers a cleaner or
safer way to do something (thread handling, memory access, dispatch tables, GUI plumbing) the
implementation has been modernized. But the outward contract — every script command, the full
`UO.xxx` API surface, the `uo.dll` external ABI, and the exact quirky behaviors real-world scripts
rely on (tick timing, boolean encoding, `GOTO`/`GOSUB` semantics, and more) — is meant to be
preserved exactly. Existing `.euo` scripts should keep working unmodified.

## Status

This is a working, actively-tested port, **not a finished, polished release**. This port is based on
last publicly available source of EasyUO that is available [here](http://www.easyuo.com/cheffe/EasyUO_Source.zip).
As per Cheffe own admission this version is deprecated so it is possible that this port is missing features.
All seven planned migration phases (foundational data/dispatch layer, scripting interpreter, UO client engine reads,
UO client engine code-caving, GUI shell, `uo.dll` + EUOUpdater, live-client verification) have
landed, and the project builds and runs. It is currently in an ongoing round of real-world testing
against a live UO client, fixing issues as they surface. Recent fixes include a script-execution
hang in `FindItem`, a crash in the variable inspector, the in-app `MENU` command (which drives real
GUI dialogs from script) not rendering at all, several `MENU` control-rendering glitches, missing
editor key bindings, and a stray console window behind the GUI.

Automated coverage exists (FPCUnit unit tests plus a golden-master script corpus under `tests\`)
for the interpreter core, the client-data tables, and other logic that doesn't require a live
game client. There is **no** automated coverage for anything that requires an actual running UO
client — that layer is only verified by hand, and only as far as testing has reached so far.

**In short: large parts of this port work and have been confirmed against a real client. Large
parts have not yet been exercised at all.** Treat anything not explicitly called out as tested
below as unverified.

### Confirmed working (tested against a live client)

- Client version detection / attaching to a running client.
- Core script execution (the interpreter, variables, flow control).
- `FindItem` and related item-scanning commands.
- The variable-inspector ("var dump") tool.
- The `MENU` script command's GUI rendering, including text, buttons (click handling), checkboxes,
  edit fields, and images.
- The script editor (including previously-broken key bindings like Backspace/Delete).

### Known limitations

- **Symbol/Wingdings-style icon fonts (`MENU TEXT`/`BUTTON`/`CHECK` using fonts like Wingdings) only
  render correctly if that exact font is installed.** If a script requests a font (e.g. "Wingdings
  2") that isn't actually present on the machine, Windows silently substitutes a different
  installed font at the same character code — this port reproduces that behavior (matching what the
  original Delphi build also does), but the substituted glyph can look wrong or unrelated to what
  the script author intended.
- **`MENU IMAGE` format coverage is uncertain beyond common raster formats** (BMP/PNG/JPEG/GIF).
  The original used a VCL/ActiveX image loader with broader legacy format support (e.g. WMF/EMF/ICO)
  that has no direct LCL equivalent; scripts relying on those formats may not work correctly yet.
- **64-bit only.** This port targets `x86_64-win64` exclusively — it does not build for 32-bit
  Windows. (It still works against 32-bit UO client processes; the automation techniques used here
  work across bitness.)
- **The `uo.dll` external stack-API surface has not been verified against any real external
  consumer.** It's built and exports the expected decorated names, but nothing outside this
  project's own test harness has exercised it end-to-end yet.
- **`EUOUpdater`** (the tool used to derive new client-version memory offsets) has had only light
  testing relative to the main application.
- **`Client Support`** As this port is based on a deprecated EUO version, client support for new clients
  is limited. I was able to add support for current last released client 7.0.117.0 and for a few other
  clients that I had available (7.0.108.0 and 7.0.99.1) and these are probably not the last ones needed.
  `tools\EUOUpdater` (see its `readme.txt`) covers most of what a new version needs -- including a 
  `{SYSMSGSTR_CHECK}` diagnostic added specifically because of what 7.0.108.0 needed -- but some fields
  are only ever hand-copied forward from the closest known version, so live disassembly may still be
  required for newer clients occasionally. See [`docs/adding-client-support.md`](docs/adding-client-support.md)
  for the full step-by-step process.
- General maturity: this is a young port of a codebase with a very large surface area (roughly 140
  scripting API entries plus dozens of GUI/editor features). Bugs turning up during ordinary use,
  especially in less-common script commands or GUI menu features, should be expected.

### Additions beyond the original
- **`Script Editor`** — The script editor now has: line number, basic Ctrl+Space auto complete suppport,
  normal break points, conditional break points (the syntax is basic <var_name> <operator> <value> so don't
  expect to run full scripts in that), run to cursor and call stack for nested sub calls.
- **`TILE script command`** — Now has built-in support for UOP file format without the need to manually exctract
  files in the old MUL format. 
- **`MENU MEMO <name> <x> <y> <w> <h> <text>`** — a multi-line counterpart to `MENU EDIT`
  (scrollable `TMemo`; `$` in `<text>` becomes a line break, as in `MENU TEXT`). `MENU GET`
  returns its contents with line breaks folded back to `$`. Used by
  [`docs/report-diagnostics.euo`](docs/report-diagnostics.euo).

## Download & run

Prebuilt Windows x64 binaries are on the
[**Releases**](https://github.com/ilpersi/EasyUOReforged/releases) page. Download
`EasyUOReforged-<version>-win64.zip`, unzip it anywhere, and run
`EasyUOReforged.exe` — no installer. Keep `uo.dll` next to it. `EUOUpdtr.exe` is
only needed if you're adding support for a new client version
([guide](docs/adding-client-support.md)).

Start your Ultima Online client and log in first; EasyUO Reforged detects running
clients on its own. Then paste a script into a tab and press Play. (EasyUO
Reforged is `x86_64-win64` only — see *Known limitations* on client bitness.)

New to it? See [**`docs/getting-started.md`**](docs/getting-started.md) for a
first-run walkthrough (window layout, running and debugging a script, multiple
clients).

Each release is built entirely in public by GitHub Actions
([`release.yml`](.github/workflows/release.yml)) from the tagged commit, and ships
with SHA-256 checksums (`…zip.sha256` for the archive, `SHA256SUMS.txt` for the
files inside).

### Antivirus & SmartScreen

EasyUO Reforged automates the game by **reading and writing the UO client's
process memory and patching small code hooks into it** — the same techniques a
debugger or a game trainer uses. Because of that:

- **Windows SmartScreen** will warn that the app is unrecognized (the binaries
  are not code-signed). Choose *More info → Run anyway* if you trust the
  download.
- **Windows Defender or third-party AV** may flag the executable heuristically.
  This is expected for this class of tool and is not, by itself, evidence the
  binary is malicious.

What you can do:

1. **Verify the checksum.** Compare your download against the `.sha256` file
   published with the release:
   ```
   Get-FileHash EasyUOReforged-<version>-win64.zip -Algorithm SHA256
   ```
2. **Check the build is reproducible-in-public.** Every release is compiled by
   the workflow above on GitHub's runners from a specific tagged commit — nothing
   is uploaded by hand.
3. **Scan it yourself** (e.g. VirusTotal) and, if you believe a detection is a
   false positive, report it to your AV vendor.
4. **Build from source** (below) if you'd rather not trust a prebuilt binary at
   all.

See also [`SECURITY.md`](SECURITY.md).

## Writing scripts

The scripting language itself — every command, every `#variable`, the expression
syntax — is **not** re-documented in this repository. It is the same language as
the original EasyUO, documented on the **EasyUO wiki**:

- **Command / variable reference:** <http://wiki.easyuo.com>
- **Script help, examples, community:** <http://www.easyuo.com>

This port aims to run existing `.euo` scripts unchanged. `#EUOVer` still returns
the original value (`1_50_00`) so version checks keep working; `#ReforgedVer`
is this port's own build version. Anywhere behaviour intentionally differs, or a
command is incomplete, is listed under *Known limitations* and *Additions beyond
the original* above.

[`docs/getting-started.md`](docs/getting-started.md) covers running and debugging
scripts in the app.

## Building

Requires Lazarus/FPC targeting `x86_64-win64` (Win32 widgetset); developed against **Lazarus 3.6
/ FPC 3.2.2**. Three independent projects share code through Lazarus packages (`uocommon` in
`common\`, `uoengine` in `uo\`, `euoparser` in `parser\`):

| Project | Output | Purpose |
|---|---|---|
| `EasyUOReforged.lpi` | `EasyUOReforged.exe` | Main GUI script editor/runner. |
| `uo.lpi` | `uo.dll` | The client engine exposed as a generic external stack-based API. |
| `EUOUpdtr.lpi` | `EUOUpdtr.exe` | Dev tool for deriving new client-version memory offsets. |

Build headlessly with `lazbuild`. Register the project's packages once, then build (use
`--build-mode=Release` for a stripped, optimized binary; omit it for the debug `Default` mode):

```
lazbuild --add-package-link common/uocommon.lpk uo/uoengine.lpk parser/euoparser.lpk
lazbuild --build-mode=Release uo.lpi
lazbuild --build-mode=Release EasyUOReforged.lpi
lazbuild --build-mode=Release EUOUpdtr.lpi
```

Automated tests live under `tests\` and run via `tests\run_tests.ps1` (which builds
`tests\RunTests.lpi` with lazbuild). Most of the suite needs no live client at all; a separate
opt-in suite (`LiveClientTests.pas`) automatically exercises a real running client if one is
detected, and otherwise reports those specific tests as skipped rather than failed. CI
(`.github/workflows/ci.yml`) runs the full build and test suite on every push and PR.

## Versioning

Builds are versioned `YY.MM.DD.<short git commit>` (e.g. `26.09.02.e25a4d9`) — the
build date plus the exact commit it was built from. This one value is generated by
`tools/gen-version.ps1` (automatically, before every build) and shown in the window
title bar, under **Help → About**, and as the `#ReforgedVer` script variable.
`#EUOVer` is unchanged — it still returns the original EasyUO value (`1_50_00`) for
script compatibility.

## Reporting bugs

Open a GitHub issue using the **Bug report** template. Two things make a report
actionable:

- **It has to be reproducible.** If the bug can't be made to happen on our side,
  it can't be fixed. Include a script that triggers it on a fresh run.
- **Keep the script minimal.** Cut it down to the fewest lines that still show
  the problem (ideally under ~20). Full scripts with your whole setup in them
  will be sent back for minimization first.

Run [`docs/report-diagnostics.euo`](docs/report-diagnostics.euo) with your client
attached and paste its output into the report - it collects the client version,
shard, and other environment details we need.

## Disclaimer

**EasyUO Reforged is not an official or endorsed replacement for the original EasyUO.** It is an
independent, community-driven port, not affiliated with the original author. It is offered as-is,
under the BSD 2-Clause License, the same license as the original (see `LICENSE` and `NOTICE`
in this repository), with no warranty of any kind.

This is an **evolving, work-in-progress project**. Most of it has not been exhaustively tested,
some features are known to be incomplete or behave differently from the original (see "Known
limitations" above), and issues not yet discovered should be expected. If you rely on EasyUO for
anything important, keep using the original Delphi 7 build alongside this one until you've
independently verified the scripts and features you need actually work correctly here. Use at your
own risk, and please report issues you find.
