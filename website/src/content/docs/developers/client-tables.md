---
title: How client support works
description: "What EasyUO Reforged needs to know about a client build, where it is kept in uoclidata.pas, and how a build gets its values when it attaches."
sidebar:
  order: 3
---

EasyUO Reforged drives the UO client by reading and writing its memory and by calling, or hooking, its
code. To do that it needs to know where things are in **that exact build** of the client: where it keeps
your character, where its send-packet function starts, how an item object is laid out. Those facts change
with almost every new client build.

All of them live in one file, [`uo/uoclidata.pas`](https://github.com/ilpersi/EasyUOReforged/blob/main/uo/uoclidata.pas).
Nothing else in the code holds an address: every other unit asks the `TCstDB` object (`Cst.CHARPTR`,
`Cst.ESENDPACKET`, ...). **Supporting a new client means adding its values to this file**, and nothing else.

## The four kinds of values

Each value has a name with a prefix that says what kind of value it is. There are 114 of them (25 `C_`,
25 `E_`, 51 `B_`, 13 `F_`), declared with a comment each in the `TConstantNames` list at the top of the
file.

| Prefix | What it is | Example | Found by |
|---|---|---|---|
| `C_` | The address of a **global variable** in the client. | `C_CHARPTR`: the global holding the pointer to your character. | Scan strings, EUOMigrate |
| `E_` | The address of **client code**: a function EasyUO calls, or the instruction its hook replaces. | `E_SENDPACKET`: the client's send-packet function. `E_REDIR`: the per-frame `call` the event hook takes over. | Scan strings, EUOMigrate |
| `B_` | An **offset**: where a field sits inside an object, or the distance between two globals. | `B_ITEMID`: where an object keeps its id. `B_SKILLDIST`: from the base skill values to the values with bonuses. | Copied from the previous build, EUOMigrate `probe`, reading the code |
| `F_` | A **flag**: which form of a feature this build uses. | `F_SENDTHISCALL`: the send function is a `thiscall`. `F_JOURNALDIRECT`: journal entries hold their text inline. | Reading the code, EUOMigrate |

### Zero means "off"

A value of `0` switches the feature that needs it off. An event whose `E_` address is `0` refuses to run,
and a variable whose `C_` address is `0` has nothing to read. That is deliberate: a **wrong** value is far
worse than a missing one. A wrong `C_` address reads garbage; a wrong `E_` address makes EasyUO patch
machine code into the wrong place of a running client, which crashes it.

So the rule for every value you add is: **if you have not verified it, leave it at `0`.** EUOMigrate
follows that rule too.

## Two kinds of client builds

| | Fixed-base | Relocatable ("modern") |
|---|---|---|
| Loads at | Always `$400000`. | Anywhere the loader likes (ASLR, the PE flag `DYNAMIC_BASE`), for example `$D10000`. |
| Examples | Every classic client up to `client.exe` 7.0.117.1 (PE stamp `6A8E6F9D`). | `client_beta.exe`: 7.0.117.1 (stamp `6AC94360`), then 7.0.117.31 (stamp `6AD6CEB3`). |
| Told apart by | The **version number**. | The **PE time stamp**: two builds can share a version number. |
| Kept in | A milestone (`SysVarMS…` list) and a `VersionIndex` row. | A `ModernBuilds` entry: a shared `Layout` list and its own `Addrs` list. |
| An unknown build gets | The nearest **older** milestone's values, then the runtime scan. | **Zero** for every address, then the runtime scan. |
| Runtime scan table | `ScannerTable_Post6062` (`ScannerTable_Pre6062` is empty). | `ScannerTable_Modern`. |

The relocatable builds come from a newer compiler. Their code, their object layouts and even how some
functions are called differ from a fixed-base build with the **same version number**, so nothing from the
fixed-base tables applies to them.

## What happens when EasyUO attaches

`TCstDB.Update` works out the values for the attached client in this order. Later steps overwrite earlier
ones.

1. **Read the version number** from the client's version resource, for example `7.0.108.0`. This is
   also what [`#CliVer`](/variables/cliver/) shows.
2. **Pick a milestone.** If `VersionIndex` lists the exact version, use its milestone. Otherwise use the
   nearest milestone that is **older** than the version. A version older than every milestone is not
   supported.
3. **Apply the milestones cumulatively**, from the oldest up to the chosen one. Each milestone lists only
   the values that changed at that point in the client's history, so the result is the full set of values
   for that version.
4. **For a relocatable build**, set every `C_` and `E_` value back to zero, apply the shared modern
   layout (`B_`, `F_`), then apply the `Addrs` list of the `ModernBuilds` entry whose PE stamp matches, if
   there is one. That list is applied last, so a `B_` value in it overrides the shared layout for that build
   only. `SysVarModernAddrs` does this for `B_SKILLDIST`, a distance between two globals that the linker
   changed from one beta to the next.
5. **Run the runtime scan**: search the live client's code for the byte patterns in the scanner table and
   overwrite every value a pattern finds.

### What that means for a new build

- **A new fixed-base build** (say 7.0.120.0) attaches without any change. It gets 7.0.117.1's values, and
  the runtime scan replaces the addresses it can find. Anything the scan does not cover keeps the old
  build's value, which may be wrong for the new build.
- **A new relocatable build** also attaches, but starts with every address at zero. Only what
  `ScannerTable_Modern` finds is filled in, and every feature the scan misses stays off. Even a build
  whose addresses the scan all finds can need an entry: the beta 7.0.117.31 has one only for six `B_`
  values that the shared layout has wrong for it.

Either way, adding the build's own values to `uoclidata.pas` is what makes it reliable.

### Link-time addresses

Every `C_` and `E_` value is stored as a **link-time address**: the address it would have if the exe were
loaded at `$400000`. The getters add `ImageDelta` (the real load address minus `$400000`) when they read a
value. For a fixed-base build that delta is `0`. For a relocatable one it changes on every start, and one
table still fits every load address.

For example, the first beta keeps its base skill values at link-time address `$7EEB60`. Loaded at
`$E10000`, that array is at `$7EEB60 + ($E10000 - $400000) = $11FEB60`.

Tools that print addresses for `uoclidata.pas` (EUOUpdater, EUOMigrate) always print link-time
addresses, so you can paste them as they are.

## Where things are in uoclidata.pas

| Name | What it holds |
|---|---|
| `TConstantNames` | Every value name, with a comment on what it means. |
| `SysVarMS0` … `SysVarMS140` | The milestone lists, **newest first**: `SysVarMS0` is client 7.0.117.1. |
| `Milestones` | One row per milestone list, with its sort key (`NormVer`, for example `'007.000.108.000'`). |
| `VersionIndex` | One row per known version string, pointing at its milestone. |
| `SysVarModernLayout` | The `B_` and `F_` values shared by all relocatable builds. |
| `SysVarModernAddrs`, `ModernBuilds` | The addresses of one relocatable build (plus any `B_` value of its own), and the list that links a PE stamp to them. |
| `ScannerTable_Post6062`, `ScannerTable_Modern` | The runtime scan patterns. |
| `TCstDB.Update`, `ApplyModernBuild`, `ScanMemory` | The code that puts it all together, as described above. |

The file's own header comments explain each part in more detail; read them before you edit it.

## The runtime scan

A scan pattern finds a value by the **shape of the code** that uses it: the instructions around a global
stay the same from one build to the next while the address in them moves. Patterns are written with
wildcards in place of the addresses, so one pattern keeps working for every build from the same compiler.

The patterns exist twice, in the same format:

- in `uoclidata.pas`, as the `ScannerTable_…` rows the app scans with on every attach, and
- in `tools/EUOUpdater/EUO Updtr Strings *.txt`, the files the EUOUpdater tool scans with.

When a new build breaks a pattern, it needs a new one in both places. EUOMigrate writes them for you
(see [Using EUOMigrate](/developers/euomigrate/)); [Deriving values by hand](/developers/manual-derivation/#the-scan-string-format)
explains the format.

Next: [add a new client](/developers/adding-a-client/).
