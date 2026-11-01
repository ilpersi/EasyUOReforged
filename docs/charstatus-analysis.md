# #CharStatus: what each letter means, from the client

Status: analysis done on 2026-11-01 by static analysis of `client.exe` 7.0.117.1. The site page
(`website/src/content/docs/variables/charstatus.md`) was rewritten from it. No code was changed: the poison
quirk in §5 is documented, not fixed (decided 2026-11-01). Nothing here is live-tested.

## 1. Sources

| Source | What it is | Reliability |
|---|---|---|
| `D:\Program Files (x86)\Electronic Arts\Ultima Online Classic\client.exe` | FileVersion 7.0.117.1, PE stamp `6A8E6F9D`, x86, 3 616 768 bytes, SHA-256 `e5a225d9718085e465f28c585fe2ab403884d739dc9084ad924bc210bb188a0f` | Authoritative for what the client stores and uses. Read with REA (Ghidra 12.1.4 decompiler, masked byte search, xrefs) plus capstone 5.0.7 disassembly. |
| `uo/uovariables.pas` (`TUOVar.CharStatus`), `uo/uoclidata.pas` | How Reforged (and the original EasyUO) builds the string | Authoritative for our side. |
| ServUO `Server/Mobile.cs`, `Server/Network/Packets.cs`; ModernUO `Projects/Server/Mobiles/Mobile.cs`, `Projects/Server/Network/Packets/OutgoingMobilePackets.cs` | What emulator servers put in the flags byte and in the health-bar packets | Authoritative for those emulators only. Official servers were not checked. |

`client_beta.exe` was **not** analysed (see §7).

## 2. How #CharStatus is read

`TUOVar.CharStatus` (`uo/uovariables.pas`):

1. Reads a **16-bit word** at `player + B_ITEMID + B_CHARSTATUS`. On 7.0.117.1 that is
   `$A8 + $24 = player+$CC`.
2. If `F_EXCHARSTATC > 0`, reads **one byte** at `player + B_ITEMID + B_CHARSTATUS + F_EXCHARSTATC`
   (`+$CC + $18 = player+$E4`). If that byte is exactly `1`, it ORs in bit `$04`.
3. Turns bits 0..15 into letters `A`..`P`, building the string by prepending, so the letters come out
   highest bit first (`GB`, not `BG`).

The player pointer is `C_CHARPTR` (`$A590C4` on this build). `F_EXCHARSTATC = $18` has been in the tables
since the 6.0.6.2 milestone. The modern-layout builds (`SysVarModernLayout`, `B_ITEMID $118`) don't override
`B_CHARSTATUS` or `F_EXCHARSTATC`, so they use the same `$24` / `$18` distances.

## 3. Where the byte comes from

The status byte is **one byte** at `+$CC` in the client's base world-object class, which items and mobiles
share. No code in the client reads or writes it as a 16-bit word: every access is a byte access (masked byte
search, §8).

The client copies it **unchanged from the server**. It never sets or clears a bit on its own. The writers:

| Packet | Handler | Note |
|---|---|---|
| `0x20` (player update) | `FUN_0047cdf0` → `FUN_0047cbe0` | Checks the serial against the player's (`DAT_00a08218`), stores the byte at `C_CHARPTR+$CC`, refreshes the player's gumps when it changed. |
| `0x77` (mobile moving) | `FUN_0047cef0` | |
| `0x78` (mobile incoming) | `FUN_0047d170` | |
| `0xD2` | `FUN_0046c9b0` | |
| `0xD3` | `FUN_0047d740` | |

Every mobile flag change goes through `FUN_005c7c40(mobile, newFlags)` (called from `0x5c8724`). Other
writes to `+$CC` are the base-object constructor `FUN_005157f0` (zeroes `+$CC` and `+$CD`), another
initialiser at `0x5baa7f` (zero), and the `0x27` lift-rejected handler `FUN_0046dd30`, which restores a lifted
**item's** saved flags from global `$A5910A`.

The packet ids come from the client's own packet switch at `0x48b7a9`:
`case = byte[$48C710 + id - $0B]`, `handler block = dword[$48C4BC + case*4]`, and the first `call` in each
block is the handler.

## 4. Bit by bit

| Letter | Bit | What the client does with it (7.0.117.1) | What ServUO / ModernUO send |
|---|---|---|---|
| `A` | `$01` | The walk request is refused while it is set (`0x5a7bd0`, inside the walk code). | Paralysed, frozen, or casting a spell that blocks movement. |
| `B` | `$02` | Gender for the body and paperdoll art: `0x190 + bit` (`0x520e24`, `0x522bb9`, `0x522c5e`). | Female. |
| `C` | `$04` | **Flying.** Getter `0x5beff0` (`shr 2; and 1`). Movement mode 4 when set (`0x5a7541`). Flying animation (group `$13` at `0x450271`; `0x5be116`, `0x5c1748`, `0x5c7887`) only when the client option `FlyingAnimations` is on: option index `$A8` in the name table at `$71D3D8`, stored in byte `$750098` by `FUN_00560d40`. Nothing in the client treats this bit as poison. | ServUO: always flying. ModernUO: flying on Stygian Abyss clients, poison on older ones. |
| `D` | `$08` | **Not read anywhere.** The client draws the yellow bar from the health-bar state (§5), not from this bit. | `Blessed \|\| YellowHealthbar` (invulnerable, or a yellow bar set by the server, e.g. after a lethal strike). |
| `E` | `$10` | Walk through mobiles. Getter `0x5a6e50`. When the player has it, the collision loop over mobiles is skipped (`0x5a720a`); another mobile with it doesn't block (`0x5a72aa`). | `IgnoreMobiles`. |
| `F` | `$20` | Only in the item movability / weight check: getter `0x5bef20` returns weight `$FF` when set, `0x5bd070` and `0x54118b` skip the tiledata weight test. | Never set on a mobile. |
| `G` | `$40` | Not read back from `+$CC`. `FUN_005c7c40` copies it to the war-mode field `mobile+$1B0` (`flags >> 6 & 1`, forced to 0 when the mobile's virtual `+$C0` check is true) and calls `FUN_005c7070($C)` / `($D)` on a change. | War mode. |
| `H` | `$80` | Hidden. Drawn with hue `$3E3` (`0x45527c`); skipped by loops over all mobiles (`0x5949e4`); when a mobile other than the player becomes hidden, its open gumps are closed (`FUN_005c7c40`). | Hidden. |
| `I`..`P` | `+$CD` | Not status at all: `+$CD` is the object's **equip layer** (set by the equip routine `FUN_005c4ed0`: `item+$CD = layer`, `mobile+$124+layer*4 = item`; layer `$19` is the mount). A mobile is never equipped, so it stays 0. | n/a |

The 34 bit tests (`test byte ptr [reg+$CC], imm`) in the client use only `$01`, `$04`, `$10`, `$20` and
`$80`. Many other classes reuse offset `$CC` for unrelated fields (for example the gump methods
`0x4c64f0`, `0x4dd250`, `0x5d4da0`), so a hit on `+$CC` alone proves nothing. Check the object is a
world object first: `C_CHARPTR`, a mobile list, or a virtual `+$24` (is-mobile) check.

## 5. Poison: `F_EXCHARSTATC` reads a count

Packets `0x17` (`FUN_00484d20`) and `0x16` (`FUN_00484c30`) are the health-bar updates:
serial, count, then per entry a type word and an enable byte. For each entry the handler:

- enable `0` → erases the type from a `std::map<uint32 type, uint8 value>` at **`mobile+$DC`**
  (`FUN_00483870`);
- enable non-zero → `map[type] = enable` (`FUN_00484630`);
- then `FUN_005bef80(type)`, which refreshes the mobile's health bars for types 1 and 2.

The map is an MSVC `std::map`: `+$DC` padding, `+$E0` head node, **`+$E4` element count**. The insert path
checks `[map+8]` against the maximum size and does `add dword ptr [map+8], 1` (`0x481369`, `0x4813de`). A
node is left `+0`, parent `+4`, right `+8`, key `+$C` (dword), value `+$10` (byte).

So the byte EasyUO reads at `+$E4` is the **number of active health-bar states**, not a poison flag. Type 1 is
poison (ServUO and ModernUO send `level + 1` as the value), type 2 is the yellow bar (`Blessed ||
YellowHealthbar`). Emulators send poison only this way to these clients, never in the flags byte.

The result, with `D` added (the emulators set the yellow state and bit `$08` from the same condition):

| State | Map count | `C` | `D` |
|---|---|---|---|
| Nothing | 0 | no | no |
| Poisoned | 1 | yes | no |
| Yellow bar (lethal strike, invulnerable) | 1 | **yes, wrong** | yes |
| Poisoned and yellow bar | 2 | **no, wrong** | yes |
| Flying (gargoyle) | any | yes | as above |

The site page documents this and gives the workaround: when not flying, poisoned = `C` xor `D`.

This is the original EasyUO logic, ported unchanged. It probably dates from when Cheffe noticed the byte
"turns 1 when poisoned". When the map replaced a plain flag (between 6.0.6.2 and 7.0.117.1) is not known.

## 6. Possible fix (not done)

Read the poison entry itself instead of the count: find key 1 in the map at `player + B_ITEMID +
B_CHARSTATUS + F_EXCHARSTATC - 8` (`+$DC`) by walking the tree from the head node at `+$E0`, and add `C` when
the value is non-zero. To settle first:

- the node's colour / is-nil byte offsets (`+$11` / `+$12` would be the usual MSVC layout; not checked), or
  walk with a size bound from `+$E4`;
- whether bit `$04` should still add `C`. It means flying, and old scripts read `C` as poison;
- whether this is acceptable under the "outward contract does not change" rule. It changes what
  #CharStatus returns, so it needs a decision, a `changed: true` page with *Reforged notes*, a
  `whats-new` entry, and a hand test (poisoned / yellow bar / both) on a live client.

## 7. Open items

- **client_beta.exe** (modern layout): not analysed. It inherits the `$24` / `$18` distances from
  `B_ITEMID $118`, so the status byte should be at `+$13C` and the count at `+$154`. Check that the same
  map and the same bits are there.
- **Live check** of the §5 table with a poisoned character, a yellow bar, and both, reading
  `#CharStatus` each time.
- **Older clients**: which milestone first has the map at the `F_EXCHARSTATC` position.
- **Official servers**: what they send in `$08`, `$10`, `$20`, and whether they put poison in `$04`.

## 8. How it was done (to repeat on another build)

1. Open the client in REA with the Ghidra provider (`open_binary`, `provider_id: ghidra`; the first import
   takes a few minutes).
2. Masked byte searches (`search_bytes`) for every access form at the status offset. Change `CC000000` to
   the build's offset:
   - `test byte [reg+disp32], imm8`: `F680CC000000` mask `FFF8FFFFFFFF`
   - `mov byte [reg+disp32], r8`: `8880CC000000` mask `FFC0FFFFFFFF`
   - `80 /x byte [reg+disp32], imm8`: `8080CC000000` mask `FFC0FFFFFFFF`
   - word forms (both empty here): `668980CC000000` and `0FB780CC000000`, mask `FFFFC0FFFFFFFF`
3. A capstone linear sweep of `.text`, printing every instruction whose memory operand has the
   displacement, then for each byte load the `shr` / `and` / `test` applied to that register in the next
   few instructions. This finds the getters (`shr N; and 1; ret`) that the `test` search misses.
4. `xrefs` on the player-update function, then decode the packet switch (§3) to name each handler.
5. Decompile the writers and the health-bar handlers (`procedure_pseudo_code`). Use raw disassembly where
   Ghidra drops the `this` pointer (`ECX`) of `thiscall` methods: that is how the map at `+$DC` was found.
