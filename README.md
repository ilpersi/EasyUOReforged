# EasyUO Reforged

[![Documentation](https://img.shields.io/badge/Documentation-read%20online-1f6feb?style=for-the-badge)](https://ilpersi.github.io/EasyUOReforged/)

A port of **EasyUO**, the scripting tool that automates the *Ultima Online* client, from Delphi 7 to
[Lazarus](https://www.lazarus-ide.org/) / Free Pascal, as a native 64-bit Windows application. It is
derived from the original Delphi 7 source by Cheffe; it is not the original project.

The scripting language is unchanged: existing `.euo` scripts are meant to run as they are, quirks
included. `#EUOVer` still returns `1_50_00`.

## Documentation

Everything is on the documentation site: **<https://ilpersi.github.io/EasyUOReforged/>**

| | |
|---|---|
| [Get started](https://ilpersi.github.io/EasyUOReforged/guide/install/) | Install, a first script, the editor and its debugger. |
| [Commands](https://ilpersi.github.io/EasyUOReforged/commands/) and [variables](https://ilpersi.github.io/EasyUOReforged/variables/) | Every command and `#variable`, searchable. |
| [uo.dll API](https://ilpersi.github.io/EasyUOReforged/dll/) | The client engine as a DLL, for other programs. |
| [What's new in Reforged](https://ilpersi.github.io/EasyUOReforged/reforged/whats-new/) | What this port adds: `SQL`, `ScanBuffs`, UOP map files, breakpoints and a call stack in the editor. |
| [Known limitations](https://ilpersi.github.io/EasyUOReforged/reforged/known-limitations/) | What is verified, what is not, and which clients are supported. |
| [Developer guide](https://ilpersi.github.io/EasyUOReforged/developers/) | Building from source, adding a new client, EUOMigrate. |

## Status

A working, actively tested port, **not a finished release**. It is based on the last public EasyUO
source, which its author described as deprecated. The interpreter and the client tables have automated
tests; anything that needs a running client is checked by hand, as far as testing has reached. Read the
[known limitations](https://ilpersi.github.io/EasyUOReforged/reforged/known-limitations/) before relying
on it.

## Download and run

1. Download `EasyUOReforged-<version>-win64.zip` from
   [Releases](https://github.com/ilpersi/EasyUOReforged/releases).
2. Unzip it anywhere and run `EasyUOReforged.exe`; there is no installer. Keep `uo.dll` next to it.
3. Start the UO client and log in first: EasyUO Reforged finds running clients by itself.

The binaries are not code-signed, and the program reads and writes the client's memory, so SmartScreen
and antivirus software may warn about it. Every release is built in public by GitHub Actions and ships
with SHA-256 checksums. See
[SmartScreen and antivirus](https://ilpersi.github.io/EasyUOReforged/guide/install/#smartscreen-and-antivirus)
and [`SECURITY.md`](SECURITY.md).

## Building

With Lazarus 3.6 or newer:

```
lazbuild --add-package-link common/uocommon.lpk uo/uoengine.lpk parser/euoparser.lpk
lazbuild --build-mode=Release uo.lpi
lazbuild --build-mode=Release EasyUOReforged.lpi
lazbuild --build-mode=Release EUOUpdtr.lpi
pwsh ./tests/run_tests.ps1
```

Step by step, with the Lazarus IDE and the usual build errors:
[Build from source](https://ilpersi.github.io/EasyUOReforged/developers/building/).

## Bugs and contributions

- **Bugs:** open an issue with the **Bug report** template. Include a minimal script that reproduces the
  problem and the output of [`docs/report-diagnostics.euo`](docs/report-diagnostics.euo); see
  [Reporting a bug](https://ilpersi.github.io/EasyUOReforged/guide/troubleshooting/#reporting-a-bug).
- **Code:** see [`CONTRIBUTING.md`](CONTRIBUTING.md) and the
  [developer guide](https://ilpersi.github.io/EasyUOReforged/developers/).
- **Script help and community:** <http://www.easyuo.com>.

## License and disclaimer

BSD 2-Clause, the same license as the original (see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE)). The
documentation text that comes from the old EasyUO wiki stays under the GFDL 1.2.

EasyUO Reforged is an independent community port, not affiliated with the original author and not an
official replacement for EasyUO. It comes with no warranty of any kind. If you rely on EasyUO for anything
important, keep the original next to it until you have checked that the scripts and features you need
work here.
