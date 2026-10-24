---
title: Install
description: What you need to run EasyUO Reforged, where to download it, and what to expect from SmartScreen and antivirus software.
sidebar:
  order: 1
---

EasyUO Reforged is a work-in-progress port of EasyUO to modern 64-bit Windows. Read the
[status and known limitations](/reforged/known-limitations/) before relying on it for anything important.

## What you need

- **64-bit Windows.**
- **A running Ultima Online client** (the classic `client.exe`). Start it and **log your character in
  before** launching EasyUO Reforged: the app looks for clients that are already running.
- **A supported client version.** Support is limited to a handful of builds so far. If yours isn't
  recognized, see [Add a new client](/developers/adding-a-client/).

## Download

1. Download `EasyUOReforged-<version>-win64.zip` from the
   [Releases](https://github.com/ilpersi/EasyUOReforged/releases) page.
2. Unzip it anywhere; there is no installer. Keep `uo.dll` in the same folder as `EasyUOReforged.exe`.
3. Run `EasyUOReforged.exe`.

`EUOUpdtr.exe` is also in the zip. You only need it to derive memory offsets for a new client version.

## SmartScreen and antivirus

EasyUO Reforged reads and writes the UO client's memory and patches small code hooks into it: the same
techniques a debugger or a game trainer uses. Because of that:

- **Windows SmartScreen** warns that the app is unrecognized, because the binaries are not code-signed.
  Choose *More info → Run anyway* if you trust the download.
- **Antivirus software** may flag the executable. This is expected for this kind of tool and is not, by
  itself, evidence that the file is malicious.

To check the download, compare it with the `.sha256` file published with each release (`SHA256SUMS.txt`
does the same for the files inside the zip):

```powershell
Get-FileHash EasyUOReforged-<version>-win64.zip -Algorithm SHA256
```

Every release is built by GitHub Actions from a tagged commit, in public; nothing is uploaded by hand. You
can also scan the file yourself (for example on VirusTotal) and report a false positive to your antivirus
vendor, or [build it from source](/developers/building/). See also
[SECURITY.md](https://github.com/ilpersi/EasyUOReforged/blob/main/SECURITY.md).

Next: [run your first script](/guide/first-script/).
