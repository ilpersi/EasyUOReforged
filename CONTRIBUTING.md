# Contributing to EasyUO Reforged

Thanks for your interest in helping. This is a spare-time community port, so
please keep changes focused and well-described.

## Ground rules

- **Preserve the outward contract.** Every script command, the full `UO.xxx` API
  surface, the `uo.dll` external ABI, and the deliberately-quirky behaviors real
  scripts depend on (tick timing, boolean encoding, `GOTO`/`GOSUB` semantics,
  etc.) must keep behaving exactly as the original Delphi 7 EasyUO does. If the
  original behaves a certain way, that is the spec — even when it looks like a
  bug. Call out anywhere you intentionally diverge.
- **Target stays `x86_64-win64`, Win32 widgetset.** Do not add 32-bit or
  non-Windows build assumptions.
- **Match the surrounding code.** The port keeps the original's structure and
  naming on purpose. Don't reformat or "modernize" unrelated code in a PR.

## Building

Requires Lazarus/FPC (developed against **Lazarus 3.6 / FPC 3.2.2**).

```
# one-time: make the project's packages known to lazbuild
lazbuild --add-package-link common/uocommon.lpk uo/uoengine.lpk parser/euoparser.lpk

# build (Release; drop --build-mode for the debug Default mode)
lazbuild --build-mode=Release uo.lpi
lazbuild --build-mode=Release EasyUOReforged.lpi
lazbuild --build-mode=Release EUOUpdtr.lpi
```

The three projects share code through Lazarus packages:

| Package | Folder | Contents |
|---|---|---|
| `uocommon` | `common/` | memory access, shared types, sorted-list container |
| `uoengine` | `uo/` | the UO client automation engine (depends on `uocommon`) |
| `euoparser` | `parser/` | the EasyUO scripting language (depends on `uoengine`, `LCL`) |

> Switching build modes with a forced rebuild (`lazbuild -B` alternating
> `--build-mode=Release` and Default) can leave stale package `.ppu` files and a
> "can't find unit" error. If that happens, `rm -rf */lib lib` and rebuild. Plain
> `lazbuild` (no `-B`) and the IDE are unaffected.

### Version string

`common/ReforgedVersion.pas` (the `#ReforgedVer` / title-bar / About value) is
**generated** by `tools/gen-version.ps1` and git-ignored. It is regenerated
automatically before every build (wired into `uocommon.lpk` as an "Execute Before"
command) and again by CI, so you never edit it by hand. A fresh checkout won't have
the file until the first build runs — that's expected; run `pwsh tools/gen-version.ps1`
if your editor complains before you've built.

## Tests

```
pwsh ./tests/run_tests.ps1
```

This builds `tests/RunTests.lpi` with lazbuild and runs the FPCUnit suite. Most
of it needs no game client; `LiveClientTests` exercises a real running client if
one is detected and reports its tests as *ignored* otherwise.

Add or extend tests for any logic change that doesn't strictly require a live
client (interpreter, expression/token handling, conversions, client-data tables,
UOP/MUL parsing, dispatch). CI runs the suite on every PR and must stay green.

## Pull requests

- Branch from `main`, one logical change per PR.
- Describe **what** changed and **why**, and how you verified it (tests added,
  or manual steps against a live client).
- If the change touches `uo/uoclidata.pas` or client-version support, follow
  [`docs/adding-client-support.md`](docs/adding-client-support.md) and say which
  client build(s) you tested against.

## Reporting bugs

Use the **Bug report** issue template. A minimal (<20 line) script that
reproduces the problem on a fresh run is the single most useful thing you can
provide — see the template for details.
