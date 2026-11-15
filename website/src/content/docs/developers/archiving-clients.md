---
title: Archive a client before patching
description: "EUOClientArchiver, a developer tool: keep each client build in its own ZIP before the patcher overwrites it, and get it back later to check memory addresses."
sidebar:
  order: 10
---

The UO patcher replaces `client.exe` and `client_beta.exe` in place. Once it has run, the old build is
gone, and with it the chance to compare its addresses with the new one: a `uoclidata.pas` milestone, an
EUOMigrate knowledge-base entry, a REA session. When `client.exe` went from 7.0.117.1 to 7.0.117.33, the
old build only survived as a temporary copy a REA session happened to leave behind.

EUOClientArchiver keeps a copy of each build before that happens. It is a developer tool: it is not in
the release zip.

## When to run it

- **Before you let the launcher patch the game**, every time. Running it again costs nothing: a build
  that is already in the archive folder is skipped.
- **The client may be running.** The tool only reads the client files. It never renames, moves, locks or
  changes anything in the client folder: the launcher and the patcher expect `client.exe` there.

## Build it

```powershell
lazbuild --build-mode=Release EUOClientArchiver.lpi
```

It needs only Lazarus, not the three packages of [Build from source](/developers/building/), and writes
`EUOClientArchiver.exe` next to the `.lpi`. CI builds it on every push so that it keeps compiling, but no
release contains it.

## The window

- **Client folder**: the folder that holds `client.exe`, for example
  `C:\Program Files (x86)\Electronic Arts\Ultima Online Classic`. Below it, one line per client:

  ```text
  client.exe       7.0.117.33  stamp 6AD994F1  3,616,768 bytes  archived
  client_beta.exe  7.0.117.31  stamp 6AD6CEB3  4,492,288 bytes  not archived yet
  ```

  The version, the PE stamp and the size identify the build (see
  [Identify the build](/developers/adding-a-client/#1-identify-the-build)). **archived** means the
  archive folder already holds this very build: an archive of the right name whose executable has the
  same SHA-256. A file without a version resource, or one that is not a program, gets a line that says so
  and is never archived. A folder that does not exist, or holds neither client, shows an error instead.
- **Archive folder**: any folder; it is created when you first archive into it. If it is inside a git
  repository, the tool asks before writing: client executables must never be committed, and `*.zip` files
  are not git-ignored in this repository. Both folders are remembered for the next start.
- **Note**: optional, one line, for the reason a build was kept, for example `patched from the launcher`
  or `noenc variant from shard X`. It goes into the `.txt` of every archive that click writes, and is not
  remembered.
- **Archive** archives every client it found. It is enabled when the client folder holds a client that
  can be archived and an archive folder is set. Each client takes about a second.
- **Log**: one line per client (archived, with the archive's path and the size before and after;
  already archived; or the error), then a summary such as `2 archived, 0 skipped, 0 failed`.
- **Archived builds**: every `.zip` in the archive folder, with the version, PE stamp, relocatable,
  archived date and note read from its `.txt`. A zip without one, made by hand or by another tool, shows
  its name only. Reading never changes an archive.

The client lines and the list are refreshed when either folder changes and after archiving.

## The names

For a client `<base>.exe` with version `<v>`, the archive is `<base>_<v>.zip`, and the executable inside
it is `<base>_<v>.exe`:

| In the client folder | Archive | Inside the archive |
|---|---|---|
| `client.exe`, 7.0.117.33 | `client_7.0.117.33.zip` | `client_7.0.117.33.exe`, `client_7.0.117.33.txt` |
| `client_beta.exe`, 7.0.117.31 | `client_beta_7.0.117.31.zip` | `client_beta_7.0.117.31.exe`, `client_beta_7.0.117.31.txt` |

- The version is read from inside the file, from its version resource, never from its name.
- The base name stays in because `client.exe` and `client_beta.exe` have both reported 7.0.117.1 while
  being different builds.
- The rename happens only inside the archive.

Only `client.exe` and `client_beta.exe` are archived, in any letter case. Other files, such as
`client_tc.exe` or a hand-renamed copy, are ignored. To archive another name, add it to `ClientNames` in
`tools/EUOClientArchiver/caarchive.pas`.

The archives are ordinary ZIP files (Deflate at its highest level), about 46 % of the original size, and
open in Explorer or any zip tool.

## A second run, or a name clash

- **The archive exists and holds the same bytes** (the same SHA-256): the client is skipped, the log says
  `already archived`, and the archive is left as it is.
- **It holds other bytes for the same version**, such as a rebuild that kept the version number: the build
  goes to `<base>_<v>_<STAMP>.zip`, holding `<base>_<v>_<STAMP>.exe`. `<STAMP>` is the PE stamp as 8 hex
  digits, the field `uoclidata.pas` identifies relocatable builds by. The log says so.
- **That name is taken by other bytes too**: the client fails with an error that asks you to look.

Nothing is ever overwritten. Each archive is first written as `<name>.zip.partial`, read back and compared
with the client (size and SHA-256), and only then given its name. A `.partial` left by a crash is
replaced on the next run.

## The .txt file

Each archive holds a `.txt` beside the executable, one `key  value` per line:

```text
original name    client.exe
original folder  D:\Program Files (x86)\Electronic Arts\Ultima Online Classic
version          7.0.117.33
PE stamp         6AD994F1 (2026-10-22 04:45:37 UTC)
relocatable      False
size             3616768
sha256           6eefcdc345fcfd54da00d63045b5b753d51ecd8b90e30c414fcf14a6f5929b80
last modified    2026-10-22 05:47:46 UTC
archived         2026-11-15 10:12:03 UTC
note             patched from the launcher
```

The PE stamp is followed by the time it encodes. The `sha256` is the executable's, and the times are in
UTC. The `note` line is there only when a note was given. The list of archived builds reads these keys
back.

The zip also dates the executable with its last-write time, but ZIP keeps only local time, to two
seconds, and Windows converts it with today's daylight-saving offset: a build from the summer archived in
the winter shows an hour off in Explorer. The `last modified` line is the exact time.

## Using an archived build later

Unzip it first. Then:

- **Check it.** This must print the `sha256` line of its `.txt`:

  ```powershell
  (Get-FileHash .\client_7.0.117.33.exe -Algorithm SHA256).Hash.ToLower()
  ```

- **Read its addresses without running it.** Point [EUOMigrate](/developers/euomigrate/) or a REA session
  at the extracted file. Neither needs it to be called `client.exe`:

  ```powershell
  python tools/EUOMigrate/euomigrate.py migrate "D:\UO archive\client_7.0.117.33.exe"
  ```

- **Run it.** Copy a whole client install to a folder of its own, put the extracted file in it as
  `client.exe` (or `client_beta.exe`), and start that file directly. Do not start it through the
  launcher, which would patch it back to the current build, and never put it back into your real install.
