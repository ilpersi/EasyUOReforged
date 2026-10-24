---
title: Build from source
description: "How to build EasyUO Reforged, uo.dll and EUOUpdater with Lazarus, run the test suite, work in the Lazarus IDE, build this site, and fix the usual build errors."
sidebar:
  order: 2
---

EasyUO Reforged is three Windows programs, built with Lazarus / Free Pascal from one repository. You need
to build it to try a change of your own, for example a new client entry. To just use it, take the zip from
the [releases page](https://github.com/ilpersi/EasyUOReforged/releases) instead.

| Project | Builds | What it is |
|---|---|---|
| `EasyUOReforged.lpi` | `EasyUOReforged.exe` | The script editor and runner. |
| `uo.lpi` | `uo.dll` | The client engine as a DLL, for other programs ([uo.dll API](/dll/)). `EasyUOReforged.exe` does not use it. |
| `EUOUpdtr.lpi` | `EUOUpdtr.exe` | EUOUpdater, the scan tool for new client builds ([Deriving values by hand](/developers/manual-derivation/)). |

## What you need

- **Windows, 64-bit.** Everything builds for `x86_64-win64` only.
- **Lazarus 3.6 or newer**, from the 64-bit Windows installer on [lazarus-ide.org](https://www.lazarus-ide.org/).
  It includes Free Pascal 3.2.2 and the two editor packages the GUI uses (SynEdit and the SynUni
  highlighter), so there is nothing else to install. The project was developed on Lazarus 3.6; CI builds
  every push with the current stable release.
- **Git**, to clone the repository. The build also uses it to put the commit into the version string.
- **PowerShell 7** (`pwsh`), for the test script.

For [this site](#build-the-documentation-site) you also need Node.js, and for EUOMigrate, Python (see
[Using EUOMigrate](/developers/euomigrate/)).

## 1. Get the source

```powershell
git clone https://github.com/ilpersi/EasyUOReforged.git
cd EasyUOReforged
```

## 2. Make lazbuild reachable

`lazbuild.exe` builds a Lazarus project from the command line. The installer does not put it on `PATH`:
it is in the Lazarus folder, `C:\lazarus` unless you chose another one. For the current PowerShell
window:

```powershell
$env:Path += ';C:\lazarus'
lazbuild --version
```

To keep it, add the folder to your `PATH` in Windows (*Edit environment variables for your account*).

## 3. Register the packages

The three programs share their code through three Lazarus packages. Tell Lazarus where they are, once per
machine:

```powershell
lazbuild --add-package-link common/uocommon.lpk uo/uoengine.lpk parser/euoparser.lpk
```

| Package | Folder | Contents | Uses |
|---|---|---|---|
| `uocommon` | `common/` | Reading and writing the client's memory, shared types. | |
| `uoengine` | `uo/` | The client engine: version detection, offset tables, variables, commands, events. | `uocommon` |
| `euoparser` | `parser/` | The script language: interpreter, expressions, script execution. | `uoengine`, `uocommon` |

The links are saved in your Lazarus configuration, so the IDE finds the packages too. They point at one
folder: if you keep a second clone or a git worktree, its builds still compile the packages of the clone
you registered last. Run the command again in the clone you are working in.

## 4. Build

```powershell
lazbuild --build-mode=Release uo.lpi
lazbuild --build-mode=Release EasyUOReforged.lpi
lazbuild --build-mode=Release EUOUpdtr.lpi
```

Build one, two or all three, in any order. The programs land in the repository folder, next to the
`.lpi` files. From a fresh clone, all three together take well under a minute.

Each project has two build modes. Both write the same file name, so the last build wins.

| Mode | For |
|---|---|
| `Default` (leave out `--build-mode`) | Debugging: debug information, light optimization. |
| `Release` | What a release ships: optimized (`-O3`), no debug information, symbols stripped. |

The modes keep their compiled units in separate folders (`lib\x86_64-win64\` and
`lib\x86_64-win64-release\`). EUOUpdater has folders of its own, because its `main` unit has the same name
as the GUI's.

### The version string

Before every build, `tools/gen-version.ps1` writes `common/ReforgedVersion.pas` with a version such as
`26.10.24.70afbc8`: today's date and the current commit. The title bar, *Help → About* and
[`#ReforgedVer`](/variables/reforgedver/) show it. The file is git-ignored and only rewritten when the value
changes. A fresh clone does not have it until the first build: if your editor complains before then, run
`pwsh tools/gen-version.ps1`. Without Git, the commit part reads `nogit`.

## 5. Run the tests

```powershell
pwsh ./tests/run_tests.ps1
```

The script:

1. finds `lazbuild`: on `PATH`, in a usual Lazarus folder, or in `$env:LAZARUS_DIR`;
2. refreshes the version file and registers the packages;
3. builds `tests/RunTests.lpi` and runs the FPCUnit suite;
4. checks that every command and variable has a self-test case and a page on this site, so a new command
   fails the suite until both exist.

Most tests need no game client. `tests/LiveClientTests.pas` runs against a client if one is running and
logged in, and reports its tests as ignored otherwise. Anything else that needs a live client is checked
by hand, with the [self-test](https://github.com/ilpersi/EasyUOReforged/blob/main/tools/EUOSelfTest/README.md).

To run part of the suite, call the runner the script built:

```powershell
tests/RunTests.exe --list
tests/RunTests.exe --format=plain --suite=TEuoInterpreterTests
tests/RunTests.exe --format=plain --suite=TEuoInterpreterTests.TestVersionVarsAreDistinct
```

Without `--format=plain` the runner prints XML.

## Build in the Lazarus IDE

1. Register the packages first ([step 3](#3-register-the-packages)).
2. *Project → Open Project*, and pick `EasyUOReforged.lpi` (or `uo.lpi`, `EUOUpdtr.lpi`).
3. Pick the build mode: *Project → Project Options → Compiler Options*, the *Build modes* list at the top.
4. *Run → Build* (Shift+F9) builds it. *Run → Run* (F9) starts it under the debugger; use the `Default`
   mode for that.

The GUI has no form files (`.lfm`): `easyuo/main.pas` creates every control in code, so the form designer
has nothing to show.

## Run what you built

The programs need no other files next to them. The [`sql`](/commands/sql/) command uses Windows' own
SQLite, or a 64-bit `sqlite3.dll` placed next to `EasyUOReforged.exe` (see the [SQL guide](/guides/sql/)).

A build of your own is not code-signed either, so SmartScreen or an antivirus can warn about it for the
same reason it warns about a release: it reads and writes another program's memory. See
[SmartScreen and antivirus](/guide/install/#smartscreen-and-antivirus).

## Build the documentation site

This site lives in `website/` (Astro Starlight). You only need it to change these pages:

```powershell
cd website
npm ci
npm run dev
```

`npm run dev` serves the site at `http://localhost:4321/EasyUOReforged/` and reloads a page when you save
it. `npm run build` builds it into `website/dist/` and fails on a broken internal link, as the Docs
workflow does for every pull request. The pages are the Markdown files in `website/src/content/docs/`.

## What CI and releases do

- **`.github/workflows/ci.yml`** runs the steps above on a clean `windows-latest` machine for every push
  and pull request: the version file, the package links, the three Release builds, `run_tests.ps1`, and the
  EUOMigrate tests. It keeps the programs as a build artifact.
- **`.github/workflows/release.yml`** does the same for a `v*` tag, then publishes a GitHub release: a zip
  with the three programs, `LICENSE`, `NOTICE` and `README.md`, and SHA-256 checksums.
- **`.github/workflows/docs.yml`** builds this site for pull requests and publishes it from `main`.

If a build works in CI but not on your machine, compare your steps with `ci.yml`.

## When the build fails

| Message | Cause | Fix |
|---|---|---|
| `'lazbuild' is not recognized ...` | The Lazarus folder is not on `PATH`. | [Step 2](#2-make-lazbuild-reachable). |
| `Could not find lazbuild. Set $env:LAZARUS_DIR ...`, from `run_tests.ps1` | Lazarus is neither on `PATH` nor in a usual folder. | Set `$env:LAZARUS_DIR` to your Lazarus folder and run it again. |
| `Error: (lazbuild) Broken dependency: uoengine` | The packages are not registered. | [Step 3](#3-register-the-packages). |
| `Can't find unit ...` after switching between `Default` and `Release` with `-B` | Compiled units (`.ppu`) left over from the other mode. | Delete the compiled units (below) and build again. |
| `Can't create object file: ...EasyUOReforged.exe (error code: 5)` | The program is running, so Windows does not let the linker replace it. | Close it and build again. |
| A test crashes with an access violation right after a class gained fields | A test unit that reaches the class only through another unit was not recompiled. | Delete `tests\lib` and run the tests again. |
| The version ends in `nogit` | Git is not on `PATH`. | Install Git, or add it to `PATH`. |

To delete every compiled unit (all git-ignored), from the repository folder:

```powershell
Remove-Item -Recurse -Force lib, common\lib, uo\lib, parser\lib, tests\lib -ErrorAction SilentlyContinue
```
