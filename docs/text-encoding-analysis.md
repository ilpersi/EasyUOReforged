# Text encoding of client strings

Investigation of 2026-11-27, for the decision on script literals vs client text (options A and B). Nothing
in the code was changed. Line numbers are those of `main` at 19655d2 (its `uo/` and `parser/` files are the
same as at 8b5f7c7).

## 1. How it was checked

- **Code**: every entry of `VarNamesR` / `VarNamesRW` (`parser/EuoInterpreter.pas:655-713`, 152 + 35
  variables) was followed through `GetVar` (`:1172-1524`) and `SetVar` (`:1527-1621`) to its reader in
  `uo/`; every registered command (`CmdRegistry.Register`, 68 words) was checked for client text in or out,
  including every `event` (`:4902-4959`) and `exevent` (`:4827-4899`) sub-command and the uo.dll wrapper
  (`uo/uowrap.pas`).
- **Live client**: client 7.0.108.0 (`client_noenc.exe`, UODreams), attached with `EUOCli run --client 1`.
  Read-only probes, raw bytes captured with `logfile write` (which writes bytes unchanged) and with
  `ReadProcessMemory` from Python. With the owner's OK, two client-local writes: `setuotitle` and
  `event sysmessage`, each with `è` as UTF-8 (`C3 A8`) and as one byte (`E8`, from a CP1252 file loaded
  by `call`). The title was restored afterwards; nothing was sent to the server.
- **Windows facts measured**: `GetACP()` = 1252, `GetOEMCP()` = 437; the client window (class
  `Ultima Online`) is a Unicode window (`IsWindowUnicode` = true).
- **Server side**: ModernUO source (`D:\ModernUo\modernuo`), for what the server puts into the fields the
  client keeps as 8-bit text.
- **Client files**: `Cliloc.enu` (decoded with a port of ModernUO's `BwtDecompress.cs`) and `tiledata.mul`
  of the same client.
- **Compiler/RTL**: FPC 3.2.2 and LazUtils sources, for the A/W Windows calls and implicit conversions.

## 2. Summary

| Encoding a script gets | Variables and commands |
|---|---|
| **Latin-1, one byte per letter** (low byte of UTF-16, or the 8-bit text the server sent) | `#Property`, `#Journal` (`scanjournal`, `findjournal`), `#SysMsg`, `#CharName`, `#Shard`, `#ShopItemName` |
| **CP1252** (Windows ANSI, through the `…A` API) | `#CliTitle` and `getuotitle` (read), `setuotitle` and `set #CliTitle` (write), `msg` (write) |
| **UTF-8** | `#BuffName`, `#BuffDesc`, `#GumpReply` (texts), `exevent gumpreply` (write), `event macro` text (write; GUI and EUOCli only) |
| **ASCII in practice** | `#TileName` (one name in 81,920 has a non-ASCII character, stored as UTF-8), `#ContName`, `#GumpName`, `#CliLang`, `#CliVer`, `#CharStatus` |
| **Raw bytes into the client, read back as 8-bit** | `event sysmessage`, `event exmsg`, `exevent renamepet` (the server reads that one as Latin-1) |

Script text itself is UTF-8 (editor, EUOCli files), except `call` and `EUOCli run -`, which keep the file's
bytes (section 6). Latin-1 and CP1252 are the same for `$A0..$FF` (all accented letters); they differ only
in `$80..$9F` (`€ ‚ „ … † ‡ ˆ ‰ Š ‹ Œ Ž ‘ ’ “ ” • – — ˜ ™ š › œ ž Ÿ`).

## 3. Variables that read text from the client

| Variable | Reader (code) | What the client holds | What the script gets | Evidence |
|---|---|---|---|---|
| `#Property` | `TUOEvent.GetFormStr` `uo/uoevents.pas:714-744`, via `EvProperty` `:747` (`PropStr1`, `PropStr2`); `GetVar` 098 | UTF-16LE text with markup | Every 2nd byte (the low byte); bytes below `$20` become spaces; `<BR>` becomes a line break (then `$`); other `<…>` tags removed | Live: client memory holds `57 00 65 00 69 00 …` = `Weight: 6 Stones</CENTER>` (UTF-16LE, with the tag). Identical to 1.5 (`src/uo/uoevents.pas:175`). |
| `#Journal`, `#JColor` | `TUOCmd.ScanJournal` `uo/uocommands.pas:2018-2099`, `GetJournal` `:1988` | Per line: UTF-16LE when the kind field is `$12`, 8-bit otherwise | Kind `$12`: low byte of each character (`:2066`, `:2093`). Other kinds: the bytes as stored | Live, raw nodes: 20 lines kind `$12` (`59 00 6f 00 …` "You see: …"), 5 lines kind `$F` (`57 65 6c …` "Welcome to Ultima Online!"); `event sysmessage` lines are kind `$13`/`$14`, 8-bit. ModernUO sends ASCII messages (0x1C) as **Latin-1** (`OutgoingMessagePackets.cs:224-225`, `SpanWriter.cs:404` = `Encoding.Latin1`) and Unicode ones (0xAE) as UTF-16 (`:231`). |
| `#SysMsg` | `TUOVar.SysMsg` `uo/uovariables.pas:990-1015` | The last system message object: UTF-16 or 8-bit | If the 2nd byte is 0: low bytes (UTF-16 → one byte); otherwise the bytes as stored | Live: after `event sysmessage`, `#SysMsg` returned exactly the bytes written (`… 5f c3 a8` and `… 5f e8`). A UTF-16 text whose first character is above U+00FF is misread as 8-bit (the heuristic is 1.5's). |
| `#CharName` | `TUOVar.CharName` `uo/uovariables.pas:411-423` | 8-bit name (33 bytes read) from the status data | The bytes as stored | ModernUO sends the status name (0x11) as Latin-1, 30 bytes (`OutgoingMobilePackets.cs:510`). Live probe returned N/A (no live sample). |
| `#Shard` | `TUOVar.Shard` `uo/uovariables.pas:760-767` | 8-bit shard name from the server list | The bytes as stored | ModernUO sends the server list (0xA8) names as Latin-1, 32 bytes (`OutgoingAccountPackets.cs:431`). Live: `UODreams`. |
| `#ShopItemName` | `TUOCmd.GetShopInfo` `uo/uocommands.pas:669-671` | `char*` of the shop entry | The bytes as stored | ModernUO sends vendor descriptions (0x74) as Latin-1 (`OutgoingVendorBuyPackets.cs:105`). **Not verified live** (needs a vendor window); where the client keeps the text of an entry sent as a cliloc number is unknown. |
| `#CliTitle` (R/W), `getuotitle` → `#StrRes` | `TUOVar.ReadCliTitle` `uo/uovariables.pas:1387-1392`; `TStdCmd.GetCliTitle` `parser/EuoStdCommands.pas:233-238` | The window title (UTF-16, Windows) | `GetWindowText` = `GetWindowTextA` (FPC `rtl/win/wininc/ascdef.inc:254`): converted to CP1252; characters outside CP1252 become `?` | Live: title `EncTest_U_Ã¨` read back `… 5f c3 a8`; title `EncTest_L_è` read back `… 5f e8`. |
| `#BuffName`, `#BuffDesc` | `TUOCmd.ReadBuffBar` `uo/uocommands.pas:1039-1042`, `ClilocText` `:945-957`, `WideFromRaw` `:704-719` | Template: the client's cliloc table (`char*`); arguments: UTF-16 | UTF-8 (template as stored + arguments through `UTF8Encode`) | `Cliloc.enu`: 122,475 entries, 688 with non-ASCII bytes, all valid UTF-8. Live: client memory holds cliloc 1042824 once, as UTF-8 (`49 e2 80 99 6d …` at `$6EBBCC60`), with no UTF-16 copy. |
| `#TileName` | `TTTBasic.GetTileData` `uo/tiles.pas:649/669/671` (`tile get`) | `tiledata.mul`: 20-byte names (a file, not memory) | The bytes of the file | `tiledata.mul`: 81,920 names, exactly one with non-ASCII bytes, `lion’s_mane_jelly` in UTF-8 (`e2 80 99`). |
| `#ContName` | `TUOCmd.GetCont` `uo/uocommands.pas:1452-1455` | The gump's class name (`char*` constant in `client.exe`) | ASCII, spaces as `_` | Live: `spellbook_gump`. |
| `#GumpName` | `TUOCmd.ReadGump` `uo/uocommands.pas:1299` (`ReadText`, raw 8-bit) | Same class names | ASCII, spaces as `_` (`EuoGumps.pas:44-46`) | Live: 15 gumps, all ASCII (`menubar`, `container_gump`, `new_item_Prop_gump`, `BuffIcons_Gump`, …). |
| `#GumpReply` | `HookedReply` → `EncodeReplyText` `uo/uogumpreply.pas:127-147`; `EuoInterpreter.pas:5389/5406` | The 0xB1 packet the client sends: texts in UTF-16 | UTF-8 (`UTF8Encode`), with `_` / `\` escapes | Code; ModernUO reads those texts as UTF-16 (`GumpSystem.IncomingPackets.cs:136-150`). |
| `#CliLang` | `TUOVar.CliLang` `uo/uovariables.pas:842-860` | 4-byte language code | ASCII (`ENU`…) | Live: empty on 7.0.108.0 (its language offset; unrelated to encoding). |
| `#CliVer` | `UOSel.Ver` | Version from the executable | ASCII digits | Live: `7.0.108.0`. |
| `#CharStatus` | `TUOVar.CharStatus` `uo/uovariables.pas:378-398` | Flag bits | Letters `A..P` built by Reforged | Code. |

## 4. Commands that read client text

| Command | What it reads | Encoding |
|---|---|---|
| `scanjournal` | `#Journal`, `#JColor` (section 3) | Latin-1 |
| `findjournal` | Compares the script's texts with journal lines: `UpperCase` (ASCII only) + `Pos` (`parser/EuoJournalSearch.pas:71-73`) | Script text (UTF-8) against Latin-1 |
| `deletejournal` | No text | — |
| `event property` | `#Property` | Latin-1 |
| `getuotitle` | `#StrRes` = window title | CP1252 |
| `getshopinfo` | `#ShopItemName` | 8-bit as stored (Latin-1 from ModernUO; not verified live) |
| `tile get` | `#TileName` | File bytes (ASCII; one UTF-8 name) |
| `scanbuffs` | `#BuffName`, `#BuffDesc` | UTF-8 |
| `scangumps` | `#GumpName` | ASCII |
| `ignorecont {name}` | Compares a script word with container names (`uo/uovariables.pas:295`) | ASCII names |
| `waitfor` | Any expression, so any of the above | As the variables |

The other client commands read or send numbers only: `finditem`, `moveitem`, `path`, `click`, `key` (key
names), `move`, `contpos`, `nextcpos`, `target`, `chooseskill` (skill names mapped to numbers), `hideitem`,
`ignoreitem`, `setshopitem`, `savepix`, `cmppix`. The remaining words never touch the client: `pause halt
stop wait stopcd playcd set if else goto onhotkey shutdown display deletevar sleep terminate uoxl sound str
namespace menu return gosub sub call exit for send while until break continue linespercycle sql waitfor log
logfile timer list`, and `execute`, which passes its text to Windows through `ShellExecuteExA`
(`parser/EuoStdCommands.pas:142`), so as CP1252.

## 5. Commands and variables that write text to the client

| Command | How the text is written | What reaches the client | Evidence |
|---|---|---|---|
| `setuotitle`, `set #CliTitle` | `SetWindowText` = `SetWindowTextA` (`EuoStdCommands.pas:241`, `uovariables.pas:1394-1397`; FPC `ascdef.inc:253`) | Each byte read as CP1252 | Live: UTF-8 `è` gave the title `EncTest_U_Ã¨` (U+00C3 U+00A8); the one byte `E8` gave `EncTest_L_è` (U+00E8). |
| `msg` | `PostMessage` = `PostMessageA`, one `WM_CHAR` per byte (`uo/uocommands.pas:2520-2526`; FPC `ascdef.inc:187`) | The client window is Unicode, so Windows converts each byte from CP1252: UTF-8 `è` becomes `Ã` `¨` | ACP and `IsWindowUnicode` measured live. **Not run** (it would speak to the server). The client then sends 0xAD in UTF-16 (ModernUO `IncomingMessagePackets.cs:113-119`). |
| `event sysmessage` | The bytes + `#0` into the event cave (`uo/uoevents.pas:931-958`) | 8-bit message; the journal keeps it 8-bit (kind `$13`/`$14`) | Live: journal nodes `45 6e … 5f c3 a8` and `… 5f e8`; `#SysMsg` reads them back unchanged. How the client draws `$80..$FF` was not captured (the screen grab showed another window on top). |
| `event exmsg` | Same as `sysmessage` (`uo/uoevents.pas:665-674`) | Same | Code; not run. |
| `event macro {n} {m} {text}` | `StringToWideChar` (`uo/uoevents.pas:1026`) — an implicit conversion from the **process** code page | GUI and EUOCli: UTF-8 → UTF-16, correct for UTF-8 literals; a one-byte `E8` is invalid UTF-8 and becomes U+FFFD. uo.dll: CP1252 → UTF-16 (as 1.5) | LazUtils sets the process code page to UTF-8 (`fpcadds.pas:74`, on by default: `lazutils_defines.inc:8-9`); the GUI and EUOCli link LCL/LazUtils, uo.dll links only `uoengine`/`uocommon`/FCL (`uo.lpi`, `uoengine.lpk`, `uocommon.lpk`); FPC `ustrings.inc:1034`, `astrings.inc:64-71`, `syswin.inc:592-613`. **Not run** (macro 1 = Say reaches the server). |
| `exevent renamepet` | The bytes padded to 30 in packet 0x75 (`uo/uoevents.pas:1545-1556`) | The server reads Latin-1 (ModernUO `IncomingMobilePackets.cs:39` `ReadLatin1Safe`): UTF-8 `è` becomes `Ã¨` | Code; not run. |
| `exevent gumpreply` | `DecodeReplyText` = `UTF8Decode` → UTF-16 in 0xB1 (`uo/uogumpreply.pas:149-180`) | Correct for UTF-8; a one-byte `E8` is invalid UTF-8 and becomes `?` (FPC `UNICODE_INVALID`=63, `ustrings.inc:1808`) | Code; not run. |
| `exevent skilllock` / `statlock` / `event skilllock` | Names mapped to numbers | No text | Code. |
| uo.dll `Msg`, `SysMessage`, `ExMsg`, `Macro`, `RenamePet`, `CliTitle` | The same `uo/` functions with the caller's bytes (`uo/uowrap.pas:427, 525, 534, 543, 544, 553, 641`) | As above, but `Macro` converts from CP1252 | Code. |

## 6. Script-side text, for the comparison

| Source | Encoding |
|---|---|
| Editor (`CSyn.Text`), files opened in the editor, `EUOCli run/check/mcp` files | UTF-8 (`LoadScriptFileAsUTF8` converts a CP1252 file; the editor saves UTF-8) |
| `call` sub-scripts | The file's bytes (`EuoInterpreter.pas:2422`, FPC `TStrings.LoadFromFile`) |
| `EUOCli run -` | The stdin bytes |
| `menu get` → `#MenuRes`, `list frommenu`, Watches / breakpoint expressions | UTF-8 (LCL) |
| `#CurPath`, file names | UTF-8 (LCL RTL) |

## 7. Every other variable

All carry numbers or ASCII that Reforged builds, so the encoding question does not apply:

- **Numbers**: `#CliCnt #CliNr #SysTime #Random #CharPosX #CharPosY #CharPosZ #CharDir #Sex #Str #MaxWeight
  #Dex #Int #Hits #MaxHits #Stamina #MaxStam #Mana #MaxMana #Gold #Weight #MaxStats #AR #Followers #MaxFol
  #FR #CR #PR #ER #Luck #MaxDmg #MinDmg #TP #CliLogged #CursKind #EnemyHits #LLiftedKind #Skill #SkillCap
  #CursorX #CursorY #FindX #FindY #FindZ #FindKind #FindStack #FindRep #FindCol #FindCnt #FindDist #PixCol
  #JColor #ShopCurPos #ShopCnt #ShopItemMax #ShopItemPrice #TileCnt #TileType #TileZ #JIndex #ContSizeX
  #ContSizeY #ContHP #BuffCnt #BuffID #BuffCliloc #BuffTime #BuffBarOpen #SqlCnt #SqlChanges #SqlLastID
  #PathCnt #PathX #PathY #PathZ #PathDir #FindLayer #JFound #GumpCnt #GumpPosX #GumpPosY #GumpSizeX
  #GumpSizeY #GumpMin #GumpReplyCnt #SCnt #SCnt2 #LShard #ContPosX #ContPosY #NextCPosX #NextCPosY #TargCurs
  #CliXRes #CliYRes #CliLeft #CliTop #LSpell #LSkill #LTargetKind #LTargetTile #LTargetX #LTargetY #LTargetZ
  #FindIndex #LPC #SysMsgCol #BuffIndex #GumpIndex`
- **Base-26 IDs** (letters only): `#CharID #ContKind #ContID #ContType #EnemyID #LObjectType #LLiftedID
  #LLiftedType #FindID #FindType #FindBagID #ShopItemType #ShopItemID #BackpackID #CharType #MountID
  #MountType #GumpKind #GumpArt #GumpObjID #GumpSerial #GumpTypeID #LTargetID #LHandID #RHandID #LObjectID`
- **Fixed words or Reforged-built ASCII**: `#Time #Date #OSVer #CharGhost #ContSize #SkillLock #NSName
  #NSType #True #False #Spc #Smc #Dot #EUOVer #Opts #ReforgedVer #TileFlags #FindMod #DispRes #PathState
  #WaitRes #MoveRes #GumpReplyRes #LogRes #SendRes #SendCode #TimerRes #ListRes #MenuButton #SendHeader`
- **Not from the client**: `#Result #StrRes` (script), `#MenuRes` (LCL, UTF-8), `#SqlRes` (SQLite, UTF-8),
  `#SendReply` (HTTP body as received), `#CurPath` (UTF-8).

## 8. Characters above U+00FF in UTF-16 sources

The low-byte readers (`#Property`, `#Journal` kind `$12`, `#SysMsg`) keep only the low byte. In the
client's English cliloc table, 1,122 of the 1,190 non-ASCII characters are above U+00FF, for example:
`’` U+2019 (×626) → `$19`, `—` U+2014 → `$14`, `•` U+2022 → `$22` (`"`), `…` U+2026 → `$26` (`&`),
`♫` U+266B → `$6B` (`k`), `“ ”` → `$1C`/`$1D`. In `#Property` the bytes below `$20` become spaces; in
`#Journal` they stay. Scripts written for 1.5 may match these replacement characters (for example `&` for
`…`). A conversion of the one-byte text to UTF-8 keeps them as they are; reading the full UTF-16 instead
would change them.

## 9. Not verified

- How the client draws `$80..$FF` from `event sysmessage` / `exmsg` (bytes verified, drawing not captured).
- `msg`, `event macro`, `exevent renamepet`, `exevent gumpreply` with accented text: code and server source
  only, because they reach the server.
- `#ShopItemName` and `#CharName` with accented text (no vendor window; `#CharName` read N/A in the probe).
- Shards other than ModernUO may send the 8-bit fields in another code page.
- Other client builds: the readers are the same code for every build; the live data came from 7.0.108.0.

## 10. What option B changed (2026-11-27)

The owner chose option B: the interpreter converts at its edges, `uo/` and uo.dll stay as they are.
Helpers in `parser/EuoTextEncoding.pas`.

| Where | Before | Now |
|---|---|---|
| `#Property`, `#Journal`, `#SysMsg`, `#CharName`, `#Shard`, `#ShopItemName` (`GetVar`), `findjournal`'s lines (`JournalEntryUtf8`) | one byte per letter (Latin-1) | `Latin1ToUtf8`: UTF-8 |
| `#CliTitle`, `getuotitle`, `setuotitle` (`TStdCmd.GetCliTitle`/`SetCliTitle`) | `GetWindowTextA`/`SetWindowTextA` (CP1252) | `GetWindowTextW`/`SetWindowTextW`, UTF-8 |
| `msg` (`TStdCmd.TypeText`) | `PostMessageA` per byte | `PostMessageW` per UTF-16 unit |
| `execute` (`TStdCmd.Execute`) | `ShellExecuteExA` | `ShellExecuteExW` |
| `display` (`TStdCmd.Display`) | `MessageBoxA` (showed UTF-8 `è` as `Ã¨`) | `MessageBoxW` |
| `event SysMessage`, `event ExMsg`, `exevent RenamePet` | the script's bytes | `Utf8ToLatin1`: one byte per letter, `?` above U+00FF |
| `call` (`CallProc`), `EUOCli run -` | the file's / stdin's bytes | `ScriptTextToUtf8` (the editor's rule) |
| `str len/pos/left/right/mid/del/ins/count/trim` | bytes | letters (`LetterCount`/`LetterPos`/`LetterCopy`/`LetterDelete`/`LetterInsert`); byte-identical results on text with no byte from `$80` up |
| `¦¦` | only the bytes A6 A6 | also UTF-8 C2 A6 C2 A6 (`BROKEN_BAR_OR_UTF8`) |

Unchanged on purpose: `event macro` (`StringToWideChar` already decodes UTF-8 in the GUI and EUOCli),
`exevent gumpreply`, `#BuffName`/`#BuffDesc`, `#GumpReply`, `#TileName`, `#ContName`/`#GumpName`, uo.dll.

Checked before building: a model of the old `str` code reproduced all 84,408 results of the real
`EUOCli.exe` (random and exhaustive cases), and the letter version gave the same results on every
one-byte, CP1252 and ASCII case; the PSL top 50 use no changed path in a way that breaks. In the suite,
`TEuoTextEncodingTests.TestLettersMatchTheRtlOnOneByteText` keeps that comparison against the RTL routines.
`display` was not in the plan: it showed the same `Ã¨` and would have started showing it for client
text too, so it got the same Unicode call.
