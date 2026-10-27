---
title: Deriving values by hand
description: "The manual route for what EUOMigrate cannot decide: scanning with EUOUpdater, the scan-string format, values the scan cannot see, relocatable builds, writing signatures and the buff bar."
sidebar:
  order: 7
---

[EUOMigrate](/developers/euomigrate/) does most of a new build mechanically. This page covers what is left
over, and how the existing tables were made in the first place. You need it when:

- the EUOMigrate report flags a field it **cannot infer**, usually because the client implements that
  feature in a different form than the builds it knows;
- a value is **inherited** and something behaves wrong in testing (a layout EUOMigrate has no probe for);
- you want to check a value **independently**.

## Scanning a live client with EUOUpdater

EUOUpdater (`EUOUpdtr.exe`, in every release zip) searches a running client for byte patterns and prints
the address each one leads to. It is the original EasyUO tool for this job.

1. Build it (see [Build from source](/developers/building/)), or take it from a release:

   ```powershell
   lazbuild --build-mode=Release EUOUpdtr.lpi
   ```

2. Start the client and log in, then start `EUOUpdtr.exe`. It finds and selects the running client by
   itself.
3. Open the scan-string file for your kind of client (below) and paste its whole content into the
   **left** editor.
4. Press **Start**.
5. Read the results in the **right** editor: one `$XXXXXXXX  {NAME}` line per value, or `N/A` where no
   pattern matched.

| File in `tools/EUOUpdater/` | For |
|---|---|
| `EUO Updtr Strings 200 - 6061.txt` | Fixed-base clients from 2.0.0 to 6.0.6.1. |
| `EUO Updtr Strings 6062 and newer.txt` | Fixed-base clients from 6.0.6.2 on. Try this one first for a classic client. |
| `EUO Updtr Strings modern.txt` | Relocatable builds (`client_beta.exe`). |

If most lines come back `N/A`, the patterns do not fit this client: try the other file for fixed-base
clients, or derive new patterns (see [Writing signatures](#writing-signatures)).

The results are link-time addresses (see [Link-time addresses](/developers/client-tables/#link-time-addresses)),
ready for `uoclidata.pas`. EUOUpdater only finds `C_` and `E_` values: `B_` and `F_` values are covered
[below](#values-the-scan-cannot-see).

## The scan-string format

Each line of a strings file describes one pattern:

```text
B858020000394424117511C7051111111120030000A311111111 ; 11; +13; C ; +00; {CLIXRES}
```

| Part | Here | Meaning |
|---|---|---|
| Pattern | `B858…A311111111` | The bytes to find, in hex. |
| Joker | `11` | The wildcard byte: every `11` in the pattern matches any byte. It is chosen so it never collides with a byte that has to match. |
| Offset | `+13` | Where to look, counted in bytes from the start of the match. |
| Mode | `C` | `X`: the address *match + offset* itself (for code addresses such as `E_REDIR`). `C`: read the dword at *match + offset* (an address written in the instruction). `CB`: follow the `call` / `jmp` displacement at *match + offset* to its target. |
| Adjust | `+00` | Added to the result. |
| Name | `{CLIXRES}` | The value it finds, without its `C_` / `E_` prefix. |

In this line, the bytes `C705 11111111 20030000` are `mov dword [address], 800`: the client storing its
window width. Offset 13 lands on the wildcarded address, and mode `C` reads it, which gives `C_CLIXRES`.

A second line with the same name is a **fallback**, anchored in another function or in a newer build's
version of the same one. When several lines of a name match, EUOUpdater shows the result of the **last**
one, and the runtime scan in `uoclidata.pas` keeps the last one too: order the lines so that, on every
build, the right one comes last. The lines marked `6AD6CEB3` in `EUO Updtr Strings modern.txt` show how.

The same pattern in `uoclidata.pas`, as a runtime scan row:

```pascal
(Joker: $11; Unused: (0,0,0); AddOffset1: 13; Mode: 3; AddOffset2: 0; Expr: C_CLIXRES;
 Pattern: 'B858020000394424117511C7051111111120030000A311111111'),
```

`Mode` is `1` for `X`, `2` for `CB` and `3` for `C`. Mode `4` exists only in `uoclidata.pas`: it reads
two dwords from one match and stores their difference, for a `B_` value that is the distance between two
globals (`B_SKILLDIST`). `AddOffset2` is then the offset of the second dword.

## Scanning an exe that is not running

A **fixed-base** client always loads at `$400000`, so the bytes of its file sections are exactly what a
running process holds at the same addresses. You can rebuild the address space from the PE section
table (image base plus each section's virtual address and raw data) and run the same pattern search on
it, without ever starting an unfamiliar executable. This is how 7.0.99.1 was first supported.

EUOMigrate works this way for every build. If you need to do it by hand, any PE library does the parsing
(for example Python's `pefile`). The search itself is what `GetAddr` in `tools/EUOUpdater/main.pas` and
`SearchMem` in `common/access.pas` do.

It works for a relocatable build too. Its file holds link-time addresses, the form `uoclidata.pas`
stores; only the running process has them moved to where the client was actually loaded.

## Values the scan cannot see

The scan strings only find `C_` and `E_` values. `B_` (offsets) and `F_` (flags) are traditionally copied
forward from the nearest known build, on the assumption that object layouts change less often than
addresses. That is a reasonable starting point, not a verified fact. EUOMigrate's `probe` checks many of
them in a running client; for the rest:

- **`C_TARGETCNT`** is not covered by any pattern and is `$00000000` for every known version. Leave it at
  zero.
- **`B_SYSMSGSTR` / `F_SYSMSGDIRECT`** (where a system message keeps its text): run the
  `{SYSMSGSTR_CHECK}` line of `EUO Updtr Strings 6062 and newer.txt`. It is a diagnostic, not a value to
  paste:

  | It reads | Means |
  |---|---|
  | `$00000100` | Old layout: `B_SYSMSGSTR = $100`, `F_SYSMSGDIRECT = 0` (the text is behind a second pointer). |
  | `$00000800` | New layout: `B_SYSMSGSTR = $800`, `F_SYSMSGDIRECT = 1` (the text is right there). |
  | Anything else | The layout changed again: it needs a fresh look at the client's "add system message" code. |

  Every client checked so far (7.0.99.1, 7.0.108.0, 7.0.117.1) reads `$00000800`, so do not assume the old
  `$100` just because older tables have it.
- **Anything that behaves visibly wrong** in testing (a stat, the journal, system messages, a packet) is
  most likely a copied-forward `B_` or `F_` value. For example, on 7.0.108.0 `C_JOURNALPTR` was right but
  the journal entries it points at had changed shape; only watching real chat go through memory showed
  it. The `SysVarMS1` comments in `uoclidata.pas` tell that story.

If you cannot verify a value, **say so in a comment** next to it. A documented gap is better than a guess
that looks settled.

## Relocatable builds by hand

The scan strings for fixed-base clients do not match a relocatable build (different compiler, different
code), so its first table had to be derived by comparing code and checking in the running client. That
is how the first beta was done; EUOMigrate now automates most of it.

1. **Disassemble both executables** (Capstone works well) and pair their functions by what they
   reference: strings, imported functions, unusual constants (`0x3b2`, `0xd1b71759`, `0x80c`, ...).
2. **Find each global by the code that touches it**, then confirm it in the running client. Examples that
   worked:
   - the add-message routine (`mov reg,[HEAD]; ...; mov [HEAD],reg`) gave `C_SYSMSG`;
   - the journal add-entry routine (`cmp dword [node+$80C],0`) gave `C_JOURNALPTR`;
   - the skill-array setup loop, and the skills gump's three views, gave `C_SKILLLOCK`, `C_SKILLCAPS`,
     `C_SKILLSPOS` and `B_SKILLDIST`;
   - strings the client holds (the shard name, the character name) gave `C_SHARDPOS` and the status-gump
     layout.
3. **Walk the client's own lists** to learn object layouts: the object list from `C_CHARPTR`, the gump
   list from `C_CONTPOS`, the journal chain. Do not guess offsets from the old build.
4. **Be most careful with the event hook.** `E_REDIR` must be a 5-byte `call rel32` that runs every frame
   on the client's main thread, and `E_OLDDIR` its original target. On the beta it is the
   `call __alldiv` in the per-frame tick function; the fixed-base build hooks `call __allmul` in the same
   function. Both are found by the shared constants `0xd1b71759`, `0x1f4` and `0x4c`.
5. **Compare calling conventions** before wiring an event. On the beta, `CNetwork::Send` is a `thiscall`
   that pops its own argument (`F_SENDTHISCALL`), and the macro function reads its table from globals
   (`E_MACROTAB`). Events whose functions were inlined or changed shape (system message, extended message,
   tile info, drag, pathfind, item properties) have their own code in `uo/uoevents.pas`, selected by these
   `F_` and `E_` values. `tests/CstDbModernBuildTests.pas` checks every offset and jump in that code.
6. **Turn the results into signatures** (next section), so the next build of the same compiler needs no
   manual work.

## Writing signatures

A good signature finds its value in every build from the same compiler and nowhere else:

1. Take an instruction that uses the global (or the first dozen instructions of a function, for a code
   address).
2. Replace every address-like operand, every `rel32` branch target and every `ebp` / `esp` displacement
   with the joker byte.
3. Pick a joker byte that does not appear among the bytes that must match.
4. Keep the **smallest** window that matches **exactly once** in the code section and resolves to the
   address you derived.
5. Check it against the file **and** against the running process.

`tools/EUOUpdater/EUO Updtr Strings modern.txt` and `ScannerTable_Modern` were built this way, and so are
the signatures EUOMigrate writes for every migration.

## The buff bar

[`ScanBuffs`](/commands/scanbuffs/) needs two scanned addresses and four layout values per client
generation. A client supports the buff bar only when `B_BUFFVEC` and both addresses are non-zero; anything
else leaves `ScanBuffs` a no-op, so an unverified build never reads garbage.

| Value | Meaning | Relocatable (beta) | Fixed-base |
|---|---|---|---|
| `C_CLILOC` | The global holding the pointer to the cliloc manager (a `std::map<int,char*>`). | Scanned (`$7ED970` on the first beta). | Scanned (`$A01B9C` on `client.exe`). |
| `C_BUFFTIMERS` | The buff-timer `std::map` (key: timer id; the double at node `+$28`: seconds left). | Scanned; the global holds the head node. | Scanned; the address is the map itself. |
| `B_BUFFVEC` | Offset of the icon vector's begin pointer in the `BuffIcons Gump` (end pointer: the next dword). | `$15C` | `$D0` |
| `B_BUFFSIZE` | Size of one icon entry. | `$1B0` | `$1B0` |
| `B_STLHEAD` | Offset of the tree head pointer inside the two map objects. | `0` | `4` |
| `B_CLILOCKEY` | Offset of the key in a cliloc map node; the text pointer follows it. | `$10` | `$0C` |

To find them for a new generation: the client names its buff functions in its strings
(`CBuffIconsGump::AddIcon`, `RemoveIcon`, `GetToolTipString`, ...). Follow those strings to the functions
and read the offsets off the disassembly; the tooltip function shows the entry fields, the timer map and
the cliloc lookup in one place. Then check in a client with a few buffs on (Bless, Curse and Hiding are
enough), and run stage 9 of the self-test (below). EUOMigrate's `verify` and `probe` check all six values.

## House pieces

The pathfinder's walker reads the walls and floors of the player houses the client has drawn
([`path`](/commands/path/)). The map files don't have them. The two client generations keep them in
different ways, and a client with neither set of values simply reads no house piece:

| Value | Meaning | Relocatable (beta) | Fixed-base |
|---|---|---|---|
| `C_MULTILIST` | The global holding the first piece of the list of drawn house pieces. | Scanned (`$B5B70C` on `6AD6CEB3`). | `0` |
| `B_MULTINEXT` | The next pointer in that list. Each piece has the item layout: `B_POS`, `B_ITEMTYPE`. | `$9C` | `0` |
| `C_WORLDGRID` | The world grid: `B_GRIDSIZE` × `B_GRIDSIZE` chain heads, one per cell, holding every world object. | `0` | Scanned (`$760098` on `client.exe`). |
| `C_STATICVT` | The vtable of the grid's static objects. | `0` | Scanned (`$6C3D9C`). |
| `B_GRIDNEXT` | The next pointer in a cell's chain. | `0` | `$18` |
| `B_GRIDSIZE` | Cells per side; a cell is `(y mod size) × size + (x mod size)`. | `0` | `64` |
| `B_MULTIOWNER` | A static object's owner: non-zero for a house piece, 0 for one of the map's statics. | `0` | `$A4` |

How they were found:
- **On the beta:** the list has an add routine and a remove routine. The remove routine
  (`cmp [head],ecx; jne; mov eax,[ecx+9Ch]; mov [head],eax; …`) is the signature. Its `+$9C` and `+$A0`
  are literal bytes, so a build that moved them finds no list rather than a wrong one.
- **On `client.exe`:**
  - The grid comes from a cell lookup (`(y and 63) shl 6 + (x and 63)`, then the chain at `+$18`).
  - The vtable comes from the static object's constructor, which clears the owner at `+$A4`.
  - The routine that adds a house's components sets that owner.
- **Checked live** next to a player house near Minoc:
  - on `client.exe`, the static objects with an owner matched the beta's pieces of the same house exactly;
  - the ones without an owner were the map's statics.

The live test `TestPathLiveObjectsSeeTheCharacter` prints how many house pieces it read.

## Checking what you wrote

- **A unit test** in `tests/CstDbTests.pas` (fixed-base) or `tests/CstDbModernBuildTests.pas`
  (relocatable) that resolves the new build and checks the values you care about. See
  [Add a new client](/developers/adding-a-client/#7-add-a-unit-test).
- **The self-test** in the running client: [`tools/EUOSelfTest`](https://github.com/ilpersi/EasyUOReforged/blob/main/tools/EUOSelfTest/README.md)
  walks through every variable, event and command and writes a report. Run it on the new client and on a
  known one, and compare the two reports.
- **Live tests**: `tests/LiveClientTests.pas` runs against a client if one is running when you run the
  test suite.
