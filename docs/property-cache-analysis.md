# Item properties from the client's tooltip cache (scanprops)

Research of 2026-11-26/27 for forum item 6 of `docs/forum-feature-candidates.md` (fast item properties), and
what the `scanprops` command and `#FindProp` were built on. Addresses are file (link-time) addresses; the
betas are relocated at run time and every address there moves by the same delta. Tools: capstone over the
executables, REA, and read-only probes of the running clients (a Python harness and a Pascal port in the
session's scratchpad).

## 1. The decision

`event property` asks the client for one item per call: a cave the client runs on its next main-loop pass,
then up to a hundred 30 ms polls. Three ways to read many items were measured (section 7). The owner chose
**option B**: Reforged reads the cache itself and puts the tooltip text together with a Pascal port of the
client's formatter (`uo/uoprops.pas`). Only items the cache can't answer go through a cave, and that cave only
calls the client's own request function.

Owner's choices: `scanprops` (no parameters) over the last `finditem`; `#FindProp` follows `#FindIndex`;
uo.dll `ScanProps` plus a 12th `GetItem` value; no word filter in the port; ask-wait-fall-back for uncached
items, the wait following progress (1 s without an answer, 500 ms once only items with no entry are left, 15 s at
most); items with no entry are asked for too;
the newer formatting logic applied to the older clients as well; the English-tooltips option documented only.

## 2. The cache

A `std::map<serial, entry*>` the client keeps for every object whose tooltip it has heard of.

| | fixed-base (`client.exe`, MSVC 2008 STL) | betas (`client_beta.exe`, MSVC 2015+ STL) |
|---|---|---|
| map object | tree head pointer at +4 (`B_STLHEAD` 4) | tree head pointer at +0 (`B_STLHEAD` 0) |
| node | left +0, parent +4, right +8, key +$C, entry +$10, colour +$14, isnil +$15 | left +0, parent +4, right +8, colour +$C, isnil +$D, key +$10, entry +$14 |
| entry | +4 line list head (`B_PROPLIST`), +8 list size, +$C revision, +$10 state byte (`B_PROPSTATE`) | +0 line list head, +4 list size, +$C state byte |
| list node | next +0, previous +4, line pointer +8 | the same |
| line | cliloc +0, `wchar_t*` arguments +4 (tab separated, may be null) | the same |

The node layout is the cliloc map's, which `ClilocText` (ScanBuffs) already reads with `B_STLHEAD` /
`B_CLILOCKEY`; the entry pointer follows the key.

**State byte.** 4 = the server announced a tooltip (0xDC revision) that the client hasn't fetched; 0 once the
data arrived. client.exe 7.0.118.46: `0x43F140` makes a fresh entry with state 4 (an announce), `0x43EE90`
stores the data (it creates the entry when the serial has none). Beta 7.0.119.0: `0x425870` sets
`[entry+$C]=4`, `0x425510` clears it, `0x4257B0` tests it.

**The property check `E_ITEMCHECKADDR`.** Fixed-base `0x43F0A0`: `map[id]->state == 4` ("needs fetching").
Beta `0x427610` (fastcall): returns the entry's list size, so non-zero means "has lines"; an announced entry
that still has its old lines answers "cached" (why `PropFastCode` branches the other way).

**The request `E_ITEMREQADDR`.** Fixed-base `0x440470` (cdecl): inserts the ID into a request queue (container
at `0x75F010`) when it is not there yet; it does not look at the cache, so an ID with no entry is queued too.
`0x440800` walks the whole cache and calls the request for every state-4 entry. The code that sends the queue
to the server (0xD6) was not located statically; the hand tests measure how fast answers come.

**Size.** When the map holds more than 20,000 entries (`[map+8] > $4E20`), the client evicts 2,000 before
adding (`0x43DF50(0x7D0)`).

**Empty nodes.** The fixed-base name builder looks the item up with `operator[]` (`0x43ECA0`), which inserts a
node with a null entry for a serial it doesn't have. A null entry means "no entry".

## 3. The addresses: scan patterns

`C_PROPCACHE` is found by signature scan only (no table values):

| table | pattern | where |
|---|---|---|
| `ScannerTable_Post6062` | `8D4C24145133EDB911111111896C244489442418E8`, +8, mode 3 | the name builder's `mov ecx,CACHE` |
| `ScannerTable_Modern` | `8B303B35111111110F8411111111837E14000F84`, +4, mode 3 | next to the check: `cmp esi,[CACHE]` |

Emulated over every executable at hand (first match per line, last line wins), one hit each:

| build | C_PROPCACHE | E_ITEMCHECKADDR | E_ITEMREQADDR | C_CLILOC |
|---|---|---|---|---|
| 7.0.4.3 | $702F64 | $43F650 | | |
| 7.0.29.97 (`client_tc.exe`) | $717B04 | $440370 | | |
| 7.0.45.89 | $736704 | $43D990 | | |
| 7.0.108.0 (`client_noenc.exe`) | $75C804 | $43F0A0 | $440470 | $9FF39C |
| 7.0.117.33 | $75F004 | $43F0A0 | $440470 | $A01B9C |
| 7.0.118.46 | $75F004 | $43F0A0 | $440470 | $A01B9C |
| beta 7.0.117.31 | $20AA594 | $4269A0 | $424EE0 | $815170 |
| beta 7.0.118.132 | $21195C4 | $426790 | $424CD0 | $87C16C |
| beta 7.0.119.0 | $22F8FD8 | $427610 | $425A90 | $A64970 |

The state byte is `cmp byte [entry+$10],4` in the check of every fixed-base build from 7.0.4.3 to 7.0.118.46,
and `cmp byte [entry+$C],4` in all three betas. The layout rows sit in `SysVarMS140` (fixed-base) and
`SysVarModernLayout`.

## 4. The formatter (what the port copies)

client.exe 7.0.118.46 addresses; `uo/uoprops.pas` names each one.

- `ItemName 0x58B660` / `ItemProperties 0x58B560` call the name builder `0x43F260` (the first line) and the
  properties builder `0x43F530` (the other lines, joined with `<BR>`).
- **Template** `0x58E7C0` -> `0x58E570`: the cliloc's text, UTF-8 decoded by `0x5F6620` (no validation, at
  most $3FFE characters). A missing cliloc gives `Error (MegaCliloc) : StringId Not Found : <id>`, a null text
  `Error (MegaCliloc) : Null String : <id>`; the id is written in decimal (`%d`).
- **Filler** `0x5907B0`, arguments split by `0x590BD0` on tabs (a trailing tab adds no empty argument; an empty
  text is one empty argument):
  - `~N_name~` is argument N (wtoi `0x5F69D0`); an argument `#id` becomes that cliloc's text, `~#id~` too, but
    only for ids 500000-1999999 and without filling that text in turn;
  - the 19 clilocs of `0x58C5F0` keep `#` arguments literal: $FE441, $FE465, $FE4C1, $FEB69, $FF78E, $1005BD
    (1050045), $102FC2, $102FC4..$102FC6, $1030F8, $103307, $103631, $103634..$103636, $103651, $103662, $105682,
    $105CB1;
  - an escaped `\~` appends `126` (the character's number, in decimal);
  - a bad token makes the whole line `Error (TID): Token Out of Range : N : cl` or `Error (TID): Provided Token
    Out of Range : N : cl`.
- **Title case** `0x5FDE40`: ASCII letters only, the first one and those after ' ', '-', LF, '[' or '>'; on the
  name and on every property line except cliloc 1062613 ($1036D5).
- A **1076226** ($106C02) line is the cliloc its first argument names (filled with the same arguments).
- **Colour tags** for 1062613, 1080418 ($107C62) and 1159561 ($11B189); `GetFormStr` removes them again.
- **Beta only**, `0x426910` coin plural: for a 1050039 name whose item cliloc is graphic $28E, $EED or $EF0
  (1020000+graphic) and an amount above 1, the item cliloc gets +1 for 2-5 and +2 above 5.
- **Left out** (owner's choice): the word filter `0x5C8EA0` (a bad-word table, applied to 1062613, 1072305
  ($105CB1) and 1076226 lines) masks swear words in player-written text; the port shows them unmasked.
- **Not ported**: the config option at `[0xA5D73E]` (a bool read from the client's settings at `0x563085`).
  When set, the name template comes from `0x5906F0`, which loads `cliloc.enu`: English tooltips on a client
  whose language is another one. The port reads the client's loaded cliloc table, so with that option it gives
  the client language's text. English clients are unaffected.

**Across builds** (normalized instruction streams of everything `ItemName` / `ItemProperties` call, four levels
deep):

- 7.0.108.0, 7.0.117.33 and 7.0.118.46: identical.
- The betas 7.0.117.31, 7.0.118.132 and 7.0.119.0: identical logic; 7.0.119.0's template takes an extra
  argument that these paths pass as 0, and object offsets moved.
- 7.0.29.97 and 7.0.45.89: the title case lacks '>' and the properties builder differs a little.
- 7.0.4.3: very different.

The owner chose to apply the newer logic to the older builds too and to say so in the documentation.

## 5. From the client's strings to `#Property`

`TUOEvent.GetFormStr` (unchanged since 1.5) reads 8,000 bytes of the client's UTF-16 string: the low byte of
each of the first 4,000 characters, cut at the first zero low byte; bytes below 32 become spaces; `<BR>`
(upper case only) becomes CRLF; then up to 500 `<...>` are removed (a `>` before the first `<` stops it).
`EvProperty` keeps the properties only when the name is not empty. `#Property` joins them as `name$` +
`props$` (when not empty) with CRLF -> `$`; since 2585cf8 the interpreter converts the result from Latin-1 to
UTF-8 (`Latin1ToUtf8`). `#FindProp` stores the Latin-1 text and converts the same way; uo.dll keeps Latin-1,
like `Property`.

`common/access.pas` `ReadMem` zeroes the buffer and binary-searches the readable length when a read fails, so
a client string near the end of a memory region still reads whole.

## 6. Verification of the port

Byte for byte against the client's own text (the batch cave of option A, which calls `ItemName` /
`ItemProperties`):

| client | objects | equal |
|---|---|---|
| client.exe 7.0.118.46, local ModernUO | 48 | 48 |
| beta 7.0.119.0, local ModernUO | 41 | 41 |
| client_noenc.exe 7.0.108.0, live shard UODreams | 1,682 | 1,682 |
| 7.0.108.0 against Reforged's real `event property` | 1,326 shared items | 1,326 |

The live shard found one port bug, now fixed: a cliloc that client's cliloc file lacks (1164872) showed the
error id as a raw character; the client writes it in decimal. Four items `finditem` saw had no cache entry
("Nodraw" objects): `event property` names them from the object itself.

## 7. The three options measured

| | client.exe .46 | beta 7.0.119.0 | live 7.0.108.0 |
|---|---|---|---|
| `event property` per item | 55 ms | 38.5 ms | 74.9 ms (1,330 items in 99.6 s) |
| empty cave pass | 47 ms | 3.5 ms | 47 ms |
| **A**: batch cave calling ItemName / ItemProperties | client 9 µs/item | client 10.5 µs/item | ~1.2 ms per object in all (client 45 µs) |
| **C**: cache read + cave calling the template / filler per distinct line | 2.1 µs/line | 2.2 µs/line | 19.2 µs/line, ~0.85 ms per object |
| **B**: cache read + Pascal formatter, read-only | 21-43 µs | 33-70 µs | 53-83 µs (~0.1 s for 1,682 objects) |

A also needs the client's string destructor as a new field: `ItemName` / `ItemProperties` construct a new
16-byte string object (pointer, length, 1, capacity) into the caller's slot every call, and nobody frees it,
so `event property` leaves two heap buffers in the client per call (a known limitation now). B creates no
client strings at all.

## 8. Uncached items (what scanprops does)

- Fetched entry: formatted at once.
- Announced (state 4) or no entry: requested in one round of cave passes. `PropReqCode` writes, per item, only
  the client's request call (`push id; call; add esp,4` fixed-base, `mov ecx,id; call` on the betas), 150 items
  per pass, below `IMAGEBASE+$F00`. Then the cache is read again every 50 ms; the wait ends after 1 s without a
  new answer (500 ms when only items with no entry are left), or after 15 s (constants `PROP_IDLE_MS`,
  `PROP_IDLE_NONE_MS`, `PROP_CAP_MS`). On the live shard 2 objects of 1,175 had no entry and never got an
  answer: with a 1 s wait every scan that included them took 1.25 s instead of ~0.1 s (owner chose 500 ms).
- Afterwards: an announced item still waiting stores the lines it still has (the betas keep the old tooltip) or
  `$`; an item with no entry gets one `event property` on the fixed-base clients and `$` on the betas, where
  `event property` would only request it again and give `$` after 3 s.
- No cache field (or `C_CLILOC` missing): every item gets one `event property`.

## 9. EUOMigrate

`tools/EUOMigrate/euomig/propfields.py` reads `B_PROPSTATE` and `B_PROPLIST` from code shapes (section 3 and
its own header): right on all eight builds above (7.0.29.97 to 7.0.118.46, the three betas).
`oracles.o_propcache` checks `C_PROPCACHE` in a running client (a consistent map, state bytes 0 or 4, lines
with cliloc numbers).

## 10. Hand tests (2026-11-27/28)

| stage | client | test | result |
|---|---|---|---|
| 1 | client.exe 7.0.118.46, local | backpack | 26 items: event property 1,437 ms, scanprops < 1 ms, 26/26 equal |
| 1 | | 1,024 new daggers (`[tile`), scanned as they appear | 6,891 ms while the tooltips arrived, none `$`; cached afterwards 78-94 ms |
| 1 | | self-test stages 5-6 (staff on) | 134 pass, 0 fail (5.26, 6.20 pass) |
| 2 | beta 7.0.119.0, local | backpack | 26 items: 1,000 ms vs < 1 ms, 26/26 equal |
| 2 | | 1,024 new daggers | 5,922 ms, none `$`; cached 188-203 ms |
| 2 | | self-test stages 5-6 | 134 pass, 0 fail |
| 3 | client_noenc 7.0.108.0, UODreams | every known object | 1,175: event property 82,469 ms, scanprops 1,250 ms (782 ms with the 500 ms wait), 1,175/1,175 equal |
| 3 | | bank box | 17 items: 1,218 ms vs < 1 ms, 17/17 equal |
| 3 | | uo.dll (a 64-bit FPC host) | ScanItems 966, ScanProps 665 ms, GetItem 12 values for all 966, the 12th equal to `Property` for 60/60; 11 values before any ScanProps; ScanProps with an argument: ERR_WRONGPAR |

The local clients fetch a new item's tooltip by themselves within a fraction of a second; scanprops only waits
for items it scans before that.

## 11. Open
- A later setting to choose between this implementation and option C (owner, not now).
