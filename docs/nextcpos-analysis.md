# #NextCPos: where the client opens a container gump

Status: analysis done on 2026-11-13. Static analysis of `client.exe` 7.0.117.33, then live runs of
`tests/tools/NextCPosProbe.euo` on the owner's client (ModernUO shard, GM character), with the client option
*Offset interface windows rather than perfectly stacking them* off and on. No code was changed. Self-test
check 5.08 and the site pages are handled from §6.

## 1. Sources

| Source | What it is | Reliability |
|---|---|---|
| `D:\Program Files (x86)\Electronic Arts\Ultima Online Classic\client.exe` | FileVersion 7.0.117.33, PE stamp `6AD994F1`, x86, fixed base `$400000`, 3 616 768 bytes, SHA-256 `6eefcdc345fcfd54da00d63045b5b753d51ecd8b90e30c414fcf14a6f5929b80` | Authoritative for what the client does. Read with REA (Ghidra 12.1.4 decompiler) and capstone 5.0.7. The running client's code at the container routine was compared with the file: identical. |
| `tests/tools/NextCPosProbe.euo`, live | Runs A (option off), B and D (on), C (on, cases 3 and 8 only, twice) | Authoritative for this client and this shard. Raw logs are in the side-session notes folder, not in the repo. |
| `uo/uovariables.pas`, `uo/uoclidata.pas` | How Reforged reads and writes the pair | Authoritative for our side. |

client_beta.exe and older builds were **not** analysed (§7).

## 2. How Reforged reads and writes #NextCPos

`C_NEXTCPOS` is `$8DC9A4` on this build (milestone 0 and `ScannerTable_Post6062` agree: the pattern
`406A0057518B0D` matches once, at `$4F6923`, inside the container routine below). It holds Y. X is at
`C_NEXTCPOS + B_NEXTCX` (default 4) = `$8DC9A8`.

`TUOVar.ReadNextCPosX/Y` return the stored value **plus 16**, and `WriteNextCPosX/Y` store the value **minus
16** (`uo/uovariables.pas`, ported unchanged from EasyUO 1.5). The client adds 16 before it opens a window
(§3), so #NextCPosX / #NextCPosY are the place where the next container window opens. Read live at the same
moment: `$8DC9A4/$8DC9A8` = 160/160, #NextCPosX/Y = 176/176.

## 3. The client code

Only two functions reference `$8DC9A4` / `$8DC9A8` (5 references each, all absolute):

- **`$4E6670`**, called once from the start-up function `$60AAE0` (`$60ACB3`), which also registers the
  client's `atexit` handlers. It sets both stored values to 16, so #NextCPos reads 32/32 after the client starts.
  It is not called at login: the values carry over from one character to the next in the same client process.
- **`$4F6150`**, the open-gump routine (29 call sites). The container packet `0x24` handler `$46D0E0` calls it
  as `$4F6150(object, gump, 0, flag, 0)`, with `flag` 1 for an item container.

`$4F6150`:

1. If the object already has a window (`$4E76B0` walks the gump list `C_CONTPOS`; `CContainerGump`'s virtual
   `+$16C`, `$4C81F0`, returns 1), it brings that window to the front and returns. The window does not move
   and the stored values do not change.
2. Otherwise it looks up the gump art's width and height (`$570860`). The game area is `[$74F8A8]` wide and
   `[$74F8AC]` high (2560 × 1532 on the owner's client, read live).
3. Some gump numbers have cases of their own (internal 8 is the paperdoll, constructor `$524C10`, which
   `event macro 8 1` reaches as `$4F6150(player, 8, 0, 0, 1)`), and none of them reads the pair.
   Containers go to the default case:
   - `flag` 0: a plain gump at (width − gump width, 0).
   - **option byte `[$750085]` = 0:** a `CContainerGump` at **(width − gump width − 10, 10)**, the top right.
   - **option byte non-zero:** stored X += 16 and stored Y += 16. X becomes 16 if X + gump width ≥ width − 16,
     Y becomes 16 if Y + gump height ≥ height − 16. The `CContainerGump` opens at (X, Y)
     (`$4F68B3`–`$4F693D`, constructor `$4C9200` stores them at gump `+$34` / `+$38`, which #ContPosX/Y read).

After the window is made, the `0x24` handler calls `$4FC130`, which gives it a saved place if its serial is
in the list of windows still to be restored after login (`$99D48C`, places in the table at `$8DCA34`). Once
that list is empty, the flag `$718DED` turns this off.

**The option.** The client's options table at `$7500DC` pairs the name `OffsetGumps` (`$6C0498`) with the
byte `$750085`. The options text parser sets it to 1 for the value "on" or "yes" (its case at `$561EA4`;
any other value stores a register that is presumably 0, not checked). Reforged does
not read it: that would need a new address (owner's rule), and §5 shows a script does not need it.

## 4. Live results

Game area 2560 × 1532. A bag window is 176 × 194, the backpack 230 × 204, the paperdoll 262 × 324.
"Values" are #NextCPosX/Y before → after the open.

| Case | Option OFF (run A) | Option ON (run D) |
|---|---|---|
| 1. new bag after `nextcpos 300 150` | 2374,10; values 300/150 → 300/150 | **300,150**; values 300/150 → 316/166 |
| 2. two more new bags, no `nextcpos` | both 2374,10; values unchanged | 316,166 then 332,182; values +16 each time |
| 3. use bag 1 while open, others in front | stays 2374,10; values unchanged | stays 300,150; values unchanged |
| 3. the same after `event macro 8 7` and `nextcpos 500 250` | (not run like this) | **moves to 500,250**; values → 516/266 |
| 4. backpack closed, `nextcpos 300 150`, opened | 2320,10; values unchanged | 300,150; values → 316/166 |
| 5. backpack moved to 400,300, closed, opened | 2320,10 (not 400,300) | 300,150 (not 400,300) |
| 6. paperdoll closed, `nextcpos 300 150`, opened | 2300,0; values unchanged | 2300,0; values unchanged |
| 7. new bag after `nextcpos 5000 5000` | 2374,10; values unchanged | **16,16**; values → 32/32 |
| 8. open backpack used again, paperdoll in front | (not run) | comes to the front, does not move; values unchanged |

2374 = 2560 − 176 − 10 and 2320 = 2560 − 230 − 10: the top-right rule. Self-test check 5.08 failed with the bag
at 2374,10 because the option was off.

Run B (ON) gave the same numbers as run D. Its verdicts read `?` only because the first version of the probe
expected the window 16 pixels further on (§2 explains why it is not). Run C repeated case 3 with
the bag and case 8 twice. The owner watched the bag window move from 176,176 to 500,250 (one window, not a second one).

The earlier observations in the self-test hand test fit: the paperdoll always at 2300,0 (its own place); the
backpack at #NextCPos when it was first opened (the option was on then), and later always at 2320,10 (the
top-right place with the option off, not a remembered place).

## 5. Rules a script can rely on (7.0.117.33)

1. **Option off:** every container window opens at the top right of the game area, Y 10, 10 pixels from the
   right edge. #NextCPosX / #NextCPosY are not used and do not change.
2. **Option on:** a container window opens at #NextCPosX, #NextCPosY, and then both go up by 16, so the next
   window opens a little lower and to the right. When the window would come within 16 pixels of the right
   (bottom) edge, it opens at X (Y) 16 instead, and the value then reads 32.
3. **Only containers** (backpack, bags, chests, bank box, corpses): the paperdoll and the other gumps never use
   it.
4. **A container that is already open** comes to the front without moving and without changing the values.
   Exception seen: after the backpack was used (`event macro 8 7`), using an open bag inside it gave the bag a new
   window at #NextCPos (option on). The likely cause is that opening the backpack makes the server send its
   contents again and the client rebuilds the bag's object, so the old window no longer belongs to it. This was not checked
   in the code.
5. **No memory of a moved window** within a session: a closed backpack reopens by rule 1 or 2, not where it
   was moved. The only saved places are the desktop the client restores once after login.
6. **A script can tell whether the option is on** without reading it: open a new container and compare
   #NextCPosX/Y with what they were. They change only when the option is on.
7. The values live as long as the client process. They start at 32/32.

## 6. Recommendations

**Self-test check 5.08** (`tools/EUOSelfTest/EUOSelfTest.euo`, `sub st_c508`; owned by the parent session).
Its expectation, the new bag at 300,150 after `nextcpos 300 150`, is right with the option on. Run D confirms
it. With the option off it can't pass, and that is the client's setting, not a fault. No HUMAN question is
needed. After the bag has opened, read #NextCPosX/Y:

- 316/166: the option is on. Check that the bag is at 300/150 (PASS or FAIL, as now).
- 300/150, unchanged: the option is off. Record a NOTE ("the client option Offset interface windows ... is off:
  containers open at the top right and #NextCPos is not used"). It may also check Y = 10.
- anything else: FAIL.

The no-staff branch (backpack closed and reopened) follows the same rule. Its comment "only a container shown
for the first time since login" is wrong: it is the option, not the first time. Restoring #NextCPosX/Y
afterwards, as the check does now, is right.

**Site pages** (owner agreed). `variables/nextcposx.md`, `variables/nextcposy.md`, `commands/nextcpos.md`:
containers only, the +16 after each window, the wrap at the edge, the top-right place with the option off, how a
script tells, and the paperdoll example replaced with the backpack. No `changed: true`, what's-new or CHANGELOG
entry, since Reforged's behaviour does not change. Not a known limitation either: it is the client's setting.

**For the #CliXRes investigation** (another session): the client places windows using a game area of
`[$74F8A8]` × `[$74F8AC]` = 2560 × 1532 on the owner's client, while #CliXRes / #CliYRes read 800 × 600 there.

## 7. Open items

- **Case 3's exception** (rule 4): confirm in the code that the backpack's content packet rebuilds the objects
  of the bags in it and closes their windows. Then decide if a script needs to know.
- **Which gumps take the `flag` 0 branch** (top right, Y 0): the `0x24` handler passes 0 for gump numbers 500
  and 501 when the byte `$A5D73F` is 0. Not identified further.
- **client_beta.exe and older builds**: not analysed. The beta table note (`uoclidata.pas`, "a bag opened at X 48 /
  Y 200 after only #NextCPosY was set to 200") fits rule 2.
- **Official servers**: only ModernUO was tried. The placement is all client-side, except case 3's exception.

## 8. How it was done (to repeat on another build)

1. Find the references to `C_NEXTCPOS` and `C_NEXTCPOS + B_NEXTCX` in the exe: a plain search for the
   4-byte addresses in `.text`. On this build there are two functions, the start-up reset and the container routine.
2. Decompile the container routine (REA `procedure_pseudo_code`) and read its default case: the option byte
   test, the +16, the edge test, the constructor's X/Y arguments.
3. Follow the option byte to the options table (name pointer, byte pointer, a third dword) to get its name.
4. Run `tests/tools/NextCPosProbe.euo` with the option off and on (`EUOCli run ... --client 1`). Every line
   should read `rule=OFF` or `rule=ON` (FRONT for the open containers, UNUSED for the paperdoll).
