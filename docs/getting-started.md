# Getting started

A first-run walkthrough for **using** EasyUO Reforged. If you want to build it or
work on it, see the README's *Building* section and
[`architecture.md`](architecture.md) instead.

> EasyUO Reforged is a work-in-progress port. Read the README's *Status* and
> *Known limitations* sections before relying on it for anything important.

## What you need

- **64-bit Windows.**
- **A running Ultima Online client** (the classic `client.exe`). Start it and
  **log your character in before** launching EasyUO Reforged — the app scans for
  clients that are already running.
- A supported client version. Support is limited to a handful of builds so far
  (see the README); if yours isn't recognized, see
  [`adding-client-support.md`](adding-client-support.md).

## Install

1. Download `EasyUOReforged-<version>-win64.zip` from the
   [Releases](https://github.com/ilpersi/EasyUOReforged/releases) page.
2. Unzip it anywhere (no installer). Keep `uo.dll` in the same folder as
   `EasyUOReforged.exe`.
3. First launch: **SmartScreen** will say the app is unrecognized (the binaries
   aren't code-signed). Choose *More info -> Run anyway* if you trust the
   download. Your antivirus may also flag it — this is expected for a tool that
   reads and writes another process's memory. See the README's
   *Antivirus & SmartScreen* section, and verify the download against the
   published checksums.

`EUOUpdtr.exe` is also in the zip; you only need it if you're deriving memory
offsets for a new client version.

## The window

- **Tabs** — one open script per tab. `File -> New` / `Open`, or drag a `.euo`
  file onto the window. The last session's tabs are remembered.
- **Editor** (left/centre) — a syntax-highlighted code editor with line numbers.
- **Variable inspector** (right) — a tree of every built-in `#IDENTIFIER`
  grouped by category, plus your script's own `%variables`, with values that
  refresh a few times a second while a script runs.
- **Title bar** shows the version (`YY.MM.DD.<git commit>`); `Help -> About`
  shows it too.

## Run your first script

1. Make sure the UO client is running and logged in.
2. Paste a script into a tab. A minimal one:

   ```
   ; announce where the character is, then stop
   display OK Char is at #CharPosX , #SPC , #CharPosY
   halt
   ```

3. Press **F9** (`Control -> Start`), or the Play button on the toolbar.
4. `Control -> Pause` (F-key varies), `Stop`, and `Stop All` (stops every tab's
   script) control execution. The editor is read-only while a script runs.

If you get *"No supported UO client found!"*, the client either isn't running,
isn't logged in, or is a version this build doesn't recognize yet.

## Debugging

EasyUO Reforged adds IDE-style debugging on top of the classic controls
(shortcuts follow Delphi/Lazarus conventions):

| Key | Action |
|---|---|
| **F5** | Toggle breakpoint on the current line |
| **F4** | Run to cursor |
| **F7 / F8 / F6** | Step Into / Over / Out |
| `Control -> Breakpoint Condition...` | Conditional breakpoint — `<var> <op> <value>`, e.g. `%i > 10` (simple comparisons only) |
| `Control -> Clear All Breakpoints` | Remove them all |
| `Control -> Show Call Stack` | Live panel of nested `GOSUB` frames |

While paused, the variable inspector shows the live state, and
`Tools -> VarDump` dumps every variable to a text window you can copy.

## Multiple clients

- `Tools -> New Client` launches another UO client (you'll be asked for
  `client.exe` the first time).
- `Tools -> Swap To Next Client` cycles which running client the active script
  drives.

## Other things worth knowing

- **`Tools -> Don't Move Cursor`** is on by default: click/target commands work
  without warping your real mouse pointer. Turn it off if a script needs the
  real cursor moved.
- **`Tools -> Manage VarList`** edits the identifier list shown in the inspector.
- The editor has basic **Ctrl+Space autocomplete** for script keywords, built-in
  `#variables`, and your own variables, plus **Find/Replace** (Ctrl+F).
- **Ctrl+Shift+R / Ctrl+Shift+P** record and play back a *keystroke* macro in the
  editor (a text-editing convenience, not a game-action recorder).

## Learning the language

The scripting language itself — every command, every `#variable`, expression
syntax — is documented on the **EasyUO wiki**: <http://wiki.easyuo.com>. The
[easyuo.com](http://www.easyuo.com) forums are the place for script help and
existing scripts.

This port aims to run existing `.euo` scripts unchanged. `#EUOVer` still returns
the original value (`1_50_00`) for compatibility; `#ReforgedVer` is this port's
own build version. Where behaviour intentionally differs, or a feature is
incomplete, it's listed under the README's *Known limitations* and *Additions
beyond the original*.

## Getting help / reporting bugs

Open a GitHub issue with the **Bug report** template. Include a **minimal** script
(under ~20 lines) that reproduces the problem on a fresh run, and the output of
[`report-diagnostics.euo`](report-diagnostics.euo) run with your client attached.
