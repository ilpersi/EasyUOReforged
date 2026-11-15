# Gumps: what the client keeps for each open window

Status: analysis done on 2026-11-02 by static analysis of three client builds and by reading two running
clients, then extended on 2026-11-07 with a static check of eleven old clients (§10). On 2026-11-15 the
features were built on it (`ScanGumps`, `exevent GumpReply`, the click hook) and checked live: §12. It answers "what does a gump hold besides its name", for `GetShopInfo`, `FindGumpByName` and
`GetCont` in `uo/uocommands.pas`, and is the groundwork for a command that lists the open gumps.

All offsets are offsets **inside a gump object**. No new address is involved anywhere.

## 1. Sources

| Build | File | Identity | How it was read |
|---|---|---|---|
| 2013 | `client_tc.exe` | 7.0.29.97, fixed base | static (capstone) |
| 7.0.117.1 | `client.exe` (before the 2026-11-02 patch) | stamp `6A8E6F9D`, SHA-256 `e5a225d9…bb188a0f`, fixed base | static (REA with Ghidra 12.1.4, capstone), live |
| 7.0.117.33 | `client.exe` (after the patch) | stamp `6AD994F1`, SHA-256 `6eefcdc3…f5929b80`, fixed base | static (capstone), live |
| beta 7.0.117.31 | `client_beta.exe` | stamp `6AD6CEB3`, relocatable (seen loaded at `$7B0000`) | static (capstone), live |

All the files are in `D:\Program Files (x86)\Electronic Arts\Ultima Online Classic\`. The old 7.0.117.1
exe only survives as a REA temp copy (§9). The eleven old clients of §10 are in `D:\Tmp\UO Clients\`.

The live reads used `ReadProcessMemory` only (python `ctypes`, `PROCESS_VM_READ`). Nothing was written to the
clients and no input was sent. The shard was TestReforged (an emulator shard).

"Static" means: found in the code of that build. "Live" means: read in the running client and found to hold
the expected values.

## 2. The gump list

- `C_CONTPOS` heads the list, and `+$58` (`B_CONTNEXT`) is the next gump. This is the list `GetCont`,
  `GetShopInfo` and `FindGumpByName` walk.
- **Only top-level windows are in that list.** Every gump is a node in a tree. Buttons, text lines, scrollbars
  and so on hang under their window and never show up in the walk.
- **The list runs front to back.** Bringing a gump to the front (client function `0x4EA450` on 7.0.117.1)
  unlinks it and puts it at the head. A new top-level gump is also linked in at the head (`0x4EA670`).
- The client keeps a second global with the **last** top-level gump (`$8DD438` on 7.0.117.1). It is listed
  here only to explain the code; nothing needs it.
- The client's own lookup of a server gump by type id (`0x4EB680` on 7.0.117.1) walks the same list.

### Tree links

Same offsets in all four builds. They are taken from the client's add-child code, found in each build with
the same instruction shape, and checked live on every window and child on 7.0.117.33 and the beta.

| Offset | Meaning |
|---|---|
| `+$58` | next sibling (`B_CONTNEXT`) |
| `+$5C` | previous sibling |
| `+$60` | first child |
| `+$64` | parent (0 for a top-level window) |
| `+$68` | last child |

## 3. Fields every gump has (base class `CGump`)

Base constructor: `0x4EA9F0` (7.0.117.1), `0x4EAC10` (7.0.117.33: the same function, moved by +$220 like
the code around it), `0x54D290` (beta: one of two functions that store `"normal gump"` and `$FEEDBEEF`). Every gump class calls
it, then overwrites the fields it cares about.

| Field | 2013 tc | 7.0.117.1 / .33 | beta | Evidence | Read today by |
|---|---|---|---|---|---|
| vtable: the C++ class | `+$00` | `+$00` | `+$00` | static + live | `#ContKind` (its low word) |
| marker `$FEEDBEEF` | `+$04` | `+$04` | `+$04` | static + live, every gump | — |
| name pointer (`"container gump"`, …) | `+$08` | `+$08` | `+$08` | static + live | `#ContName`, `GetShopInfo`, `FindGumpByName` |
| full width (0 on some gumps) | ? | `+$20` | ? | static + live | — |
| width / height | ? | `+$24` / `+$28` | `+$24` / `+$28` | static + live | `#ContSizeX/Y` (`B_CONTSIZEX`) |
| width / height while minimized | ? | `+$2C` / `+$30` | `+$2C` / `+$30` | static + live | — |
| X / Y | ? | `+$34` / `+$38` | `+$34` / `+$38` | static + live | `#ContPosX/Y` (`B_CONTX`) |
| linked object: container item, vendor, mobile | ? | `+$4C` | `+$4C` | static + live | `#ContID`, `#ContType` (`B_CONTITEM`) |
| tree links | `+$58..+$68` | `+$58..+$68` | `+$58..+$68` | static + live | `+$58` only |
| **gump art ID** (graphic number, -1 when none) | `+$6C` | `+$6C` | **`+$70`** | static + live | — |
| unknown small number, different per gump | — | — | `+$6C` | live | — |
| **minimized flag** | ? | `+$7C` | **`+$80`** | static (7.0.117.1) + live | — |
| cliloc on spell icon gumps; -123 by default, -1 on the buff bar | `+$B0` | `+$B0` | **`+$B8`** | static + live | — |

"?" means not checked here: `B_CONTX`, `B_CONTSIZEX` and `B_CONTITEM` already come from the tables there.
§10 has the tc values, and the older builds.

How the less obvious ones were identified:

- **Art ID.** The container constructor stores its gump graphic there and picks the open sound from it. The
  shop (`$870`), bill (`$873` buy / `$871` sell), status (`$2A6C`), target status (`$804`) and buff bar
  (`$4EC`) constructors each store a constant there. The base constructor sets -1.
  - Live, the same numbers on both clients: backpack `$3C`, paperdoll `$7D0`, skills `$1F40`, status
    `$2A6C`, buff bar `$4EC`, text gump `$820`, spellbook `$8AC`, item properties `$243A`.
  - Spell icon gumps hold their icon graphic (`$8D0`, `$8DA`).
- **Minimized flag and minimized size.** The bring-to-front code takes the size from `+$2C/+$30` when `+$7C`
  is set and from `+$24/+$28` otherwise.
  - Live: the minimized item-properties gump reads 1, and its current size (56×60) equals the minimized size.
    On the beta the flag is at `+$80`.
- **Linked object.** Container: the container item. Paperdoll and status gump: the mobile. Shop gump: the
  vendor.
  - Live: backpack → `$40000003`, paperdoll and status → serial 1, spellbook → the spellbook item
    `$400042C6`.
- **`+$B0` / `+$B8`.** The spell icons read 3002027 and 3002037, cliloc numbers, probably the spell names
  for the tooltip. Its meaning on other gumps is unknown.

Not identified: `+$0C..+$1C`, `+$3C..+$48` (start at -1), `+$54` (a drawing buffer array), `+$70`/`+$78`
(7.0.117.x), `+$84` (starts at 1), `+$88..+$AC`, `+$B8` (7.0.117.x).

### `#ContKind` is the class, and it changes with every build

`#ContKind` is the low word of the vtable address (`RWV(Read,Buf,@ContKind,2)` in `GetCont`). It is unique
per class but tied to the build. Each class's vtable was found through its RTTI (MSVC Complete Object
Locator → type descriptor `.?AV<Class>@@`): 140 gump classes in 7.0.117.1.

| Class | Name at +$08 | 7.0.117.1 and .33 | beta |
|---|---|---|---|
| `GenericGump` | `generic gump` | `$FD6C` | `$4894` |
| `CContainerGump` | `container gump` | `$E694` | `$DBF8` |
| `CStatusGump` | `status gump` | `$9BE4` | `$9F8C` |
| `CPaperdollGump` | `paperdoll gump` | `$944C` | `$A234` |
| `CBuffIconsGump` | `BuffIcons Gump` | `$79D4` | `$4AD0` |
| `CGumpMenuBar` (beta: `…OpenGL`) | `menubar` | `$993C` | `$B8F0` |
| `CSkillGump` | `skill gump` | `$D2C4` | `$E6E0` |
| `CSpellIconGump` | `spellicon gump` | `$6D3C` | `$3464` |
| `CSpellBookGump` | `spellbook gump` | `$6504` | `$3F84` |
| `CNewItemPropGump` | `new item Prop gump` | `$218C` | `$FFFC` |
| `CMapGump` (beta: `…OpenGL`) | `map gump` | `$7F04` | `$2E1C` |
| `GameAreaEdgeGump` (beta: `…OpenGL`) | `GameAreaEdgeGump` | `$823C` | `$30D8` |
| `CInputGump` | `normal gump` | `$464C` | `$1A60` |
| `CShopGump` | `shop gump` | `$C064` | not read |
| `CBillGump` | `bill gump` | `$C2F4` | not read |
| `CTargetStatusGump` | `target status gump` | `$DDF4` | not read |

The vtables did not move in the 7.0.117.1 → .33 patch, because its data section stayed in place. A bigger
update moves them. The beta also has new classes: OpenGL variants, and `CPerformanceGumpOpenGL`.

The **class name** itself can be read without any address: vtable − 4 → Complete Object Locator, then +$0C →
type descriptor, then +$08 → the `.?AV…@@` name. EUOMigrate's probe already does this (`cls_of_object`).

## 4. Fields of particular gump types (7.0.117.1 unless noted)

### Generic gump: gumps sent by the server

Constructor `0x4DB6F0` (size `$F4`). The layout parser is `0x4D9CD0`, and the packet handler calls it at
`0x46505D` / `0x46543C`.

| Field | 2013 tc | 7.0.117.x | beta | Evidence |
|---|---|---|---|---|
| **serial** | `+$D8` | `+$E0` | `+$178` | the `$B1` reply packet (§10); constructor argument order; live on 7.0.117.x and the beta |
| **type ID** | `+$DC` | `+$E4` | `+$17C` | the `$B1` reply packet (§10); the client's find-by-type-id compares it; live on 7.0.117.x and the beta |
| X / Y it opened at | ? | `+$CC` / `+$D0` | `+$164` / `+$168` | the parser copies them to `+$34/+$38`; live |
| flags (1 by default) | ? | `+$BC`, `+$D4`, `+$D8`, `+$DC` | `+$154`, `+$16C`, `+$170`, `+$174` | constructor; live |
| unknown | ? | `+$C4` / `+$C8` | `+$15C` / `+$160` | live: 397 / 212 on one gump |
| children | | `HTMLBox` objects, one per text/HTML element | | live: 20 on one gump |

- The serial changes every time a gump opens. The type ID is the same every time the same gump opens.
  - Live: type ID `$9E26D92D` read with serial `$B`, then `$E` (7.0.117.x), then `$10` (beta). Type ID
    `$9ECCBC5C` read on both clients.
  - On emulator shards the type ID is a hash of the gump's class.
- When a new gump arrives with certain type IDs (`$2410`, `$2432`, `$2448`, `$245F..$2462`, `$F3ECC`,
  `$F3ECD`), the client first closes any open gump with the same type ID (`0x4653A8`).
- Server gumps have no single background graphic: art ID reads -1.

### Shop gump

Constructor `0x53ADE0`.

| Offset | Meaning |
|---|---|
| `+$4C` | the vendor. The vendor keeps the gump pointer back at its `+$B8` / `+$BC`. |
| `+$BC..+$C8` | rectangle of the item list (`$1E,$3A,$E4,$EC`) |
| `+$CC` | current stock line (`B_SHOPCURRENT`) |
| `+$D0` | first stock line |
| `+$FC` | scrollbar child |
| `+$100` | the bill gump created with it |
| `+$11C..+$140` | ten child gumps, one per visible line |

The stock lines are item-like objects; their layout is already in `GetShopInfo`.

### Bill gump

Constructor `0x53A9D0`. `+$CC` = its shop gump. Art `$873` (buy) or `$871` (sell).

### Status gump

Constructor `0x5249F0`.

- `+$4C` = the mobile.
- `+$7C` = 1 for the compact status bar.
- Stat words from `+$E2` to `+$107`. Current and maximum hit points are at `+$EA` / `+$EC`; that is
  `B_CONTNEXT + $92`, which `GetCont`'s `ContHP` reads.
- A matching second block at `+$15E..+$183` looks like the previous values.
- The other words are not identified.

### Other types

| Type | Constructor | Fields |
|---|---|---|
| Paperdoll | `0x5206A0` | `+$4C` = the mobile |
| Target status | `0x545430` | `+$C0..+$FC`; the enemy's hit points at `+$C4` (`B_ENEMYHPVAL`) |
| BuffIcons gump | `0x4A29F0` | `+$C4` orientation; `+$D0` icon vector (`B_BUFFVEC`; `+$15C` on the beta); `+$150` minimum minor-axis size |
| Container | `0x4C91E0` | `+$4C` = the item, whose `+ B_ITEMID + B_GUMPPTR` (`+$EC`) points back at the gump |

The type-specific offsets **moved on the beta**: about +$8C to +$98. For example `B_SHOPCURRENT` `$CC` →
`$15C`, `B_BUFFVEC` `$D0` → `$15C`, `B_BILLFIRST` `$DC` → `$170`.

## 5. What stays the same across builds

**No offset is guaranteed.** The art ID went `+$6C` → `+$70` and the generic type ID `+$E4` → `+$17C`
between 7.0.117.x and the beta. Each field a script can read needs its own row in `uo/uoclidata.pas`,
like the existing `B_*` offsets.

What can be relied on is the **value**, for fields whose content comes from game data or from the server:

| Value | Why it stays the same |
|---|---|
| art ID | graphic number in the gump art files |
| generic serial / type ID | sent by the server |
| linked object serial | an item or mobile serial |
| minimized flag | on/off |
| tree links | links in the client's own tree |
| position / size | pixels |
| name | the client's internal names; unchanged from 2013 to the beta, and `FindGumpByName` already depends on them |

Not reliable as values: `#ContKind` (changes per build), raw pointers, the unidentified fields.

## 6. What the existing table values already reach

Without new rows in `uoclidata.pas`:

- the number of open top-level gumps and their front-to-back order (`C_CONTPOS` + `B_CONTNEXT`);
- "is this container open": item `+ B_ITEMID + B_GUMPPTR` points at its container gump. Not verified:
  whether the client clears it on close;
- more about the linked object: amount (`B_ITEMSTACK`), position and kind (`B_POS`), notoriety
  (`B_FINDREP`);
- what is exposed today: name, `#ContKind`, X/Y, size, `ContHP`, everything `GetShopInfo`/`SetShopItem`
  read, the buff list.

A fixed distance from an existing row would also reach the tree links (`B_CONTNEXT + 4..+$10`) and the
minimized size (`B_CONTSIZEX + 8 / +$C`). Both hold on every build checked, from 4.0.0c to the beta (§10).

Needs new rows: art ID, minimized flag, generic serial / type ID / opening position, `+$B0` cliloc, and the
type-specific fields of §4.

## 7. Open items

- No shop, bill or target-status gump was open during the live reads: their fields are static only.
- Builds with no client to read: 4.0.1 to 4.0.11b, and where the generic serial moved between 7.0.29.97
  and 7.0.61.13 (§10).
- The old clients of §10 were read statically only. None was run.
- The beta `+$6C` value and the generic `+$C4/+$C8` values: meaning unknown.
- The texts inside a generic gump: they are `HTMLBox` children, and their layout was not mapped.
- Whether an item's `B_GUMPPTR` is cleared when its container gump closes.

## 8. Side result: client.exe 7.0.117.33 needs no table entry

The 2026-11-02 patch turned `client.exe` into 7.0.117.33. `uo/uoclidata.pas` has no entry for it.
`TCstDB.Update` falls back to milestone 0 (7.0.117.1), then `ScannerTable_Post6062` re-reads the addresses
from the running client.

This was emulated on both exes: milestone values, then the scan in the `$400000..$650000` window, first match
wins. On the old exe the emulation reproduces milestone 0 exactly.

- All 42 scan patterns still match. Every `C_*` global is unchanged.
- The code moved: most `E_*` +$220, `E_OLDDIR` / `E_SYSMSGADDR` +$240, `E_SENDPACKET` +$20.
  `E_ITEMCHECKADDR` / `E_ITEMREQADDR` did not move.
- At every hook the first 14 instructions are identical apart from operands that moved with the code (the
  SEH handler; the security cookie `$757B98` → `$757BB8`).
- The fields the scan does not cover are 0 in both builds, as before.
- The globals reached at a fixed distance (`B_LANG`, `B_LTARGX`, `B_LTARGTILE`, `B_TITHE`, `B_TARGPROC`,
  `B_SKILLDIST`, `B_LLIFTEDKIND`) are referenced by the same number of instructions in both builds.
- The event cave site (`$400600`, padding in the PE header) is still empty.

Not done: no event command was run on 7.0.117.33.

## 9. How it was done

1. **Class → vtable map.** Find each `.?AV…Gump…@@` type descriptor, the Complete Object Locators that point
   at it (signature 0, offset 0), and the dword that points at each locator; the vtable starts 4 bytes after
   it.
2. **Constructors.** Find each class's `mov dword [reg], <vtable>`, then list every store into the object
   from the function start to its `ret`. The base constructor is the one that stores `"normal gump"` and
   `$FEEDBEEF`; each subclass stores its own name string at `+$08`. A constructor that stores a known art
   constant (`$4EC`, `$870`, `$2A6C`) gives the art ID offset.
3. **Tree links.** A sweep for the add-child shape:
   - `mov r,[p+$60]`, `mov [c+$58],r`, `mov [r+$5C],c`, then `cmp [p+$68],0`.
   - Disassemble linearly and restart after undecodable bytes; `disasm_lite` alone stops at the first one.
4. **Generic type ID.** A sweep for a loop that loads `[g+$58]`, calls a virtual method, then
   `cmp [g+X], reg` (the find-by-type-id function).
5. **Live.** Walk `[C_CONTPOS]` by `+$58` and print the fields per gump. Then check every top-level gump's
   `+$5C` / `+$64` and every child's `+$64` / `+$5C`, and each window's `+$68`.
   - On the beta add the load delta: actual base − `$400000`.
   - The beta's list head, from its type-id lookup at `0x54E100`, is link-time `$90A868`.
6. **Hook check (§8).** Parse `SysVarMS*` and `ScannerTable_Post6062` out of `uoclidata.pas`, map both exes
   at their section addresses, and run the scan.

The scripts were throw-away (session scratchpad). The old 7.0.117.1 exe survives only as
`C:\Users\ACER\AppData\Local\Temp\rea-ghidra-41b5b50484bf2dd8db8bfb2efc510bfb\target-e5a225d97180.exe`,
a temp file: copy it somewhere permanent to compare future patches.

## 10. Old clients (static check, 2026-11-07)

Eleven clients from `D:\Tmp\UO Clients\`, disassembled with capstone and never run. `client_tc.exe`,
`client.exe` (7.0.117.33) and the beta were run through the same scripts as references.

### Results

| Field | 4.0.0c | 4.0.11c, 5.0.0b, 5.0.4a, 5.0.9.1, 6.0.0.0, 6.0.4.0, 6.0.14.3, 7.0.1.1, tc 7.0.29.97 | 7.0.61.13, 7.0.117.0, 7.0.117.33 | beta |
|---|---|---|---|---|
| vtable / marker / name | `+$00` / `+$04` / `+$08` | same | same | same |
| full width | `+$1C` | `+$20` | `+$20` | not checked |
| width / height | `+$20` / `+$24` | `+$24` / `+$28` | same | same |
| minimized width / height | `+$28` / `+$2C` | `+$2C` / `+$30` | same | same |
| X / Y | `+$30` / `+$34` | `+$34` / `+$38` | same | same |
| linked object | `+$38` | `+$4C` | same | same |
| next / prev / first child / parent / last child | `+$44 .. +$54` | `+$58 .. +$68` | same | same |
| **art ID** | **`+$58`** | **`+$6C`** | **`+$6C`** | `+$70` |
| **minimized flag** | **`+$68`** | **`+$7C`** | **`+$7C`** | `+$80` |
| **generic serial** | **`+$C4`** | **`+$D8`** | **`+$E0`** | `+$178` |
| **generic type ID** | **`+$C8`** | **`+$DC`** | **`+$E4`** | `+$17C` |

- **Every existing row is right.** `B_CONTNEXT`, `B_CONTX`, `B_CONTSIZEX`, `B_CONTITEM` and `B_ITEMID`, as the
  milestones give them, match the code of all eleven clients.
- **The list works the same way everywhere.** Each client has the same bring-to-front code: unlink, then link
  at the head. So the list runs front to back on every build.
- **The art numbers do not change.** Shop `$870`, bill `$873` / `$871`, text `$820`, spellbook `$8AC` and
  status `$2A6C` are stored as constants on all eleven. Target status `$804` and buff bar `$4EC` are seen as
  constants from 6.0.14.3 on. On the older clients that have those gumps (from 5.0.4a) no such constant was
  found, and how they set the art was not checked.
- **No art reads -1 everywhere.** The base constructor sets -1 on all eleven, and the generic gump code stores
  no art, so a server gump reads `N/A`.
- **Names.** `container`, `status`, `paperdoll`, `skill`, `shop`, `bill`, `generic` and `normal gump` exist on
  all eleven. `target status gump` and `BuffIcons Gump` start at 5.0.4a.
- **The C++ class name needs RTTI, which starts at 6.0.14.3 here.** The seven clients from 4.0.0c to 6.0.4.0
  have none, so an optional class-name field would read `N/A` there.
- **Correction:** §4 used to guess `+$DC` / `+$E0` for the tc serial and type ID. They are `+$D8` / `+$DC`.

### Where the milestone tables do not fit the client

Not about gumps: these affect every feature that reads a `C_` address on these two builds.

| Client | `C_CONTPOS` from the table | In the code | Other `C_` rows |
|---|---|---|---|
| 4.0.11c | `$695388` | `$69D770` | **None of the 22 appear in the code.** Milestone 116 only has `E_` rows, so the `C_` rows are inherited from 4.0.11b. |
| 5.0.4a | 0 | `$6B7360` | All 0: milestone 99 clears them. |

Neither build gets a scan: `ScannerTable_Pre6062` is empty. So a gump command would find nothing on 5.0.4a, and
would read a wrong address on 4.0.11c. Stopping when `+$04` is not `$FEEDBEEF` guards against the second case:
the marker is on every build.

All the other clients are fine: the table value matches on 4.0.0c, 5.0.0b, 5.0.9.1, 6.0.0.0, 6.0.4.0, 6.0.14.3
and 7.0.1.1, and the scan finds the right address on 7.0.29.97, 7.0.61.13 and 7.0.117.0.

### Builds with no client to read

| Versions | What is known |
|---|---|
| 4.0.1b | `B_CONTNEXT` is still `$44`, so it probably has the 4.0.0c layout |
| 4.0.2a to 4.0.4t | `B_CONTNEXT` is `$48`, a layout no client here has |
| 4.0.5a to 4.0.11b | `B_CONTNEXT` is `$58`, so probably the 4.0.11c layout |
| 7.0.29.98 to 7.0.61.12 | the serial and type ID moved from `$D8` / `$DC` to `$E0` / `$E4` somewhere here |

### How it was found

- **Serial and type ID: the `$B1` gump reply.** The client sends back serial first and type ID second, and
  this code reads them straight from the gump. It is the strongest evidence, and the same on every fixed-base
  build:

  ```
  push 0xB1 / push eax / call <packet start>
  mov  ecx, [ebp + SERIAL]   ...
  mov  eax, [ebp + TYPEID]
  ```

  The bytes `68 B1 00 00 00 50 E8 ?? ?? ?? ?? 8B 8D <SERIAL>` match exactly once in each of the 13 fixed-base
  clients, 7.0.117.33 included. The beta builds the packet differently (`mov byte ptr [esp+$10], $B1`), but
  also reads `+$178` and `+$17C` there. The generic constructor's argument order agrees on all the fixed-base
  clients.
- **The find-by-type-id function** of §9 only exists from somewhere after 7.0.29.97. It is not on the older
  clients.
- **Art ID:** constructors storing the constants above.
- **Minimized flag and size:** the code right after bring-to-front picks width and height from one pair or the
  other according to the flag.
- **Tree links and list head:** the bring-to-front code itself. The head is the global it writes, and 62 to 77
  places in each client walk the list from it.
- **Linked object and item ID:** the code reading `[gump + B_CONTITEM]`, then `[item + B_ITEMID]`.
- **Version:** `uoscanver`'s detection, emulated on the files. It reports the version in each file's name.

## 11. Answering a server gump (2026-11-15)

How a click on a server gump's button reaches the server, and what a script command can do the same way.
Static analysis of `client.exe` 7.0.117.33, checked against `client_tc.exe` and the beta. The server side is
from ModernUO (`D:\ModernUo\modernuo`, commit `c9875e7f6`, 2026-08-31). Nothing was run.

### What the client does on a click

The reply function (`0x4D5300` on 7.0.117.33, `0x4C9EA0` on tc, `0x513200` on the beta) is a method of the
generic gump that takes the button number. It builds a `$B1` packet on its own stack and passes it to the
client's send function, `0x462960` on 7.0.117.33. That is the function `E_SENDPACKET` already points to, the
one every `exevent` uses through `SendExEvent`.

| Bytes | Field | From |
|---|---|---|
| 1 | `$B1` | |
| 2 | packet length | filled by the packet builder (`0x48A2D0`) |
| 4 | gump serial | `[gump + $E0]` (beta `+$178`) |
| 4 | gump type ID | `[gump + $E4]` (beta `+$17C`) |
| 4 | button number | the argument |
| 4 | number of switches that are on | counted over the gump's elements |
| 4 × n | the ID of each switch that is on | |
| 4 | number of text entries | |
| per entry | ID (2 bytes), length in characters (2 bytes), the text in UTF-16 | at most 239 characters (`$EF`): the client cuts the rest |

Every number is big-endian (`0x48A450` calls `htonl`).

Who calls the reply function, on all three builds:

| Caller | Button sent | Then |
|---|---|---|
| A reply button. The element's `+$44` bit 0 marks a reply button, and `+$48` holds its number. Other buttons only change page. | the button's number | it deletes the gump: `call [vtable + 0]` with 1 |
| Right-click to close | 0, only if `[gump + $DC]` is not 0 | it deletes the gump |
| Two loops that close every gump (what triggers them was not traced) | 0, same condition | it deletes the gump |

- **The client deletes the window itself, right after sending.** The server sends nothing to close it.
- The exception: for type IDs `$2410` to `$2462` the click code takes a jump table, and some of those gumps stay
  open for some buttons. These numbers are OSI's own gumps; ModernUO's type IDs are hashes.
- On `tc` (three callers) and the beta (four), every call is followed by the same delete (`[vtable + 0]`
  with 1).

### Where the switch and text values come from (7.0.117.33 only)

The reply function walks a tree of layout elements that starts at `[gump + $E8]`:

| Offset | Meaning |
|---|---|
| `+$2C` / `+$30` | first child / next element |
| `+$3C` | element kind: 6 or 7 is a switch (checkbox or radio; which is which was not checked), 8 is a text entry |
| `+$48` | the element's ID (switch ID, text entry ID, button number) |
| `+$60` | the switch is on |
| `+$40` | pointer to the text entry's text (UTF-16) |
| `+$44` | button flags; bit 0 means a reply button |

So the current state of an open server gump (which switches are on, what is typed, which reply buttons
exist) can be read without hooks, from new offsets. Only 7.0.117.33 was checked.

### What the server checks (ModernUO)

`GumpSystem.DisplayGumpResponse` (`Projects/UOContent/Gumps/Base/GumpSystem.IncomingPackets.cs`):

1. It looks for a gump it sent to this connection with **the same serial and the same type ID**. If none
   matches, the reply is silently ignored (apart from the virtue gump, type ID 461).
2. Button 0 always counts as "close". Any other button must exist in the gump. If it does not, the server
   logs "Invalid gump response", ignores the reply and **leaves the gump open** on its side.
3. The number of switches must not be more than the gump has, and the number of text entries likewise. A text
   longer than 239 characters is rejected the same way. The switch and text **IDs** are not checked.
4. Then it forgets the gump (`Remove`) and calls the gump's `OnResponse`.

The serial is a counter the server increases for every gump it creates (`BaseGump`: `Serial = nextSerial++`);
the type ID is the same for every gump of one class (`GetTypeId(GetType())`). When the server closes a gump
itself, it sends `$BF` sub-command 4 with the type ID (`OutgoingGumpPackets.SendCloseGump`). How the client
handles that was not traced.

### What this means for a script command

- **Sending the packet the `exevent` way works.** The server cannot tell it from a click, as long as the
  serial and type ID belong to a gump that is open right now. `SendExEvent` already sends packets of any
  length; the `$BF` packet of `exevent StatLock` is variable-length too.
- **The serial has to be the current one.** A reply recorded earlier carries an old serial, and the server
  ignores it. Replaying a reply means taking the serial from the gump that is open now, matched by type ID.
- **The window stays open in the client**, because only the client's own click path deletes it. Clicking it
  later sends a second reply with a serial the server no longer has, which ModernUO ignores. Two ways to
  close it:
  - delete it the way the click path does, `[vtable + 0]` with 1, from the event cave on the client's main
    thread. That needs no new address: `event ContTop` already calls a client function on a gump pointer
    the same way. It frees client memory, so it must run only on a gump that is still in the list;
  - or leave it open, and document it.
- **Recording what the client sent needs a hook.** The packet is built on the stack, then sent at once
  (`0x466CB0`) or copied into a send queue (at `[net + $900C4]`) that is flushed and reused. Neither keeps it.
  The send method (`0x467BA0`) also counts packets and bytes per opcode in a map at `[net + $6C]`: that could
  show *that* a `$B1` went out, not what it held. So a variable with the last reply sent by the client needs a
  code cave on `E_SENDPACKET` that copies packets starting with `$B1`. Without one, Reforged can only remember
  the replies it sent itself.

## 12. Built and checked (2026-11-15)

What came of this analysis, and what the live checks added to it.

- **Code:** `ScanGumps` and the `#Gump…` variables (`uo/uocommands.pas`, GUMP LIST); `exevent GumpReply`,
  `#GumpReply`, `#GumpReplyRes`, `#GumpReplyCnt` (`uo/uogumpreply.pas`, `uo/uoevents.pas`); the rows `B_GUMPART`,
  `B_GUMPMIN`, `B_GUMPSERIAL`, `B_GUMPTYPE` in `uo/uoclidata.pas` (7.0.29.97 and newer, the owner's choice; 0 from
  7.0.30 to 7.0.46 for the serial and type ID); `tools/EUOMigrate/euomig/gumpfields.py` derives all four from code.
- **The installed clients changed** since §1: `client.exe` is 7.0.118.46, `client_beta.exe` 7.0.118.132. The code
  shapes of §10 give the same offsets on both ($6C/$7C/$E0/$E4 and $70/$80/$178/$17C), and on 7.0.1.1, 6.0.14.3,
  7.0.61.13 and 7.0.117.0 ($D8/$DC on the first two).
- **The minimized flag is a dword** on every build checked: the bring-to-front code tests it with `cmp dword`.
- **The client keeps a packet's length low byte first** while it builds it (`0x48A2D0` on 7.0.118.46 stores 3, then
  each append updates it as a word; the beta the same); the send function fixes it up. The `$B1` answer is built so.
- **The beta keeps its menu bar as entry 1** of the list, in front of every window.
- **Closing the window from the event cave** (`[vtable+0]` with 1, as the click path does) worked on both clients:
  dozens of answers, no crash.
- **A click sends the window's state:** a Cancel in `[AddonGen` sent `0 0/1 0: 1:Server.Items 2:-128 3:127`, the
  switches and every text field, not a bare button 0.
- **The send function's first bytes** (the click hook): 7.0.118.46 `0x462960` `mov ecx,[0xA0839C]` (6 bytes, then
  `test`/`je`); the beta `0x434930` `push ebp/mov ebp,esp/push ebx/push esi` (5 bytes). The beta's `E_SENDPACKET`
  scan pattern starts at those bytes, so `ScannerTable_Modern` also has the same patterns with them as jokers.
  Live: the hook recorded hand clicks on both, and a new process found it again and counted on.
- **ModernUO:** an unknown button is refused only on an old-style `Gump`; a `StaticGump` such as the delete
  confirmation passes it on, and that gump takes it as "no" (`docs/modernuo-reference.md` 3.10).
