unit uoclidata;

{
  Ported from the original Delphi 7 uo\uoclidata.pas, then RE-ARCHITECTED during the
  Lazarus/FPC migration from a flat, 222-exact-string-version table (221 ClientList rows,
  each independently restating all ~87 constants in its own SysVarNNNNN array) into a
  milestone/delta model: one small array per point where the resolved state actually
  changed, applied cumulatively at runtime.

  WHY: the flat table duplicated every unchanged constant across every one of 140 distinct
  per-version tables (12,167 lines of transplanted data), and adding a brand-new client
  version meant hand-authoring a full ~87-field table even when only a handful of fields
  actually differ from the nearest known neighbor. Every value below still traces back to
  exactly that same flat, hand-verified data -- nothing here is independently re-derived.
  It was converted mechanically by Lazarus\tests\tools\DeriveCstDbMilestones.ps1, which
  walked all 222 versions in the flat table's OWN existing (hand-curated) order and kept
  only the fields that changed relative to the immediately preceding (older) version --
  and which re-resolves every one of those 222 versions purely from its own generated
  model and diffs the result field-for-field against the flat table before ever emitting
  a line of the Pascal below (see that script's own header comment for the full algorithm
  and why the file's OWN version ordering is trusted over any derived string comparator).
  The real, independent proof of correctness is unchanged: FPCUnit's
  TestAllVersionsAgainstGoldenFixture (Lazarus\tests\CstDbTests.pas) still checks the real,
  running TCstDB against tests\fixtures\uoclidata_golden.json, itself extracted straight
  from the untouched original Delphi 7 source by VerifyCstDbData.ps1 -- that fixture and
  that cross-check are completely independent of this file's internal data shape.

  NEW capability added alongside the re-architecture (the second half of what was asked
  for): TCstDB.Update can now also take a live process handle and, when given one, layers
  a DYNAMIC RUNTIME SCAN on top of the milestone-resolved state -- signature-scanning the
  attached client's own memory (via common\access.pas's existing SearchMem/ReadMem, the
  same primitive uoscanver.pas and tools\EUOUpdater already use) for VARIABLES/EVENTS
  fields whose absolute address is realistically the same shape across a whole client
  generation but genuinely moves on almost every single build. Post-6062's table covers
  37 of the 42 scannable C_*/E_* fields (everything tools\EUOUpdater's own scan-string
  file has a pattern for, mechanically validated against a live client rather than
  hand-transcribed -- see ScannerTable_Post6062's own comment for the full story,
  including why it started as a 2-entry starter set and grew from there once a real
  not-yet-milestoned client made the case for filling it out); Pre-6062 is still an empty
  stub, left for whenever a period-correct older client is available to validate against.

  The class SHAPE (introduced earlier in this same migration, unchanged by this redesign):
  one Values: array[TConstantNames] of Cardinal instead of the original's 82 separately-
  named fields+getters. Every one of the 87 public getter functions keeps its exact
  original name and signature, so every external call site (uovariables.pas,
  uocommands.pas, uoevents.pas, tiles.pas) needed zero changes for this redesign either.

  PRESERVED quirk, now implemented via a two-pass lookup (see TCstDB.Update's own header
  comment for why two passes, and ExactMatchMilestoneIndex/FloorMilestoneIndex below):
  Update resolves ALL 87 values to fresh data in exactly two cases -- CliVer = '' or CliVer
  names a version this file has ever seen. If CliVer is NON-EMPTY, does not match any known
  version, AND doesn't parse-and-floor to at least the oldest known milestone, Update exits
  immediately WITHOUT touching any of the 87 fields, leaving whatever was previously
  resolved in place -- reproduced exactly, do not "helpfully" reset Values to zero on that
  path. New in this redesign: a non-empty, unrecognized string that DOES parse and floor to
  a real milestone (i.e. a genuinely new future client version newer than anything in this
  file, or falling in a not-yet-explicitly-known gap) now resolves against the nearest
  applicable milestone instead of being treated as unrecognized -- this is the actual new
  capability the milestone redesign was asked to provide.

  SupportedCli (the flat space-joined-string client-picker gate consumed by
  uoselector.pas's TimerProc) is REMOVED by this redesign and replaced with
  CliVerSupported(CliVer): Boolean, which wraps this same two-pass logic as a boolean,
  mutating nothing -- per an explicit decision confirmed with the user, this switches
  uoselector.pas's window filter from "exact string match against the 222 known versions"
  to "floor-resolves to a real milestone," so a not-yet-explicitly-listed future client
  build newer than the newest known milestone becomes automatically selectable.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, access;

type
  TConstantNames = (
    /// VARIABLES /////////
    C_BLOCKINFO,C_CLILOGGED,C_CLIXRES,C_ENEMYID,C_SHARDPOS,C_NEXTCPOS,
    C_SYSMSG,C_CONTPOS,C_ENEMYHITS,C_LHANDID,C_CHARDIR,C_TARGETCNT,
    C_CURSORKIND,C_TARGETCURS,C_CLILEFT,C_CHARPTR,C_LLIFTEDID,
    C_LSHARD,C_POPUPID,C_JOURNALPTR,C_SKILLCAPS,C_SKILLLOCK,C_SKILLSPOS,
    /// BASE CONSTANTS ////
    B_TARGPROC,B_CHARSTATUS,B_ITEMID,B_ITEMTYPE,
    B_ITEMSTACK,B_STATNAME,B_STATWEIGHT,B_STATAR,B_STATML,B_CONTSIZEX,
    B_CONTX,B_CONTITEM,B_CONTNEXT,B_ENEMYHPVAL,B_SHOPCURRENT,
    B_SHOPNEXT,B_BILLFIRST,B_SKILLDIST,B_SYSMSGSTR,B_EVSKILLPAR,
    B_LLIFTEDTYPE,B_LLIFTEDKIND,B_LANG,B_TITHE,B_FINDREP,
    B_SHOPPRICE,B_GUMPPTR,B_ITEMSLOT,B_MEMBASE,B_PACKETVER,B_LTARGTILE,
    B_LTARGX,B_STAT1,
    // Added alongside F_JOURNALDIRECT (see FEATURES section below and milestone 0's
    // comment) -- new-layout journal-node field offsets, only meaningful when
    // F_JOURNALDIRECT=1. Zero (unused) for every other version.
    B_JCOL,B_JKIND,B_JNEXTPTR,
    /// EVENTS ////////////
    E_REDIR,E_OLDDIR,E_EXMSGADDR,
    E_ITEMPROPID,E_ITEMNAMEADDR,E_ITEMPROPADDR,E_ITEMCHECKADDR,
    E_ITEMREQADDR,E_PATHFINDADDR,E_SLEEPADDR,E_DRAGADDR,
    E_SYSMSGADDR,E_MACROADDR,E_SKILLLOCKADDR,E_SENDPACKET,
    E_SENDLEN,E_SENDECX,E_CONTTOP,E_STATBAR,
    /// FEATURES //////////
    F_EXTSTAT,F_EVPROPERTY,F_MACROMAP,F_EXCHARSTATC, F_PACKETVER,
    F_PATHFINDVER,F_FLAGS,
    // Added during the original Lazarus migration (not present in the original Delphi 7
    // source) -- see milestone 0's comment below for why this exists: on client 7.0.108.0
    // the system-message object embeds its text directly at B_SYSMSGSTR rather than
    // holding a further pointer there, so TUOVar.SysMsg must skip one level of pointer
    // indirection when this is set. Defaults to 0 (old two-level-indirection behavior,
    // unchanged) for every one of the ~220 pre-existing client versions.
    F_SYSMSGDIRECT,
    // Added alongside F_SYSMSGDIRECT (see milestone 0's comment below) -- on client
    // 7.0.108.0 the journal (chat/system-message history) is a doubly-linked chain of
    // objects that embed their own text directly, rather than the old fixed-size TItem
    // record (Pos/Col/Kind/Fill/Next) TUOCmd.ScanJournal otherwise walks. B_JCOL/B_JKIND/
    // B_JNEXTPTR give the new per-object field offsets; this flag tells ScanJournal to use
    // them and read text inline instead of indirecting through Item.Pos. Defaults to 0
    // (old behavior, unchanged) for every one of the ~220 pre-existing versions.
    F_JOURNALDIRECT,
    /// END ///////////////
    LISTEND
  );

  TSysVarList = packed record
    Expr : TConstantNames;
    case Integer of
      1: (Val : Cardinal);
      2: (Ptr : Pointer);
  end;

  TSysVarListArray = array[0..1023] of TSysVarList;
  PSysVarListArray = ^TSysVarListArray;

  // One per point in this file's version history where the resolved state actually
  // changed relative to every OLDER milestone -- NOT one per known client version (that's
  // VersionIndex, below). List is LISTEND-terminated and holds only the fields that
  // changed at this milestone; see TCstDB.Update's comment for the cumulative-apply
  // algorithm that turns a sequence of these back into a full resolved state.
  TMilestoneEntry = packed record
    NormVer : String;             // zero-padded sort/floor-lookup key, e.g. '007.000.108.000'
                                   // -- internal only, never shown to the user or compared
                                   // against uoscanver's raw ScanVer output directly.
    List    : PSysVarListArray;
  end;

  // One per known client version string, EXACTLY as its own file-version resource / this
  // project's own uoscanver.ScanVer produces it (e.g. '5.0.1d1', '7.0.108.0') -- i.e. the
  // literal replacement for the old flat ClientList's role, just pointing at a milestone
  // INDEX instead of directly at a full per-version table.
  TVersionIndexEntry = packed record
    Cli       : String;
    Milestone : Integer;          // index into the Milestones array below
  end;

  // Dynamic runtime memory-scanning pattern entry -- structurally aligned with this
  // project's own existing tools\EUOUpdater scan-string convention (Joker=$11 always,
  // Pattern hex-decoded, '11' byte-pairs are wildcards), not the (buggy -- see
  // ScannerTable_Post6062's own comment) reference implementation's mismatched Joker
  // literal. LISTEND-terminated to match this file's own sentinel convention.
  TScannerEntry = packed record
    Joker      : Byte;             // wildcard byte value SearchMem should ignore -- always $11
    Unused     : array[1..3] of Byte;
    AddOffset1 : Integer;          // applied to the raw match address BEFORE the Mode step
    Mode       : Integer;          // 1=direct address, 2=call/jmp relative-displacement
                                    //   resolve (target + [target] + 4), 3=pointer dereference
    AddOffset2 : Integer;          // applied AFTER the Mode step
    Expr       : TConstantNames;   // LISTEND terminates the table
    Pattern    : PAnsiChar;        // hex-encoded signature bytes
  end;

  TCstDB = class(TObject)
  private
    CS     : TMultiReadExclusiveWriteSynchronizer;
    Values : array[TConstantNames] of Cardinal;
    procedure ScanMemory(PHnd : Cardinal; const NormVer : String);
  public
    constructor Create;
    procedure   Free;
    procedure   Update(CliVer : String; PHnd : Cardinal = 0);
    ///////////////////////////////////////
    function    BLOCKINFO       : Cardinal;
    function    CLILOGGED       : Cardinal;
    function    CLIXRES         : Cardinal;
    function    ENEMYID         : Cardinal;
    function    SHARDPOS        : Cardinal;
    function    NEXTCPOS        : Cardinal;
    function    SYSMSG          : Cardinal;
    function    CONTPOS         : Cardinal;
    function    ENEMYHITS       : Cardinal;
    function    LHANDID         : Cardinal;
    function    CHARDIR         : Cardinal;
    function    TARGETCNT       : Cardinal;
    function    CURSORKIND      : Cardinal;
    function    TARGETCURS      : Cardinal;
    function    CLILEFT         : Cardinal;
    function    CHARPTR         : Cardinal;
    function    LLIFTEDID       : Cardinal;
    function    LSHARD          : Cardinal;
    function    POPUPID         : Cardinal;
    function    JOURNALPTR      : Cardinal;
    function    SKILLCAPS       : Cardinal;
    function    SKILLLOCK       : Cardinal;
    function    SKILLSPOS       : Cardinal;
    ///////////////////////////////////////
    function    BTARGPROC       : Cardinal;
    function    BCHARSTATUS     : Cardinal;
    function    BITEMID         : Cardinal;
    function    BITEMTYPE       : Cardinal;
    function    BITEMSTACK      : Cardinal;
    function    BSTATNAME       : Cardinal;
    function    BSTATWEIGHT     : Cardinal;
    function    BSTATAR         : Cardinal;
    function    BSTATML         : Cardinal;
    function    BCONTSIZEX      : Cardinal;
    function    BCONTX          : Cardinal;
    function    BCONTITEM       : Cardinal;
    function    BCONTNEXT       : Cardinal;
    function    BENEMYHPVAL     : Cardinal;
    function    BSHOPCURRENT    : Cardinal;
    function    BSHOPNEXT       : Cardinal;
    function    BBILLFIRST      : Cardinal;
    function    BSKILLDIST      : Cardinal;
    function    BSYSMSGSTR      : Cardinal;
    function    BEVSKILLPAR     : Cardinal;
    function    BLLIFTEDTYPE    : Cardinal;
    function    BLLIFTEDKIND    : Cardinal;
    function    BLANG           : Cardinal;
    function    BTITHE          : Cardinal;
    function    BFINDREP        : Cardinal;
    function    BSHOPPRICE      : Cardinal;
    function    BGUMPPTR        : Cardinal;
    function    BITEMSLOT       : Cardinal;
    function    BMEMBASE        : Cardinal;
    function    BPACKETVER      : Cardinal;
    function    BLTARGTILE      : Cardinal;
    function    BLTARGX         : Cardinal;
    function    BSTAT1          : Cardinal;
    function    BJCOL           : Cardinal;
    function    BJKIND          : Cardinal;
    function    BJNEXTPTR       : Cardinal;
    ///////////////////////////////////////
    function    EREDIR          : Cardinal;
    function    EOLDDIR         : Cardinal;
    function    EEXMSGADDR      : Cardinal;
    function    EITEMPROPID     : Cardinal;
    function    EITEMNAMEADDR   : Cardinal;
    function    EITEMPROPADDR   : Cardinal;
    function    EITEMCHECKADDR  : Cardinal;
    function    EITEMREQADDR    : Cardinal;
    function    EPATHFINDADDR   : Cardinal;
    function    ESLEEPADDR      : Cardinal;
    function    EDRAGADDR       : Cardinal;
    function    ESYSMSGADDR     : Cardinal;
    function    EMACROADDR      : Cardinal;
    function    ESKILLLOCKADDR  : Cardinal;
    function    ESENDPACKET     : Cardinal;
    function    ESENDLEN        : Cardinal;
    function    ESENDECX        : Cardinal;
    function    ECONTTOP        : Cardinal;
    function    ESTATBAR        : Cardinal;
    ///////////////////////////////////////
    function    FEXTSTAT        : Cardinal;
    function    FEVPROPERTY     : Cardinal;
    function    FMACROMAP       : Cardinal;
    function    FEXCHARSTATC    : Cardinal;
    function    FPACKETVER      : Cardinal;
    function    FPATHFINDVER    : Cardinal;
    function    FFLAGS          : Cardinal;
    function    FSYSMSGDIRECT   : Cardinal;
    function    FJOURNALDIRECT  : Cardinal;
  end;

// Replaces the old flat SupportedCli string -- see this unit's header comment and
// TCstDB.Update's for the two-pass exact-match-then-floor-lookup logic this wraps.
// Mutates nothing; safe to call with no TCstDB instance in scope at all.
function CliVerSupported(const CliVer : String) : Boolean;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

implementation

////////////////////////////////////////////////////////////////////////////////
// vvv MILESTONE/DELTA DATA -- mechanically derived, see this file's header comment vvv
////////////////////////////////////////////////////////////////////////////////

const

////////////////////////////////////////////////////////////////////////////////
// Generated by Lazarus\tests\tools\DeriveCstDbMilestones.ps1 -- DO NOT hand-edit
// the VALUES below; re-run the script against an updated flat table instead, or
// (for a genuinely NEW client version with no flat-table precedent) hand-author a
// new milestone following this same shape -- see docs\adding-client-support.md.
// Each SysVarMSn array holds only the fields that changed at that milestone,
// relative to the cumulative state of every OLDER milestone (index n+1..High).
// See TCstDB.Update's header comment for the exact cumulative-apply algorithm.
////////////////////////////////////////////////////////////////////////////////

// Milestone 0 -- first introduced at client '7.0.108.0' (normalized '007.000.108.000')
//
// Added during the Lazarus/FPC migration (not present in the original Delphi 7 source)
// to support Ultima Online Stygian Abyss client 7.0.108.0, which the flat table's then-
// newest entry (7.0.47.0) predates by roughly 60 patch versions and which SupportedCli
// was therefore filtering out entirely, so EasyUO/this port never even offered it as a
// client to attach to.
//
// C_*/E_* values (absolute addresses) below were obtained by running
// tools\EUOUpdater\"EUO Updtr Strings 6062 and newer.txt"'s byte-signature scans against
// a live, running instance of this exact client build -- the officially-documented
// EUOUpdater workflow (see that folder's readme.txt), not guessed or derived from the
// newer prebuilt easyuo.exe the user also provided (no disassembler was available at the
// time; the live-client scan turned out to be the more direct and more reliable source
// of truth anyway, and is the tool this codebase already provides for exactly this
// situation).
//
// One field could not be resolved by that scan directly, and its fix eventually turned
// out to be a genuine STRUCTURAL change, not just a wrong address:
//
// C_SYSMSG: its pattern in "6062 and newer.txt" was not found in this build. Two earlier
// attempts to patch around that got the address wrong (first an arithmetic guess from
// C_CONTPOS: $008DAC38; then a value cross-validated against a reference implementation
// the user pointed at, D:\Dropbox\Delphi\EasyUOGemini\uo\uoclidata.pas -- a parallel/AI-
// authored rewrite of this file, not otherwise part of this project -- which gave
// $008DAC34 and matched that file's other 8 scan results exactly). Both were reported by
// the user as still not working, which is what finally justified live disassembly
// (python3 + capstone, attached to the running client via ReadProcessMemory, no static
// analysis of any prebuilt exe) instead of another byte-pattern guess:
//
//   - $008DAC34 IS correct as the list-head pointer (C_SYSMSG itself) -- disassembling
//     the code at 0x0048D460 (the shared "add message" routine, reached from both
//     E_SYSMSGADDR and E_EXMSGADDR) shows it unconditionally does
//     `mov edx,[0x008DAC34]` / `... / mov [0x008DAC34],ebp` to read and update this
//     exact address as a singleton object pointer -- unambiguous ground truth, not
//     inference.
//   - But B_SYSMSGSTR (copied forward as $100, the old-layout offset to a SECOND pointer
//     that itself points at the text) is what was actually still wrong. The same
//     disassembly shows this build's message object copies the ANSI text with a plain
//     byte-loop directly into the object at offset +0x800 (`lea eax,[ebp+0x800]` feeding
//     call 0x639D50, a strcpy-shaped routine) -- there is no second pointer to indirect
//     through any more in this client build.
//
// Fixed on two sides: B_SYSMSGSTR here is set to the real embedded-text offset ($800,
// NOT the $100 old-layout default), and a new FEATURES flag, F_SYSMSGDIRECT, was added
// (0 for every older client version, 1 only here) so TUOVar.SysMsg (uovariables.pas) can
// skip the now-nonexistent second pointer dereference on this build without disturbing
// any older one.
//
// C_TARGETCNT: not covered by any scan string in the file at all, but every other
// version in this entire table also carries $00000000 for it, so this is very likely a
// vestigial/unused constant rather than a real gap.
//
// JOURNAL (reported by the user after the SYSMSG fix shipped: "#JIndex never increases,
// #JColor looks wrong"): C_JOURNALPTR itself ($01E220CC) turned out to be perfectly
// correct as an address -- live disassembly of the code that reads it (0x0050E077,
// `mov edx,[0x1E220CC]`) confirmed it. What's wrong is that TUOCmd.ScanJournal's
// hardcoded TItem record (Pos/Col/Kind/Fill[19]/Next, 32 bytes, walked via a raw memcpy)
// no longer matches this client's actual journal-node layout at all.
//
// The real layout, walked live via python3+capstone attached through ReadProcessMemory
// (an actual chain of in-game chat/system messages, including a real test chat line,
// was read back correctly this way -- not inferred):
//   - Text is embedded directly at the node's own offset 0, up to 0x800 bytes, exactly
//     like C_SYSMSG's object -- no separate Item.Pos pointer to indirect through.
//   - +0x800 (B_JCOL): Cardinal hue/color value.
//   - +0x804 (B_JKIND): Cardinal font id, doubling as the old code's encoding selector --
//     still compared against exactly $12 to mean "unicode, de-interleave like the
//     original Kind=$12 check did"; this matched every live-observed player-typed
//     (unicode) line, while server/cliloc-templated (ansi) lines carried a different
//     value here.
//   - +0x818 (B_JNEXTPTR): pointer to the NEXT-OLDER node -- what ScanJournal now walks,
//     replacing the old record's implicit `Next` field at its fixed +28 offset.
// F_JOURNALDIRECT (0 for every older version, 1 only here) tells ScanJournal
// (uocommands.pas) to use B_JCOL/B_JKIND/B_JNEXTPTR and read text inline instead of the
// old fixed TItem record shape.
//
// The BASE CONSTANTS (B_*) and FEATURES (F_*) fields not called out above are copied
// forward from 7.0.47.0's resolved state (this table only lists what changed relative
// to that -- i.e. everything below IS the actual delta) -- a reasonable, standard
// assumption, not a verified fact for every field.
SysVarMS0 : array[0..42] of TSysVarList = (
  (Expr: B_JCOL; Val: $00000800),
  (Expr: B_JKIND; Val: $00000804),
  (Expr: B_JNEXTPTR; Val: $00000818),
  (Expr: C_BLOCKINFO; Val: $005A5A70),
  (Expr: C_CHARDIR; Val: $00A00490),
  (Expr: C_CHARPTR; Val: $00A568C4),
  (Expr: C_CLILEFT; Val: $00A05C30),
  (Expr: C_CLILOGGED; Val: $0071B0A8),
  (Expr: C_CLIXRES; Val: $0071B8EC),
  (Expr: C_CONTPOS; Val: $008DAC58),
  (Expr: C_CURSORKIND; Val: $00A05BA5),
  (Expr: C_ENEMYHITS; Val: $009A2E4C),
  (Expr: C_ENEMYID; Val: $008D41A4),
  (Expr: C_JOURNALPTR; Val: $01E220CC),
  (Expr: C_LHANDID; Val: $009FF5D4),
  (Expr: C_LLIFTEDID; Val: $00A56910),
  (Expr: C_LSHARD; Val: $00A5AF68),
  (Expr: C_NEXTCPOS; Val: $008DA1A4),
  (Expr: C_POPUPID; Val: $00A5B0DC),
  (Expr: C_SHARDPOS; Val: $008D9FF8),
  (Expr: C_SKILLCAPS; Val: $01EC8B18),
  (Expr: C_SKILLLOCK; Val: $01EC8ADC),
  (Expr: C_SKILLSPOS; Val: $01EC8B90),
  (Expr: C_SYSMSG; Val: $008DAC34),
  (Expr: C_TARGETCURS; Val: $00A05C04),
  (Expr: E_CONTTOP; Val: $004E8CF0),
  (Expr: E_DRAGADDR; Val: $005BCBD0),
  (Expr: E_EXMSGADDR; Val: $005BB470),
  (Expr: E_ITEMCHECKADDR; Val: $0043F0A0),
  (Expr: E_ITEMNAMEADDR; Val: $00589A60),
  (Expr: E_ITEMPROPADDR; Val: $00589960),
  (Expr: E_ITEMPROPID; Val: $009F736C),
  (Expr: E_ITEMREQADDR; Val: $00440470),
  (Expr: E_MACROADDR; Val: $00594DD0),
  (Expr: E_OLDDIR; Val: $00639C90),
  (Expr: E_PATHFINDADDR; Val: $00511C59),
  (Expr: E_REDIR; Val: $005AE21D),
  (Expr: E_SENDPACKET; Val: $00462880),
  (Expr: E_SLEEPADDR; Val: $006A00F4),
  (Expr: E_STATBAR; Val: $005564F0),
  (Expr: E_SYSMSGADDR; Val: $005EAC50),
  (Expr: F_JOURNALDIRECT; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 1 -- first introduced at client '7.0.99.1' (normalized '007.000.099.001')
//
// Added during the Lazarus/FPC migration to support Ultima Online client 7.0.99.1, which
// sits in the gap between 7.0.47.0 and 7.0.108.0 and was previously unsupported.
// Requested by the user, who provided a downloaded (never launched) copy of
// client_7.0.99.1_TOL.exe -- its embedded version resource was checked directly
// (GetFileVersionInfoW) and confirms it is genuinely 7.0.99.1, not just a filename claim.
//
// All C_*/E_* values below were derived by running tools\EUOUpdater\"EUO Updtr Strings
// 6062 and newer.txt" against this exact file -- via STATIC analysis of the PE file's own
// section table rather than a live running process (this client was never launched).
// This is sound specifically because this whole client generation loads at a fixed,
// non-relocated ImageBase=$400000 (the same reason SearchMem's own hardcoded
// $400000-$650000 scan window works against a live process at all): the on-disk section
// bytes at their mapped virtual addresses are exactly what a live process's memory would
// show at those same addresses. Every single scan line matched -- no N/A results, unlike
// 7.0.108.0's original {SYSMSG} pattern.
//
// C_TARGETCNT: not covered by any scan string, same as every other version in this
// table -- $00000000, per the same "likely vestigial" reasoning as milestone 0's comment.
//
// B_SYSMSGSTR/F_SYSMSGDIRECT: NOT left at the old-layout $100/0 default. The
// {SYSMSGSTR_CHECK} scan reads back $00000800 on this build too -- confirmed via the same
// static-analysis method as the C_*/E_* values above (re-deriving the same byte pattern
// milestone 0's live disassembly found, and validating it as the ONLY match in the
// scanned image). This means the direct-embed system-message layout was ALREADY in place
// at least as early as 7.0.99.1 -- it was not something 7.0.108.0 itself introduced,
// contrary to what was assumed when that entry was first written. (That in turn means
// 7.0.47.0's own B_SYSMSGSTR=$100 was never actually verified either -- it's the
// inherited legacy default, not a confirmed fact for that build specifically.)
//
// JOURNAL LAYOUT: genuinely investigated, deliberately left as the OLD (pre-7.0.108.0)
// fixed-record behavior here (F_JOURNALDIRECT omitted below, defaulting to 0) -- NOT
// because nothing changed, but because static analysis alone could not resolve this with
// the same confidence as everything else in this block, and shipping a guess seemed
// worse than an honest, flagged gap:
//   - Live disassembly of the code walking from C_JOURNALPTR shows a genuine doubly-
//     linked node walk with text embedded inline at the node's own start -- structurally
//     the SAME kind of change milestone 0's F_JOURNALDIRECT=1 layout uses.
//   - But the confirmed "next" pointer offset here is +$814, not milestone 0's +$818 --
//     a real, different offset, not a typo.
//   - The ANSI-vs-Unicode decoding field sits at +$80C (not milestone 0's +$804) and the
//     compiled code branches on whether it's zero/nonzero, not on whether it equals
//     exactly $12 the way ScanJournal's hardcoded check (and milestone 0's B_JKIND field)
//     assumes. Whether the actual VALUE for a real Unicode message still happens to be
//     $12 could not be confirmed without observing real traffic against a file that was
//     never run.
//   - No code reading a distinct "message color" value could be found anywhere near this
//     node-walking routine, so B_JCOL has no supporting evidence either way here.
// Net effect: #JIndex/#JColor/#JournalGetText are very likely INCORRECT for this specific
// client, same as they silently were for 7.0.108.0 before its own dedicated
// investigation -- a known, flagged gap. Resolving it needs the same live-disassembly
// approach milestone 0 used, against an actually-running 7.0.99.1 client.
//
// Every other field not called out above: copied forward from 7.0.47.0's resolved state
// (unchanged, so it does NOT appear in this delta at all) -- a reasonable-but-unverified
// default, not a proven fact.
SysVarMS1 : array[0..40] of TSysVarList = (
  (Expr: B_SYSMSGSTR; Val: $00000800),
  (Expr: C_BLOCKINFO; Val: $0059C050),
  (Expr: C_CHARDIR; Val: $00AB52A0),
  (Expr: C_CHARPTR; Val: $00AFB6D4),
  (Expr: C_CLILEFT; Val: $00ABAA40),
  (Expr: C_CLILOGGED; Val: $007100A0),
  (Expr: C_CLIXRES; Val: $007108E4),
  (Expr: C_CONTPOS; Val: $0098FAA8),
  (Expr: C_CURSORKIND; Val: $00ABA9B5),
  (Expr: C_ENEMYHITS; Val: $00A57C9C),
  (Expr: C_ENEMYID; Val: $00988FF4),
  (Expr: C_JOURNALPTR; Val: $01EC70CC),
  (Expr: C_LHANDID; Val: $00AB43E4),
  (Expr: C_LLIFTEDID; Val: $00AFB720),
  (Expr: C_LSHARD; Val: $00AFFD78),
  (Expr: C_NEXTCPOS; Val: $0098EFF4),
  (Expr: C_POPUPID; Val: $00AFFEEC),
  (Expr: C_SHARDPOS; Val: $0098EE48),
  (Expr: C_SKILLCAPS; Val: $01F6DB00),
  (Expr: C_SKILLLOCK; Val: $01F6DAC4),
  (Expr: C_SKILLSPOS; Val: $01F6DB78),
  (Expr: C_SYSMSG; Val: $0098FA84),
  (Expr: C_TARGETCURS; Val: $00ABAA14),
  (Expr: E_CONTTOP; Val: $004E1F00),
  (Expr: E_DRAGADDR; Val: $005B31A0),
  (Expr: E_EXMSGADDR; Val: $005B1A40),
  (Expr: E_ITEMCHECKADDR; Val: $0043DD50),
  (Expr: E_ITEMNAMEADDR; Val: $00581450),
  (Expr: E_ITEMPROPADDR; Val: $00581350),
  (Expr: E_ITEMPROPID; Val: $00AAC18C),
  (Expr: E_ITEMREQADDR; Val: $0043F120),
  (Expr: E_MACROADDR; Val: $0058AAC0),
  (Expr: E_OLDDIR; Val: $00631120),
  (Expr: E_PATHFINDADDR; Val: $0050AE19),
  (Expr: E_REDIR; Val: $005A47ED),
  (Expr: E_SENDPACKET; Val: $0045D4D0),
  (Expr: E_SLEEPADDR; Val: $006960EC),
  (Expr: E_STATBAR; Val: $0054F420),
  (Expr: E_SYSMSGADDR; Val: $005E1080),
  (Expr: F_SYSMSGDIRECT; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 2 -- first introduced at client '7.0.47.0' (normalized '007.000.047.000')
SysVarMS2 : array[0..11] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005901B0),
  (Expr: E_DRAGADDR; Val: $005A72F0),
  (Expr: E_EXMSGADDR; Val: $005A5BB0),
  (Expr: E_ITEMNAMEADDR; Val: $00576A70),
  (Expr: E_ITEMPROPADDR; Val: $00576970),
  (Expr: E_MACROADDR; Val: $0057ED70),
  (Expr: E_OLDDIR; Val: $0061DFB0),
  (Expr: E_PATHFINDADDR; Val: $005030D9),
  (Expr: E_REDIR; Val: $00598C3D),
  (Expr: E_STATBAR; Val: $00546640),
  (Expr: E_SYSMSGADDR; Val: $005D3320),
  (Expr: LISTEND; Val: 0)
);

// Milestone 3 -- first introduced at client '7.0.46.24' (normalized '007.000.046.024')
SysVarMS3 : array[0..35] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00590160),
  (Expr: C_CHARDIR; Val: $00A96E78),
  (Expr: C_CHARPTR; Val: $00ADC2BC),
  (Expr: C_CLILEFT; Val: $00A9B628),
  (Expr: C_CLILOGGED; Val: $006F7C4C),
  (Expr: C_CLIXRES; Val: $006F81F4),
  (Expr: C_CONTPOS; Val: $0097598C),
  (Expr: C_CURSORKIND; Val: $00A9B59D),
  (Expr: C_ENEMYHITS; Val: $00A3DB74),
  (Expr: C_ENEMYID; Val: $0096EEF4),
  (Expr: C_JOURNALPTR; Val: $00B18C58),
  (Expr: C_LHANDID; Val: $00A960BC),
  (Expr: C_LLIFTEDID; Val: $00ADC308),
  (Expr: C_LSHARD; Val: $00AE0954),
  (Expr: C_NEXTCPOS; Val: $00974EE4),
  (Expr: C_POPUPID; Val: $00AE0AC4),
  (Expr: C_SHARDPOS; Val: $00974D48),
  (Expr: C_SKILLCAPS; Val: $00B5AF48),
  (Expr: C_SKILLLOCK; Val: $00B5AF0C),
  (Expr: C_SKILLSPOS; Val: $00B5AFC0),
  (Expr: C_SYSMSG; Val: $0097596C),
  (Expr: C_TARGETCURS; Val: $00A9B5FC),
  (Expr: E_CONTTOP; Val: $004DC1D0),
  (Expr: E_DRAGADDR; Val: $005A72A0),
  (Expr: E_EXMSGADDR; Val: $005A5B60),
  (Expr: E_ITEMNAMEADDR; Val: $00576A20),
  (Expr: E_ITEMPROPADDR; Val: $00576920),
  (Expr: E_ITEMPROPID; Val: $00A9202C),
  (Expr: E_MACROADDR; Val: $0057ED20),
  (Expr: E_OLDDIR; Val: $0061DF60),
  (Expr: E_PATHFINDADDR; Val: $00503089),
  (Expr: E_REDIR; Val: $00598BED),
  (Expr: E_SLEEPADDR; Val: $006820EC),
  (Expr: E_STATBAR; Val: $005465F0),
  (Expr: E_SYSMSGADDR; Val: $005D32D0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 4 -- first introduced at client '7.0.46.0' (normalized '007.000.046.000')
SysVarMS4 : array[0..1] of TSysVarList = (
  (Expr: E_OLDDIR; Val: $0061DE70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 5 -- first introduced at client '7.0.45.89' (normalized '007.000.045.089')
SysVarMS5 : array[0..11] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005900C0),
  (Expr: E_DRAGADDR; Val: $005A7200),
  (Expr: E_EXMSGADDR; Val: $005A5AC0),
  (Expr: E_ITEMNAMEADDR; Val: $00576980),
  (Expr: E_ITEMPROPADDR; Val: $00576880),
  (Expr: E_MACROADDR; Val: $0057EC80),
  (Expr: E_OLDDIR; Val: $0061DE40),
  (Expr: E_PATHFINDADDR; Val: $00502FE9),
  (Expr: E_REDIR; Val: $00598B4D),
  (Expr: E_STATBAR; Val: $00546550),
  (Expr: E_SYSMSGADDR; Val: $005D31E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 6 -- first introduced at client '7.0.45.77' (normalized '007.000.045.077')
SysVarMS6 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00590040),
  (Expr: E_CONTTOP; Val: $004DC130),
  (Expr: E_DRAGADDR; Val: $005A7180),
  (Expr: E_EXMSGADDR; Val: $005A5A40),
  (Expr: E_ITEMNAMEADDR; Val: $00576900),
  (Expr: E_ITEMPROPADDR; Val: $00576800),
  (Expr: E_MACROADDR; Val: $0057EC00),
  (Expr: E_OLDDIR; Val: $0061DDC0),
  (Expr: E_PATHFINDADDR; Val: $00502F69),
  (Expr: E_REDIR; Val: $00598ACD),
  (Expr: E_STATBAR; Val: $005464D0),
  (Expr: E_SYSMSGADDR; Val: $005D3160),
  (Expr: LISTEND; Val: 0)
);

// Milestone 7 -- first introduced at client '7.0.45.65' (normalized '007.000.045.065')
SysVarMS7 : array[0..38] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058FFF0),
  (Expr: C_CHARDIR; Val: $00A95E78),
  (Expr: C_CHARPTR; Val: $00ADB2BC),
  (Expr: C_CLILEFT; Val: $00A9A628),
  (Expr: C_CLILOGGED; Val: $006F6C4C),
  (Expr: C_CLIXRES; Val: $006F71F4),
  (Expr: C_CONTPOS; Val: $0097498C),
  (Expr: C_CURSORKIND; Val: $00A9A59D),
  (Expr: C_ENEMYHITS; Val: $00A3CB74),
  (Expr: C_ENEMYID; Val: $0096DEF4),
  (Expr: C_JOURNALPTR; Val: $00B17C58),
  (Expr: C_LHANDID; Val: $00A950BC),
  (Expr: C_LLIFTEDID; Val: $00ADB308),
  (Expr: C_LSHARD; Val: $00ADF954),
  (Expr: C_NEXTCPOS; Val: $00973EE4),
  (Expr: C_POPUPID; Val: $00ADFAC4),
  (Expr: C_SHARDPOS; Val: $00973D48),
  (Expr: C_SKILLCAPS; Val: $00B59F48),
  (Expr: C_SKILLLOCK; Val: $00B59F0C),
  (Expr: C_SKILLSPOS; Val: $00B59FC0),
  (Expr: C_SYSMSG; Val: $0097496C),
  (Expr: C_TARGETCURS; Val: $00A9A5FC),
  (Expr: E_CONTTOP; Val: $004DC0E0),
  (Expr: E_DRAGADDR; Val: $005A7130),
  (Expr: E_EXMSGADDR; Val: $005A59F0),
  (Expr: E_ITEMCHECKADDR; Val: $0043D990),
  (Expr: E_ITEMNAMEADDR; Val: $005768B0),
  (Expr: E_ITEMPROPADDR; Val: $005767B0),
  (Expr: E_ITEMPROPID; Val: $00A9102C),
  (Expr: E_ITEMREQADDR; Val: $0043ECF0),
  (Expr: E_MACROADDR; Val: $0057EBB0),
  (Expr: E_OLDDIR; Val: $0061DD60),
  (Expr: E_PATHFINDADDR; Val: $00502F19),
  (Expr: E_REDIR; Val: $00598A7D),
  (Expr: E_SENDPACKET; Val: $0045CC20),
  (Expr: E_SLEEPADDR; Val: $006810EC),
  (Expr: E_STATBAR; Val: $00546480),
  (Expr: E_SYSMSGADDR; Val: $005D3100),
  (Expr: LISTEND; Val: 0)
);

// Milestone 8 -- first introduced at client '7.0.40.10' (normalized '007.000.040.010')
SysVarMS8 : array[0..32] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058DD20),
  (Expr: C_CHARDIR; Val: $00A774C0),
  (Expr: C_CHARPTR; Val: $00ABC8F4),
  (Expr: C_CLILEFT; Val: $00A7BC70),
  (Expr: C_CONTPOS; Val: $00955FAC),
  (Expr: C_CURSORKIND; Val: $00A7BBE5),
  (Expr: C_ENEMYHITS; Val: $00A1E194),
  (Expr: C_ENEMYID; Val: $0094F514),
  (Expr: C_JOURNALPTR; Val: $00AF9290),
  (Expr: C_LHANDID; Val: $00A76704),
  (Expr: C_LLIFTEDID; Val: $00ABC940),
  (Expr: C_LSHARD; Val: $00AC0F8C),
  (Expr: C_NEXTCPOS; Val: $00955504),
  (Expr: C_POPUPID; Val: $00AC10FC),
  (Expr: C_SHARDPOS; Val: $00955368),
  (Expr: C_SKILLCAPS; Val: $00B3B580),
  (Expr: C_SKILLLOCK; Val: $00B3B544),
  (Expr: C_SKILLSPOS; Val: $00B3B5F8),
  (Expr: C_SYSMSG; Val: $00955F8C),
  (Expr: C_TARGETCURS; Val: $00A7BC44),
  (Expr: E_CONTTOP; Val: $004DA040),
  (Expr: E_DRAGADDR; Val: $005A36B0),
  (Expr: E_EXMSGADDR; Val: $005A1F50),
  (Expr: E_ITEMNAMEADDR; Val: $005745E0),
  (Expr: E_ITEMPROPADDR; Val: $005744E0),
  (Expr: E_ITEMPROPID; Val: $00A72674),
  (Expr: E_MACROADDR; Val: $0057C8E0),
  (Expr: E_OLDDIR; Val: $00607900),
  (Expr: E_PATHFINDADDR; Val: $00500E79),
  (Expr: E_REDIR; Val: $005967AD),
  (Expr: E_STATBAR; Val: $00544340),
  (Expr: E_SYSMSGADDR; Val: $005CE900),
  (Expr: LISTEND; Val: 0)
);

// Milestone 9 -- first introduced at client '7.0.38.0' (normalized '007.000.038.000')
SysVarMS9 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058DDB0),
  (Expr: E_CONTTOP; Val: $004DA0D0),
  (Expr: E_DRAGADDR; Val: $005A3740),
  (Expr: E_EXMSGADDR; Val: $005A1FE0),
  (Expr: E_ITEMNAMEADDR; Val: $00574670),
  (Expr: E_ITEMPROPADDR; Val: $00574570),
  (Expr: E_MACROADDR; Val: $0057C970),
  (Expr: E_OLDDIR; Val: $00607950),
  (Expr: E_PATHFINDADDR; Val: $00500F09),
  (Expr: E_REDIR; Val: $0059683D),
  (Expr: E_STATBAR; Val: $005443D0),
  (Expr: E_SYSMSGADDR; Val: $005CE950),
  (Expr: LISTEND; Val: 0)
);

// Milestone 10 -- first introduced at client '7.0.35.23' (normalized '007.000.035.023')
SysVarMS10 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058DD60),
  (Expr: E_CONTTOP; Val: $004DA080),
  (Expr: E_DRAGADDR; Val: $005A36F0),
  (Expr: E_EXMSGADDR; Val: $005A1F90),
  (Expr: E_ITEMNAMEADDR; Val: $00574620),
  (Expr: E_ITEMPROPADDR; Val: $00574520),
  (Expr: E_MACROADDR; Val: $0057C920),
  (Expr: E_OLDDIR; Val: $00607900),
  (Expr: E_PATHFINDADDR; Val: $00500EB9),
  (Expr: E_REDIR; Val: $005967ED),
  (Expr: E_STATBAR; Val: $00544380),
  (Expr: E_SYSMSGADDR; Val: $005CE900),
  (Expr: LISTEND; Val: 0)
);

// Milestone 11 -- first introduced at client '7.0.35.3' (normalized '007.000.035.003')
SysVarMS11 : array[0..17] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058DC30),
  (Expr: C_CLILOGGED; Val: $006D8BDC),
  (Expr: C_CLIXRES; Val: $006D9184),
  (Expr: E_CONTTOP; Val: $004D9F90),
  (Expr: E_DRAGADDR; Val: $005A35C0),
  (Expr: E_EXMSGADDR; Val: $005A1E60),
  (Expr: E_ITEMCHECKADDR; Val: $0043CD90),
  (Expr: E_ITEMNAMEADDR; Val: $005744F0),
  (Expr: E_ITEMPROPADDR; Val: $005743F0),
  (Expr: E_ITEMREQADDR; Val: $0043DFB0),
  (Expr: E_MACROADDR; Val: $0057C7F0),
  (Expr: E_OLDDIR; Val: $00607740),
  (Expr: E_PATHFINDADDR; Val: $00500D89),
  (Expr: E_REDIR; Val: $005966BD),
  (Expr: E_SENDPACKET; Val: $0045BF50),
  (Expr: E_STATBAR; Val: $00544250),
  (Expr: E_SYSMSGADDR; Val: $005CE740),
  (Expr: LISTEND; Val: 0)
);

// Milestone 12 -- first introduced at client '7.0.34.23' (normalized '007.000.034.023')
SysVarMS12 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00591210),
  (Expr: E_CONTTOP; Val: $004DD570),
  (Expr: E_DRAGADDR; Val: $005A6BA0),
  (Expr: E_EXMSGADDR; Val: $005A5440),
  (Expr: E_ITEMNAMEADDR; Val: $00577AD0),
  (Expr: E_ITEMPROPADDR; Val: $005779D0),
  (Expr: E_MACROADDR; Val: $0057FDD0),
  (Expr: E_OLDDIR; Val: $00607720),
  (Expr: E_PATHFINDADDR; Val: $00504369),
  (Expr: E_REDIR; Val: $00599C9D),
  (Expr: E_STATBAR; Val: $00547830),
  (Expr: E_SYSMSGADDR; Val: $005D1D20),
  (Expr: LISTEND; Val: 0)
);

// Milestone 13 -- first introduced at client '7.0.34.15' (normalized '007.000.034.015')
SysVarMS13 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005911D0),
  (Expr: E_CONTTOP; Val: $004DD4F0),
  (Expr: E_DRAGADDR; Val: $005A6B60),
  (Expr: E_EXMSGADDR; Val: $005A5400),
  (Expr: E_ITEMNAMEADDR; Val: $00577A70),
  (Expr: E_ITEMPROPADDR; Val: $00577970),
  (Expr: E_MACROADDR; Val: $0057FD70),
  (Expr: E_OLDDIR; Val: $006076E0),
  (Expr: E_PATHFINDADDR; Val: $005042E9),
  (Expr: E_REDIR; Val: $00599C5D),
  (Expr: E_STATBAR; Val: $005477D0),
  (Expr: E_SYSMSGADDR; Val: $005D1CE0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 14 -- first introduced at client '7.0.34.6' (normalized '007.000.034.006')
SysVarMS14 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00591170),
  (Expr: E_CONTTOP; Val: $004DD490),
  (Expr: E_DRAGADDR; Val: $005A6B00),
  (Expr: E_EXMSGADDR; Val: $005A53A0),
  (Expr: E_ITEMNAMEADDR; Val: $00577A10),
  (Expr: E_ITEMPROPADDR; Val: $00577910),
  (Expr: E_MACROADDR; Val: $0057FD10),
  (Expr: E_OLDDIR; Val: $00607680),
  (Expr: E_PATHFINDADDR; Val: $00504289),
  (Expr: E_REDIR; Val: $00599BFD),
  (Expr: E_STATBAR; Val: $00547770),
  (Expr: E_SYSMSGADDR; Val: $005D1C80),
  (Expr: LISTEND; Val: 0)
);

// Milestone 15 -- first introduced at client '7.0.34.2' (normalized '007.000.034.002')
SysVarMS15 : array[0..33] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00591120),
  (Expr: C_CHARDIR; Val: $00A774A0),
  (Expr: C_CHARPTR; Val: $00ABC8D4),
  (Expr: C_CLILEFT; Val: $00A7BC50),
  (Expr: C_CONTPOS; Val: $00955F8C),
  (Expr: C_CURSORKIND; Val: $00A7BBC5),
  (Expr: C_ENEMYHITS; Val: $00A1E174),
  (Expr: C_ENEMYID; Val: $0094F4F4),
  (Expr: C_JOURNALPTR; Val: $00AF9270),
  (Expr: C_LHANDID; Val: $00A766E4),
  (Expr: C_LLIFTEDID; Val: $00ABC920),
  (Expr: C_LSHARD; Val: $00AC0F6C),
  (Expr: C_NEXTCPOS; Val: $009554E4),
  (Expr: C_POPUPID; Val: $00AC10DC),
  (Expr: C_SHARDPOS; Val: $00955348),
  (Expr: C_SKILLCAPS; Val: $00B3B560),
  (Expr: C_SKILLLOCK; Val: $00B3B524),
  (Expr: C_SKILLSPOS; Val: $00B3B5D8),
  (Expr: C_SYSMSG; Val: $00955F6C),
  (Expr: C_TARGETCURS; Val: $00A7BC24),
  (Expr: E_CONTTOP; Val: $004DD440),
  (Expr: E_DRAGADDR; Val: $005A6AB0),
  (Expr: E_EXMSGADDR; Val: $005A5350),
  (Expr: E_ITEMNAMEADDR; Val: $005779C0),
  (Expr: E_ITEMPROPADDR; Val: $005778C0),
  (Expr: E_ITEMPROPID; Val: $00A72654),
  (Expr: E_MACROADDR; Val: $0057FCC0),
  (Expr: E_OLDDIR; Val: $00607630),
  (Expr: E_PATHFINDADDR; Val: $00504239),
  (Expr: E_REDIR; Val: $00599BAD),
  (Expr: E_SENDPACKET; Val: $0045F530),
  (Expr: E_STATBAR; Val: $00547720),
  (Expr: E_SYSMSGADDR; Val: $005D1C30),
  (Expr: LISTEND; Val: 0)
);

// Milestone 16 -- first introduced at client '7.0.33.1' (normalized '007.000.033.001')
SysVarMS16 : array[0..13] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005910C0),
  (Expr: E_CONTTOP; Val: $004DD420),
  (Expr: E_DRAGADDR; Val: $005A6A50),
  (Expr: E_EXMSGADDR; Val: $005A52F0),
  (Expr: E_ITEMNAMEADDR; Val: $00577980),
  (Expr: E_ITEMPROPADDR; Val: $00577880),
  (Expr: E_MACROADDR; Val: $0057FC80),
  (Expr: E_OLDDIR; Val: $006075D0),
  (Expr: E_PATHFINDADDR; Val: $00504219),
  (Expr: E_REDIR; Val: $00599B4D),
  (Expr: E_SENDPACKET; Val: $0045F510),
  (Expr: E_STATBAR; Val: $005476E0),
  (Expr: E_SYSMSGADDR; Val: $005D1BD0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 17 -- first introduced at client '7.0.32.11' (normalized '007.000.032.011')
SysVarMS17 : array[0..33] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00591060),
  (Expr: C_CHARDIR; Val: $00A77400),
  (Expr: C_CHARPTR; Val: $00ABC834),
  (Expr: C_CLILEFT; Val: $00A7BBB0),
  (Expr: C_CONTPOS; Val: $00955EEC),
  (Expr: C_CURSORKIND; Val: $00A7BB25),
  (Expr: C_ENEMYHITS; Val: $00A1E0D4),
  (Expr: C_ENEMYID; Val: $0094F454),
  (Expr: C_JOURNALPTR; Val: $00AF91D0),
  (Expr: C_LHANDID; Val: $00A76644),
  (Expr: C_LLIFTEDID; Val: $00ABC880),
  (Expr: C_LSHARD; Val: $00AC0ECC),
  (Expr: C_NEXTCPOS; Val: $00955444),
  (Expr: C_POPUPID; Val: $00AC103C),
  (Expr: C_SHARDPOS; Val: $009552A8),
  (Expr: C_SKILLCAPS; Val: $00B3B4C0),
  (Expr: C_SKILLLOCK; Val: $00B3B484),
  (Expr: C_SKILLSPOS; Val: $00B3B538),
  (Expr: C_SYSMSG; Val: $00955ECC),
  (Expr: C_TARGETCURS; Val: $00A7BB84),
  (Expr: E_CONTTOP; Val: $004DD410),
  (Expr: E_DRAGADDR; Val: $005A69F0),
  (Expr: E_EXMSGADDR; Val: $005A5290),
  (Expr: E_ITEMNAMEADDR; Val: $00577920),
  (Expr: E_ITEMPROPADDR; Val: $00577820),
  (Expr: E_ITEMPROPID; Val: $00A725B4),
  (Expr: E_MACROADDR; Val: $0057FC20),
  (Expr: E_OLDDIR; Val: $00607570),
  (Expr: E_PATHFINDADDR; Val: $005041B9),
  (Expr: E_REDIR; Val: $00599AED),
  (Expr: E_SENDPACKET; Val: $0045F4E0),
  (Expr: E_STATBAR; Val: $00547680),
  (Expr: E_SYSMSGADDR; Val: $005D1B70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 18 -- first introduced at client '7.0.31.0' (normalized '007.000.031.000')
SysVarMS18 : array[0..32] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00591050),
  (Expr: C_CHARDIR; Val: $00A773E0),
  (Expr: C_CHARPTR; Val: $00ABC814),
  (Expr: C_CLILEFT; Val: $00A7BB90),
  (Expr: C_CONTPOS; Val: $00955ECC),
  (Expr: C_CURSORKIND; Val: $00A7BB05),
  (Expr: C_ENEMYHITS; Val: $00A1E0B4),
  (Expr: C_ENEMYID; Val: $0094F434),
  (Expr: C_JOURNALPTR; Val: $00AF91B0),
  (Expr: C_LHANDID; Val: $00A76624),
  (Expr: C_LLIFTEDID; Val: $00ABC860),
  (Expr: C_LSHARD; Val: $00AC0EAC),
  (Expr: C_NEXTCPOS; Val: $00955424),
  (Expr: C_POPUPID; Val: $00AC101C),
  (Expr: C_SHARDPOS; Val: $00955288),
  (Expr: C_SKILLCAPS; Val: $00B3B4A0),
  (Expr: C_SKILLLOCK; Val: $00B3B464),
  (Expr: C_SKILLSPOS; Val: $00B3B518),
  (Expr: C_SYSMSG; Val: $00955EAC),
  (Expr: C_TARGETCURS; Val: $00A7BB64),
  (Expr: E_CONTTOP; Val: $004DD3F0),
  (Expr: E_DRAGADDR; Val: $005A69E0),
  (Expr: E_EXMSGADDR; Val: $005A5280),
  (Expr: E_ITEMNAMEADDR; Val: $00577900),
  (Expr: E_ITEMPROPADDR; Val: $00577800),
  (Expr: E_ITEMPROPID; Val: $00A72594),
  (Expr: E_MACROADDR; Val: $0057FC10),
  (Expr: E_OLDDIR; Val: $00607450),
  (Expr: E_PATHFINDADDR; Val: $00504199),
  (Expr: E_REDIR; Val: $00599ADD),
  (Expr: E_STATBAR; Val: $00547660),
  (Expr: E_SYSMSGADDR; Val: $005D1A50),
  (Expr: LISTEND; Val: 0)
);

// Milestone 19 -- first introduced at client '7.0.30.1' (normalized '007.000.030.001')
SysVarMS19 : array[0..33] of TSysVarList = (
  (Expr: B_STAT1; Val: $0000001C),
  (Expr: B_STATAR; Val: $00000038),
  (Expr: B_STATML; Val: $00000004),
  (Expr: B_TITHE; Val: $00000084),
  (Expr: C_BLOCKINFO; Val: $00590E60),
  (Expr: C_CHARDIR; Val: $00A772A0),
  (Expr: C_CHARPTR; Val: $00ABC6D4),
  (Expr: C_CLILEFT; Val: $00A7BA50),
  (Expr: C_CONTPOS; Val: $00955D8C),
  (Expr: C_CURSORKIND; Val: $00A7B9C5),
  (Expr: C_ENEMYHITS; Val: $00A1DF74),
  (Expr: C_JOURNALPTR; Val: $00AF9070),
  (Expr: C_LHANDID; Val: $00A764E4),
  (Expr: C_LLIFTEDID; Val: $00ABC720),
  (Expr: C_LSHARD; Val: $00AC0D6C),
  (Expr: C_POPUPID; Val: $00AC0EDC),
  (Expr: C_SKILLCAPS; Val: $00B3B360),
  (Expr: C_SKILLLOCK; Val: $00B3B324),
  (Expr: C_SKILLSPOS; Val: $00B3B3D8),
  (Expr: C_SYSMSG; Val: $00955D6C),
  (Expr: C_TARGETCURS; Val: $00A7BA24),
  (Expr: E_CONTTOP; Val: $004DD350),
  (Expr: E_DRAGADDR; Val: $005A67F0),
  (Expr: E_EXMSGADDR; Val: $005A5090),
  (Expr: E_ITEMNAMEADDR; Val: $00577710),
  (Expr: E_ITEMPROPADDR; Val: $00577610),
  (Expr: E_ITEMPROPID; Val: $00A72454),
  (Expr: E_MACROADDR; Val: $0057FA20),
  (Expr: E_OLDDIR; Val: $00607260),
  (Expr: E_PATHFINDADDR; Val: $005040F9),
  (Expr: E_REDIR; Val: $005998ED),
  (Expr: E_STATBAR; Val: $00547470),
  (Expr: E_SYSMSGADDR; Val: $005D1860),
  (Expr: LISTEND; Val: 0)
);

// Milestone 20 -- first introduced at client '7.0.29.2' (normalized '007.000.029.002')
SysVarMS20 : array[0..12] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005907E0),
  (Expr: E_CONTTOP; Val: $004DD180),
  (Expr: E_DRAGADDR; Val: $005A6170),
  (Expr: E_EXMSGADDR; Val: $005A4A10),
  (Expr: E_ITEMNAMEADDR; Val: $00577090),
  (Expr: E_ITEMPROPADDR; Val: $00576F90),
  (Expr: E_MACROADDR; Val: $0057F3A0),
  (Expr: E_OLDDIR; Val: $00606BE0),
  (Expr: E_PATHFINDADDR; Val: $00503F29),
  (Expr: E_REDIR; Val: $0059926D),
  (Expr: E_STATBAR; Val: $00546DF0),
  (Expr: E_SYSMSGADDR; Val: $005D11E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 21 -- first introduced at client '7.0.27.66' (normalized '007.000.027.066')
SysVarMS21 : array[0..35] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00590630),
  (Expr: C_CHARDIR; Val: $00A77280),
  (Expr: C_CHARPTR; Val: $00ABC6B4),
  (Expr: C_CLILEFT; Val: $00A7BA30),
  (Expr: C_CLILOGGED; Val: $006DA24C),
  (Expr: C_CLIXRES; Val: $006DA7F4),
  (Expr: C_CONTPOS; Val: $00955D6C),
  (Expr: C_CURSORKIND; Val: $00A7B9A5),
  (Expr: C_ENEMYHITS; Val: $00A1DF54),
  (Expr: C_ENEMYID; Val: $0094F2F4),
  (Expr: C_JOURNALPTR; Val: $00AF9050),
  (Expr: C_LHANDID; Val: $00A764C4),
  (Expr: C_LLIFTEDID; Val: $00ABC700),
  (Expr: C_LSHARD; Val: $00AC0D4C),
  (Expr: C_NEXTCPOS; Val: $009552E4),
  (Expr: C_POPUPID; Val: $00AC0EBC),
  (Expr: C_SHARDPOS; Val: $00955148),
  (Expr: C_SKILLCAPS; Val: $00B3B340),
  (Expr: C_SKILLLOCK; Val: $00B3B304),
  (Expr: C_SKILLSPOS; Val: $00B3B3B8),
  (Expr: C_SYSMSG; Val: $00955D4C),
  (Expr: C_TARGETCURS; Val: $00A7BA04),
  (Expr: E_CONTTOP; Val: $004DCFD0),
  (Expr: E_DRAGADDR; Val: $005A5FC0),
  (Expr: E_EXMSGADDR; Val: $005A4860),
  (Expr: E_ITEMNAMEADDR; Val: $00576EE0),
  (Expr: E_ITEMPROPADDR; Val: $00576DE0),
  (Expr: E_ITEMPROPID; Val: $00A72434),
  (Expr: E_MACROADDR; Val: $0057F1F0),
  (Expr: E_OLDDIR; Val: $00606A30),
  (Expr: E_PATHFINDADDR; Val: $00503D79),
  (Expr: E_REDIR; Val: $005990BD),
  (Expr: E_SLEEPADDR; Val: $006680EC),
  (Expr: E_STATBAR; Val: $00546C40),
  (Expr: E_SYSMSGADDR; Val: $005D1030),
  (Expr: LISTEND; Val: 0)
);

// Milestone 22 -- first introduced at client '7.0.27.9' (normalized '007.000.027.009')
SysVarMS22 : array[0..20] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A76280),
  (Expr: C_CHARPTR; Val: $00ABB6B4),
  (Expr: C_CLILEFT; Val: $00A7AA30),
  (Expr: C_CONTPOS; Val: $00954D6C),
  (Expr: C_CURSORKIND; Val: $00A7A9A5),
  (Expr: C_ENEMYHITS; Val: $00A1CF54),
  (Expr: C_ENEMYID; Val: $0094E2F4),
  (Expr: C_JOURNALPTR; Val: $00AF8050),
  (Expr: C_LHANDID; Val: $00A754C4),
  (Expr: C_LLIFTEDID; Val: $00ABB700),
  (Expr: C_LSHARD; Val: $00ABFD4C),
  (Expr: C_NEXTCPOS; Val: $009542E4),
  (Expr: C_POPUPID; Val: $00ABFEBC),
  (Expr: C_SHARDPOS; Val: $00954148),
  (Expr: C_SKILLCAPS; Val: $00B3A340),
  (Expr: C_SKILLLOCK; Val: $00B3A304),
  (Expr: C_SKILLSPOS; Val: $00B3A3B8),
  (Expr: C_SYSMSG; Val: $00954D4C),
  (Expr: C_TARGETCURS; Val: $00A7AA04),
  (Expr: E_ITEMPROPID; Val: $00A71434),
  (Expr: LISTEND; Val: 0)
);

// Milestone 23 -- first introduced at client '7.0.27.7' (normalized '007.000.027.007')
SysVarMS23 : array[0..13] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00590440),
  (Expr: E_CONTTOP; Val: $004DCFB0),
  (Expr: E_DRAGADDR; Val: $005A5DB0),
  (Expr: E_EXMSGADDR; Val: $005A4650),
  (Expr: E_ITEMNAMEADDR; Val: $00576CF0),
  (Expr: E_ITEMPROPADDR; Val: $00576BF0),
  (Expr: E_MACROADDR; Val: $0057F000),
  (Expr: E_OLDDIR; Val: $00606820),
  (Expr: E_PATHFINDADDR; Val: $00503D59),
  (Expr: E_REDIR; Val: $00598ECD),
  (Expr: E_SENDPACKET; Val: $0045F4C0),
  (Expr: E_STATBAR; Val: $00546C20),
  (Expr: E_SYSMSGADDR; Val: $005D0E20),
  (Expr: LISTEND; Val: 0)
);

// Milestone 24 -- first introduced at client '7.0.27.5' (normalized '007.000.027.005')
SysVarMS24 : array[0..10] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005903F0),
  (Expr: E_DRAGADDR; Val: $005A5D60),
  (Expr: E_EXMSGADDR; Val: $005A4600),
  (Expr: E_ITEMNAMEADDR; Val: $00576CA0),
  (Expr: E_ITEMPROPADDR; Val: $00576BA0),
  (Expr: E_MACROADDR; Val: $0057EFB0),
  (Expr: E_OLDDIR; Val: $006067B0),
  (Expr: E_REDIR; Val: $00598E7D),
  (Expr: E_STATBAR; Val: $00546BD0),
  (Expr: E_SYSMSGADDR; Val: $005D0DB0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 25 -- first introduced at client '7.0.26.4' (normalized '007.000.026.004')
SysVarMS25 : array[0..30] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $00590420),
  (Expr: C_CHARDIR; Val: $00A76240),
  (Expr: C_CHARPTR; Val: $00ABB674),
  (Expr: C_CLILEFT; Val: $00A7A9F0),
  (Expr: C_CONTPOS; Val: $00954D2C),
  (Expr: C_CURSORKIND; Val: $00A7A965),
  (Expr: C_ENEMYHITS; Val: $00A1CF14),
  (Expr: C_ENEMYID; Val: $0094E2B4),
  (Expr: C_JOURNALPTR; Val: $00AF8010),
  (Expr: C_LHANDID; Val: $00A75484),
  (Expr: C_LLIFTEDID; Val: $00ABB6C0),
  (Expr: C_LSHARD; Val: $00ABFD0C),
  (Expr: C_NEXTCPOS; Val: $009542A4),
  (Expr: C_POPUPID; Val: $00ABFE7C),
  (Expr: C_SHARDPOS; Val: $00954108),
  (Expr: C_SKILLCAPS; Val: $00B3A300),
  (Expr: C_SKILLLOCK; Val: $00B3A2C4),
  (Expr: C_SKILLSPOS; Val: $00B3A378),
  (Expr: C_SYSMSG; Val: $00954D0C),
  (Expr: C_TARGETCURS; Val: $00A7A9C4),
  (Expr: E_DRAGADDR; Val: $005A5D90),
  (Expr: E_EXMSGADDR; Val: $005A4630),
  (Expr: E_ITEMNAMEADDR; Val: $00576CD0),
  (Expr: E_ITEMPROPADDR; Val: $00576BD0),
  (Expr: E_ITEMPROPID; Val: $00A713F4),
  (Expr: E_MACROADDR; Val: $0057EFE0),
  (Expr: E_OLDDIR; Val: $006067D0),
  (Expr: E_REDIR; Val: $00598EAD),
  (Expr: E_STATBAR; Val: $00546C00),
  (Expr: E_SYSMSGADDR; Val: $005D0DD0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 26 -- first introduced at client '7.0.25.6' (normalized '007.000.025.006')
SysVarMS26 : array[0..35] of TSysVarList = (
  (Expr: B_ITEMID; Val: $000000A8),
  (Expr: C_BLOCKINFO; Val: $00590560),
  (Expr: C_CHARDIR; Val: $00A761A0),
  (Expr: C_CHARPTR; Val: $00ABB5D4),
  (Expr: C_CLILEFT; Val: $00A7A950),
  (Expr: C_CONTPOS; Val: $00954C8C),
  (Expr: C_CURSORKIND; Val: $00A7A8C5),
  (Expr: C_ENEMYHITS; Val: $00A1CE74),
  (Expr: C_ENEMYID; Val: $0094E214),
  (Expr: C_JOURNALPTR; Val: $00AF7F70),
  (Expr: C_LHANDID; Val: $00A753E4),
  (Expr: C_LLIFTEDID; Val: $00ABB620),
  (Expr: C_LSHARD; Val: $00ABFC6C),
  (Expr: C_NEXTCPOS; Val: $00954204),
  (Expr: C_POPUPID; Val: $00ABFDDC),
  (Expr: C_SHARDPOS; Val: $00954068),
  (Expr: C_SKILLCAPS; Val: $00B3A260),
  (Expr: C_SKILLLOCK; Val: $00B3A224),
  (Expr: C_SKILLSPOS; Val: $00B3A2D8),
  (Expr: C_SYSMSG; Val: $00954C6C),
  (Expr: C_TARGETCURS; Val: $00A7A924),
  (Expr: E_CONTTOP; Val: $004DCF90),
  (Expr: E_DRAGADDR; Val: $005A5E40),
  (Expr: E_EXMSGADDR; Val: $005A46E0),
  (Expr: E_ITEMCHECKADDR; Val: $00440370),
  (Expr: E_ITEMNAMEADDR; Val: $00576E10),
  (Expr: E_ITEMPROPADDR; Val: $00576D10),
  (Expr: E_ITEMPROPID; Val: $00A71354),
  (Expr: E_ITEMREQADDR; Val: $00441590),
  (Expr: E_MACROADDR; Val: $0057F120),
  (Expr: E_OLDDIR; Val: $00606880),
  (Expr: E_REDIR; Val: $00598F5D),
  (Expr: E_SENDPACKET; Val: $0045F4A0),
  (Expr: E_STATBAR; Val: $00546BE0),
  (Expr: E_SYSMSGADDR; Val: $005D0E80),
  (Expr: LISTEND; Val: 0)
);

// Milestone 27 -- first introduced at client '7.0.24.3' (normalized '007.000.024.003')
SysVarMS27 : array[0..38] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $005902F0),
  (Expr: C_CHARDIR; Val: $00A760C0),
  (Expr: C_CHARPTR; Val: $00ABB4F4),
  (Expr: C_CLILEFT; Val: $00A7A870),
  (Expr: C_CLILOGGED; Val: $006D924C),
  (Expr: C_CLIXRES; Val: $006D97F4),
  (Expr: C_CONTPOS; Val: $00954BEC),
  (Expr: C_CURSORKIND; Val: $00A7A7E5),
  (Expr: C_ENEMYHITS; Val: $00A1CDD4),
  (Expr: C_ENEMYID; Val: $0094E174),
  (Expr: C_JOURNALPTR; Val: $00AF7E90),
  (Expr: C_LHANDID; Val: $00A75304),
  (Expr: C_LLIFTEDID; Val: $00ABB540),
  (Expr: C_LSHARD; Val: $00ABFB8C),
  (Expr: C_NEXTCPOS; Val: $00954164),
  (Expr: C_POPUPID; Val: $00ABFCFC),
  (Expr: C_SHARDPOS; Val: $00953FC8),
  (Expr: C_SKILLCAPS; Val: $00B3A180),
  (Expr: C_SKILLLOCK; Val: $00B3A144),
  (Expr: C_SKILLSPOS; Val: $00B3A1F8),
  (Expr: C_SYSMSG; Val: $00954BCC),
  (Expr: C_TARGETCURS; Val: $00A7A844),
  (Expr: E_CONTTOP; Val: $004DCDE0),
  (Expr: E_DRAGADDR; Val: $005A5BB0),
  (Expr: E_EXMSGADDR; Val: $005A4460),
  (Expr: E_ITEMCHECKADDR; Val: $00440220),
  (Expr: E_ITEMNAMEADDR; Val: $00576BA0),
  (Expr: E_ITEMPROPADDR; Val: $00576AA0),
  (Expr: E_ITEMPROPID; Val: $00A71274),
  (Expr: E_ITEMREQADDR; Val: $00441440),
  (Expr: E_MACROADDR; Val: $0057EEB0),
  (Expr: E_OLDDIR; Val: $00606620),
  (Expr: E_PATHFINDADDR; Val: $00503D29),
  (Expr: E_REDIR; Val: $00598CED),
  (Expr: E_SENDPACKET; Val: $0045F350),
  (Expr: E_SLEEPADDR; Val: $006670EC),
  (Expr: E_STATBAR; Val: $00546970),
  (Expr: E_SYSMSGADDR; Val: $005D0C20),
  (Expr: LISTEND; Val: 0)
);

// Milestone 28 -- first introduced at client '7.0.22.0' (normalized '007.000.022.000')
SysVarMS28 : array[0..37] of TSysVarList = (
  (Expr: C_BLOCKINFO; Val: $0058DCE0),
  (Expr: C_CHARDIR; Val: $00A73C68),
  (Expr: C_CHARPTR; Val: $00AB909C),
  (Expr: C_CLILEFT; Val: $00A78418),
  (Expr: C_CLILOGGED; Val: $006D724C),
  (Expr: C_CLIXRES; Val: $006D77F4),
  (Expr: C_CONTPOS; Val: $00952ACC),
  (Expr: C_CURSORKIND; Val: $00A7838D),
  (Expr: C_ENEMYHITS; Val: $00A1ACB4),
  (Expr: C_ENEMYID; Val: $0094C054),
  (Expr: C_JOURNALPTR; Val: $00AF5A38),
  (Expr: C_LHANDID; Val: $00A72EAC),
  (Expr: C_LLIFTEDID; Val: $00AB90E8),
  (Expr: C_LSHARD; Val: $00ABD734),
  (Expr: C_NEXTCPOS; Val: $00952044),
  (Expr: C_POPUPID; Val: $00ABD8A4),
  (Expr: C_SHARDPOS; Val: $00951EA8),
  (Expr: C_SKILLCAPS; Val: $00B37D28),
  (Expr: C_SKILLLOCK; Val: $00B37CEC),
  (Expr: C_SKILLSPOS; Val: $00B37DA0),
  (Expr: C_SYSMSG; Val: $00952AAC),
  (Expr: C_TARGETCURS; Val: $00A783EC),
  (Expr: E_CONTTOP; Val: $004DC990),
  (Expr: E_DRAGADDR; Val: $005A3610),
  (Expr: E_EXMSGADDR; Val: $005A1EC0),
  (Expr: E_ITEMCHECKADDR; Val: $0043FE30),
  (Expr: E_ITEMNAMEADDR; Val: $00574C50),
  (Expr: E_ITEMPROPADDR; Val: $00574B50),
  (Expr: E_ITEMPROPID; Val: $00A6EE1C),
  (Expr: E_ITEMREQADDR; Val: $00441050),
  (Expr: E_MACROADDR; Val: $0057CF60),
  (Expr: E_OLDDIR; Val: $00603FD0),
  (Expr: E_PATHFINDADDR; Val: $005038D9),
  (Expr: E_REDIR; Val: $0059673D),
  (Expr: E_SENDPACKET; Val: $0045EF70),
  (Expr: E_STATBAR; Val: $00546560),
  (Expr: E_SYSMSGADDR; Val: $005CE690),
  (Expr: LISTEND; Val: 0)
);

// Milestone 29 -- first introduced at client '7.0.21.2' (normalized '007.000.021.002')
SysVarMS29 : array[0..9] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005A3460),
  (Expr: E_EXMSGADDR; Val: $005A1D10),
  (Expr: E_ITEMNAMEADDR; Val: $00574AB0),
  (Expr: E_ITEMPROPADDR; Val: $005749B0),
  (Expr: E_MACROADDR; Val: $0057CDB0),
  (Expr: E_OLDDIR; Val: $00603E20),
  (Expr: E_REDIR; Val: $0059658D),
  (Expr: E_STATBAR; Val: $005463C0),
  (Expr: E_SYSMSGADDR; Val: $005CE4E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 30 -- first introduced at client '7.0.21.1' (normalized '007.000.021.001')
SysVarMS30 : array[0..10] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005A3420),
  (Expr: E_EXMSGADDR; Val: $005A1CD0),
  (Expr: E_ITEMNAMEADDR; Val: $00574A90),
  (Expr: E_ITEMPROPADDR; Val: $00574990),
  (Expr: E_MACROADDR; Val: $0057CD90),
  (Expr: E_OLDDIR; Val: $00603DE0),
  (Expr: E_PATHFINDADDR; Val: $00503739),
  (Expr: E_REDIR; Val: $0059654D),
  (Expr: E_STATBAR; Val: $005463A0),
  (Expr: E_SYSMSGADDR; Val: $005CE4A0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 31 -- first introduced at client '7.0.20.0' (normalized '007.000.020.000')
SysVarMS31 : array[0..25] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A73BC8),
  (Expr: C_CHARPTR; Val: $00AB8FFC),
  (Expr: C_CLILEFT; Val: $00A78378),
  (Expr: C_CONTPOS; Val: $00952A2C),
  (Expr: C_CURSORKIND; Val: $00A782ED),
  (Expr: C_ENEMYHITS; Val: $00A1AC14),
  (Expr: C_JOURNALPTR; Val: $00AF5998),
  (Expr: C_LHANDID; Val: $00A72E0C),
  (Expr: C_LLIFTEDID; Val: $00AB9048),
  (Expr: C_LSHARD; Val: $00ABD694),
  (Expr: C_NEXTCPOS; Val: $00951FA4),
  (Expr: C_POPUPID; Val: $00ABD804),
  (Expr: C_SKILLCAPS; Val: $00B37C88),
  (Expr: C_SKILLLOCK; Val: $00B37C4C),
  (Expr: C_SKILLSPOS; Val: $00B37D00),
  (Expr: C_SYSMSG; Val: $00952A0C),
  (Expr: C_TARGETCURS; Val: $00A7834C),
  (Expr: E_DRAGADDR; Val: $005A3410),
  (Expr: E_EXMSGADDR; Val: $005A1CC0),
  (Expr: E_ITEMNAMEADDR; Val: $00574A80),
  (Expr: E_ITEMPROPADDR; Val: $00574980),
  (Expr: E_ITEMPROPID; Val: $00A6ED7C),
  (Expr: E_MACROADDR; Val: $0057CD80),
  (Expr: E_REDIR; Val: $0059653D),
  (Expr: E_STATBAR; Val: $00546390),
  (Expr: LISTEND; Val: 0)
);

// Milestone 32 -- first introduced at client '7.0.19.1' (normalized '007.000.019.001')
SysVarMS32 : array[0..11] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DC7F0),
  (Expr: E_DRAGADDR; Val: $005A3420),
  (Expr: E_EXMSGADDR; Val: $005A1CB0),
  (Expr: E_ITEMNAMEADDR; Val: $00574A70),
  (Expr: E_ITEMPROPADDR; Val: $00574970),
  (Expr: E_MACROADDR; Val: $0057CD70),
  (Expr: E_OLDDIR; Val: $00603DD0),
  (Expr: E_PATHFINDADDR; Val: $00503729),
  (Expr: E_REDIR; Val: $0059652D),
  (Expr: E_STATBAR; Val: $00546370),
  (Expr: E_SYSMSGADDR; Val: $005CE490),
  (Expr: LISTEND; Val: 0)
);

// Milestone 33 -- first introduced at client '7.0.19.0' (normalized '007.000.019.000')
SysVarMS33 : array[0..29] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A73BD0),
  (Expr: C_CHARPTR; Val: $00AB9004),
  (Expr: C_CLILEFT; Val: $00A78380),
  (Expr: C_CONTPOS; Val: $00952A34),
  (Expr: C_CURSORKIND; Val: $00A782F5),
  (Expr: C_ENEMYHITS; Val: $00A1AC1C),
  (Expr: C_JOURNALPTR; Val: $00AF59A0),
  (Expr: C_LHANDID; Val: $00A72E14),
  (Expr: C_LLIFTEDID; Val: $00AB9050),
  (Expr: C_LSHARD; Val: $00ABD69C),
  (Expr: C_NEXTCPOS; Val: $00951FAC),
  (Expr: C_POPUPID; Val: $00ABD80C),
  (Expr: C_SKILLCAPS; Val: $00B37C90),
  (Expr: C_SKILLLOCK; Val: $00B37C54),
  (Expr: C_SKILLSPOS; Val: $00B37D08),
  (Expr: C_SYSMSG; Val: $00952A14),
  (Expr: C_TARGETCURS; Val: $00A78354),
  (Expr: E_CONTTOP; Val: $004DC810),
  (Expr: E_DRAGADDR; Val: $005A3440),
  (Expr: E_EXMSGADDR; Val: $005A1CD0),
  (Expr: E_ITEMNAMEADDR; Val: $00574A90),
  (Expr: E_ITEMPROPADDR; Val: $00574990),
  (Expr: E_ITEMPROPID; Val: $00A6ED84),
  (Expr: E_MACROADDR; Val: $0057CD90),
  (Expr: E_OLDDIR; Val: $00603DF0),
  (Expr: E_PATHFINDADDR; Val: $00503749),
  (Expr: E_REDIR; Val: $0059654D),
  (Expr: E_STATBAR; Val: $00546390),
  (Expr: E_SYSMSGADDR; Val: $005CE4B0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 34 -- first introduced at client '7.0.17.0' (normalized '007.000.017.000')
SysVarMS34 : array[0..33] of TSysVarList = (
  (Expr: B_FINDREP; Val: $000001B4),
  (Expr: C_CHARDIR; Val: $00A73BC8),
  (Expr: C_CHARPTR; Val: $00AB8D54),
  (Expr: C_CLILEFT; Val: $00A780D0),
  (Expr: C_CONTPOS; Val: $00952A2C),
  (Expr: C_CURSORKIND; Val: $00A78045),
  (Expr: C_ENEMYHITS; Val: $00A1AC14),
  (Expr: C_ENEMYID; Val: $0094BFB4),
  (Expr: C_JOURNALPTR; Val: $00AF56F0),
  (Expr: C_LHANDID; Val: $00A72E0C),
  (Expr: C_LLIFTEDID; Val: $00AB8DA0),
  (Expr: C_LSHARD; Val: $00ABD3EC),
  (Expr: C_NEXTCPOS; Val: $00951FA4),
  (Expr: C_POPUPID; Val: $00ABD55C),
  (Expr: C_SHARDPOS; Val: $00951E08),
  (Expr: C_SKILLCAPS; Val: $00B379E0),
  (Expr: C_SKILLLOCK; Val: $00B379A4),
  (Expr: C_SKILLSPOS; Val: $00B37A58),
  (Expr: C_SYSMSG; Val: $00952A0C),
  (Expr: C_TARGETCURS; Val: $00A780A4),
  (Expr: E_CONTTOP; Val: $004DD2B0),
  (Expr: E_DRAGADDR; Val: $005A3C40),
  (Expr: E_EXMSGADDR; Val: $005A2620),
  (Expr: E_ITEMNAMEADDR; Val: $005753F0),
  (Expr: E_ITEMPROPADDR; Val: $005752F0),
  (Expr: E_ITEMPROPID; Val: $00A6ED7C),
  (Expr: E_MACROADDR; Val: $0057D830),
  (Expr: E_OLDDIR; Val: $006045B0),
  (Expr: E_PATHFINDADDR; Val: $005041C9),
  (Expr: E_REDIR; Val: $00596E9D),
  (Expr: E_SENDPACKET; Val: $0045EDD0),
  (Expr: E_STATBAR; Val: $00546CF0),
  (Expr: E_SYSMSGADDR; Val: $005CEC70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 35 -- first introduced at client '7.0.16.0' (normalized '007.000.016.000')
SysVarMS35 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A73BE8),
  (Expr: C_CHARPTR; Val: $00AB8D74),
  (Expr: C_CLILEFT; Val: $00A780F0),
  (Expr: C_CLILOGGED; Val: $006D721C),
  (Expr: C_CLIXRES; Val: $006D77C4),
  (Expr: C_CONTPOS; Val: $00952A4C),
  (Expr: C_CURSORKIND; Val: $00A78065),
  (Expr: C_ENEMYHITS; Val: $00A1AC34),
  (Expr: C_ENEMYID; Val: $0094BFD4),
  (Expr: C_JOURNALPTR; Val: $00AF5710),
  (Expr: C_LHANDID; Val: $00A72E2C),
  (Expr: C_LLIFTEDID; Val: $00AB8DC0),
  (Expr: C_LSHARD; Val: $00ABD40C),
  (Expr: C_NEXTCPOS; Val: $00951FC4),
  (Expr: C_POPUPID; Val: $00ABD57C),
  (Expr: C_SHARDPOS; Val: $00951E28),
  (Expr: C_SKILLCAPS; Val: $00B37A00),
  (Expr: C_SKILLLOCK; Val: $00B379C4),
  (Expr: C_SKILLSPOS; Val: $00B37A78),
  (Expr: C_SYSMSG; Val: $00952A2C),
  (Expr: C_TARGETCURS; Val: $00A780C4),
  (Expr: E_CONTTOP; Val: $004DD460),
  (Expr: E_DRAGADDR; Val: $005A4050),
  (Expr: E_EXMSGADDR; Val: $005A2850),
  (Expr: E_ITEMNAMEADDR; Val: $00575620),
  (Expr: E_ITEMPROPADDR; Val: $00575520),
  (Expr: E_ITEMPROPID; Val: $00A6ED9C),
  (Expr: E_MACROADDR; Val: $0057DA60),
  (Expr: E_OLDDIR; Val: $00604070),
  (Expr: E_PATHFINDADDR; Val: $00504379),
  (Expr: E_REDIR; Val: $005970CD),
  (Expr: E_SLEEPADDR; Val: $006650EC),
  (Expr: E_STATBAR; Val: $00546F20),
  (Expr: E_SYSMSGADDR; Val: $005CE730),
  (Expr: LISTEND; Val: 0)
);

// Milestone 36 -- first introduced at client '7.0.14.4' (normalized '007.000.014.004')
SysVarMS36 : array[0..13] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DD0A0),
  (Expr: E_DRAGADDR; Val: $005A3560),
  (Expr: E_EXMSGADDR; Val: $005A1D60),
  (Expr: E_ITEMNAMEADDR; Val: $00574B40),
  (Expr: E_ITEMPROPADDR; Val: $00574A40),
  (Expr: E_ITEMREQADDR; Val: $00440EB0),
  (Expr: E_MACROADDR; Val: $0057CF80),
  (Expr: E_OLDDIR; Val: $00603580),
  (Expr: E_PATHFINDADDR; Val: $00503FB9),
  (Expr: E_REDIR; Val: $005965DD),
  (Expr: E_SENDPACKET; Val: $0045EF80),
  (Expr: E_STATBAR; Val: $00546480),
  (Expr: E_SYSMSGADDR; Val: $005CDC40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 37 -- first introduced at client '7.0.14.3' (normalized '007.000.014.003')
SysVarMS37 : array[0..13] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DD0C0),
  (Expr: E_DRAGADDR; Val: $005A35A0),
  (Expr: E_EXMSGADDR; Val: $005A1DA0),
  (Expr: E_ITEMNAMEADDR; Val: $00574B70),
  (Expr: E_ITEMPROPADDR; Val: $00574A70),
  (Expr: E_ITEMREQADDR; Val: $00440ED0),
  (Expr: E_MACROADDR; Val: $0057CFC0),
  (Expr: E_OLDDIR; Val: $006035C0),
  (Expr: E_PATHFINDADDR; Val: $00503FD9),
  (Expr: E_REDIR; Val: $0059661D),
  (Expr: E_SENDPACKET; Val: $0045EFA0),
  (Expr: E_STATBAR; Val: $005464B0),
  (Expr: E_SYSMSGADDR; Val: $005CDC80),
  (Expr: LISTEND; Val: 0)
);

// Milestone 38 -- first introduced at client '7.0.14.0' (normalized '007.000.014.000')
SysVarMS38 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A72BC8),
  (Expr: C_CHARPTR; Val: $00AB7D54),
  (Expr: C_CLILEFT; Val: $00A770D0),
  (Expr: C_CONTPOS; Val: $00951A2C),
  (Expr: C_CURSORKIND; Val: $00A77045),
  (Expr: C_ENEMYHITS; Val: $00A19C14),
  (Expr: C_ENEMYID; Val: $0094AFB4),
  (Expr: C_JOURNALPTR; Val: $00AF46F0),
  (Expr: C_LHANDID; Val: $00A71E0C),
  (Expr: C_LLIFTEDID; Val: $00AB7DA0),
  (Expr: C_LSHARD; Val: $00ABC3EC),
  (Expr: C_NEXTCPOS; Val: $00950FA4),
  (Expr: C_POPUPID; Val: $00ABC55C),
  (Expr: C_SHARDPOS; Val: $00950E08),
  (Expr: C_SKILLCAPS; Val: $00B369E0),
  (Expr: C_SKILLLOCK; Val: $00B369A4),
  (Expr: C_SKILLSPOS; Val: $00B36A58),
  (Expr: C_SYSMSG; Val: $00951A0C),
  (Expr: C_TARGETCURS; Val: $00A770A4),
  (Expr: E_CONTTOP; Val: $004DD0A0),
  (Expr: E_DRAGADDR; Val: $005A3560),
  (Expr: E_EXMSGADDR; Val: $005A1D60),
  (Expr: E_ITEMCHECKADDR; Val: $0043FC90),
  (Expr: E_ITEMNAMEADDR; Val: $00574B40),
  (Expr: E_ITEMPROPADDR; Val: $00574A40),
  (Expr: E_ITEMPROPID; Val: $00A6DD7C),
  (Expr: E_ITEMREQADDR; Val: $00440EB0),
  (Expr: E_MACROADDR; Val: $0057CF80),
  (Expr: E_OLDDIR; Val: $00603580),
  (Expr: E_PATHFINDADDR; Val: $00503FB9),
  (Expr: E_REDIR; Val: $005965DD),
  (Expr: E_SENDPACKET; Val: $0045EF80),
  (Expr: E_STATBAR; Val: $00546480),
  (Expr: E_SYSMSGADDR; Val: $005CDC40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 39 -- first introduced at client '7.0.13.1' (normalized '007.000.013.001')
SysVarMS39 : array[0..14] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DCFD0),
  (Expr: E_DRAGADDR; Val: $005A3490),
  (Expr: E_EXMSGADDR; Val: $005A1C90),
  (Expr: E_ITEMCHECKADDR; Val: $0043FC30),
  (Expr: E_ITEMNAMEADDR; Val: $00574A70),
  (Expr: E_ITEMPROPADDR; Val: $00574970),
  (Expr: E_ITEMREQADDR; Val: $00440E50),
  (Expr: E_MACROADDR; Val: $0057CEB0),
  (Expr: E_OLDDIR; Val: $006034B0),
  (Expr: E_PATHFINDADDR; Val: $00503EE9),
  (Expr: E_REDIR; Val: $0059650D),
  (Expr: E_SENDPACKET; Val: $0045EF20),
  (Expr: E_STATBAR; Val: $005463B0),
  (Expr: E_SYSMSGADDR; Val: $005CDB70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 40 -- first introduced at client '7.0.13.0' (normalized '007.000.013.000')
SysVarMS40 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A72B88),
  (Expr: C_CHARPTR; Val: $00AB7D14),
  (Expr: C_CLILEFT; Val: $00A77090),
  (Expr: C_CLILOGGED; Val: $006D6214),
  (Expr: C_CLIXRES; Val: $006D67BC),
  (Expr: C_CONTPOS; Val: $009519EC),
  (Expr: C_CURSORKIND; Val: $00A77005),
  (Expr: C_ENEMYHITS; Val: $00A19BD4),
  (Expr: C_ENEMYID; Val: $0094AF74),
  (Expr: C_JOURNALPTR; Val: $00AF46B0),
  (Expr: C_LHANDID; Val: $00A71DCC),
  (Expr: C_LLIFTEDID; Val: $00AB7D60),
  (Expr: C_LSHARD; Val: $00ABC3AC),
  (Expr: C_NEXTCPOS; Val: $00950F64),
  (Expr: C_POPUPID; Val: $00ABC51C),
  (Expr: C_SHARDPOS; Val: $00950DC8),
  (Expr: C_SKILLCAPS; Val: $00B369A0),
  (Expr: C_SKILLLOCK; Val: $00B36964),
  (Expr: C_SKILLSPOS; Val: $00B36A18),
  (Expr: C_SYSMSG; Val: $009519CC),
  (Expr: C_TARGETCURS; Val: $00A77064),
  (Expr: E_CONTTOP; Val: $004DCE80),
  (Expr: E_DRAGADDR; Val: $005A3330),
  (Expr: E_EXMSGADDR; Val: $005A1B30),
  (Expr: E_ITEMNAMEADDR; Val: $00574910),
  (Expr: E_ITEMPROPADDR; Val: $00574810),
  (Expr: E_ITEMPROPID; Val: $00A6DD3C),
  (Expr: E_MACROADDR; Val: $0057CD50),
  (Expr: E_OLDDIR; Val: $00603350),
  (Expr: E_PATHFINDADDR; Val: $00503D89),
  (Expr: E_REDIR; Val: $005963AD),
  (Expr: E_SENDPACKET; Val: $0045EDD0),
  (Expr: E_SLEEPADDR; Val: $006640EC),
  (Expr: E_STATBAR; Val: $00546250),
  (Expr: E_SYSMSGADDR; Val: $005CDA10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 41 -- first introduced at client '7.0.12.0' (normalized '007.000.012.000')
SysVarMS41 : array[0..9] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005A1D20),
  (Expr: E_EXMSGADDR; Val: $005A0520),
  (Expr: E_ITEMNAMEADDR; Val: $00573300),
  (Expr: E_ITEMPROPADDR; Val: $00573200),
  (Expr: E_MACROADDR; Val: $0057B740),
  (Expr: E_OLDDIR; Val: $00601D40),
  (Expr: E_REDIR; Val: $00594D9D),
  (Expr: E_STATBAR; Val: $00544B30),
  (Expr: E_SYSMSGADDR; Val: $005CC400),
  (Expr: LISTEND; Val: 0)
);

// Milestone 42 -- first introduced at client '7.0.11.2' (normalized '007.000.011.002')
SysVarMS42 : array[0..11] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DBAB0),
  (Expr: E_DRAGADDR; Val: $005A1D60),
  (Expr: E_EXMSGADDR; Val: $005A0560),
  (Expr: E_ITEMNAMEADDR; Val: $00573320),
  (Expr: E_ITEMPROPADDR; Val: $00573220),
  (Expr: E_MACROADDR; Val: $0057B760),
  (Expr: E_OLDDIR; Val: $00601D80),
  (Expr: E_PATHFINDADDR; Val: $00502369),
  (Expr: E_REDIR; Val: $00594DDD),
  (Expr: E_STATBAR; Val: $00544B50),
  (Expr: E_SYSMSGADDR; Val: $005CC440),
  (Expr: LISTEND; Val: 0)
);

// Milestone 43 -- first introduced at client '7.0.11.0' (normalized '007.000.011.000')
SysVarMS43 : array[0..37] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00A707C0),
  (Expr: C_CHARPTR; Val: $00AB5944),
  (Expr: C_CLILEFT; Val: $00A74CC0),
  (Expr: C_CLILOGGED; Val: $006D3F24),
  (Expr: C_CLIXRES; Val: $006D44CC),
  (Expr: C_CONTPOS; Val: $0094F644),
  (Expr: C_CURSORKIND; Val: $00A74C35),
  (Expr: C_ENEMYHITS; Val: $00A1782C),
  (Expr: C_ENEMYID; Val: $00948BD4),
  (Expr: C_JOURNALPTR; Val: $00AF22E0),
  (Expr: C_LHANDID; Val: $00A6FA04),
  (Expr: C_LLIFTEDID; Val: $00AB5990),
  (Expr: C_LSHARD; Val: $00AB9FDC),
  (Expr: C_NEXTCPOS; Val: $0094EBBC),
  (Expr: C_POPUPID; Val: $00ABA14C),
  (Expr: C_SHARDPOS; Val: $0094EA20),
  (Expr: C_SKILLCAPS; Val: $00B345D0),
  (Expr: C_SKILLLOCK; Val: $00B34594),
  (Expr: C_SKILLSPOS; Val: $00B34648),
  (Expr: C_SYSMSG; Val: $0094F624),
  (Expr: C_TARGETCURS; Val: $00A74C94),
  (Expr: E_CONTTOP; Val: $004DB980),
  (Expr: E_DRAGADDR; Val: $005A1C30),
  (Expr: E_EXMSGADDR; Val: $005A0430),
  (Expr: E_ITEMCHECKADDR; Val: $0043FAE0),
  (Expr: E_ITEMNAMEADDR; Val: $005731F0),
  (Expr: E_ITEMPROPADDR; Val: $005730F0),
  (Expr: E_ITEMPROPID; Val: $00A6B974),
  (Expr: E_ITEMREQADDR; Val: $00440D00),
  (Expr: E_MACROADDR; Val: $0057B630),
  (Expr: E_OLDDIR; Val: $00601C50),
  (Expr: E_PATHFINDADDR; Val: $00502239),
  (Expr: E_REDIR; Val: $00594CAD),
  (Expr: E_SENDPACKET; Val: $0045EDC0),
  (Expr: E_SLEEPADDR; Val: $006620EC),
  (Expr: E_STATBAR; Val: $00544A20),
  (Expr: E_SYSMSGADDR; Val: $005CC310),
  (Expr: LISTEND; Val: 0)
);

// Milestone 44 -- first introduced at client '7.0.10.2' (normalized '007.000.010.002')
SysVarMS44 : array[0..10] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005A0810),
  (Expr: E_EXMSGADDR; Val: $0059F030),
  (Expr: E_ITEMNAMEADDR; Val: $00571E50),
  (Expr: E_ITEMPROPADDR; Val: $00571D50),
  (Expr: E_MACROADDR; Val: $0057A290),
  (Expr: E_OLDDIR; Val: $00600240),
  (Expr: E_PATHFINDADDR; Val: $00500FA9),
  (Expr: E_REDIR; Val: $005938AD),
  (Expr: E_STATBAR; Val: $00543670),
  (Expr: E_SYSMSGADDR; Val: $005CA900),
  (Expr: LISTEND; Val: 0)
);

// Milestone 45 -- first introduced at client '7.0.10.1' (normalized '007.000.010.001')
SysVarMS45 : array[0..12] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004DA6F0),
  (Expr: E_DRAGADDR; Val: $005A07F0),
  (Expr: E_EXMSGADDR; Val: $0059F010),
  (Expr: E_ITEMNAMEADDR; Val: $00571E30),
  (Expr: E_ITEMPROPADDR; Val: $00571D30),
  (Expr: E_MACROADDR; Val: $0057A270),
  (Expr: E_OLDDIR; Val: $00600220),
  (Expr: E_PATHFINDADDR; Val: $00500F89),
  (Expr: E_REDIR; Val: $0059388D),
  (Expr: E_SENDPACKET; Val: $0045DBE0),
  (Expr: E_STATBAR; Val: $00543650),
  (Expr: E_SYSMSGADDR; Val: $005CA8E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 46 -- first introduced at client '7.0.9.0' (normalized '007.000.009.000')
SysVarMS46 : array[0..38] of TSysVarList = (
  (Expr: B_FINDREP; Val: $000001AC),
  (Expr: B_ITEMID; Val: $000000A0),
  (Expr: C_CHARDIR; Val: $00A6F760),
  (Expr: C_CHARPTR; Val: $00AB48E4),
  (Expr: C_CLILEFT; Val: $00A73C60),
  (Expr: C_CLILOGGED; Val: $006D2F24),
  (Expr: C_CLIXRES; Val: $006D34CC),
  (Expr: C_CONTPOS; Val: $0094E5E4),
  (Expr: C_CURSORKIND; Val: $00A73BD5),
  (Expr: C_ENEMYHITS; Val: $00A167CC),
  (Expr: C_ENEMYID; Val: $00947B74),
  (Expr: C_JOURNALPTR; Val: $00AF1280),
  (Expr: C_LHANDID; Val: $00A6E9A4),
  (Expr: C_LLIFTEDID; Val: $00AB4930),
  (Expr: C_LSHARD; Val: $00AB8F7C),
  (Expr: C_NEXTCPOS; Val: $0094DB5C),
  (Expr: C_POPUPID; Val: $00AB90EC),
  (Expr: C_SHARDPOS; Val: $0094D9C0),
  (Expr: C_SKILLCAPS; Val: $00B33570),
  (Expr: C_SKILLLOCK; Val: $00B33534),
  (Expr: C_SKILLSPOS; Val: $00B335E8),
  (Expr: C_SYSMSG; Val: $0094E5C4),
  (Expr: C_TARGETCURS; Val: $00A73C34),
  (Expr: E_CONTTOP; Val: $004DA6E0),
  (Expr: E_DRAGADDR; Val: $005A0840),
  (Expr: E_EXMSGADDR; Val: $0059F060),
  (Expr: E_ITEMNAMEADDR; Val: $00571E80),
  (Expr: E_ITEMPROPADDR; Val: $00571D80),
  (Expr: E_ITEMPROPID; Val: $00A6A914),
  (Expr: E_MACROADDR; Val: $0057A2C0),
  (Expr: E_OLDDIR; Val: $00600270),
  (Expr: E_PATHFINDADDR; Val: $00500F79),
  (Expr: E_REDIR; Val: $005938DD),
  (Expr: E_SENDPACKET; Val: $0045DBD0),
  (Expr: E_SLEEPADDR; Val: $006610EC),
  (Expr: E_STATBAR; Val: $00543640),
  (Expr: E_SYSMSGADDR; Val: $005CA930),
  (Expr: F_FLAGS; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 47 -- first introduced at client '7.0.8.2' (normalized '007.000.008.002')
SysVarMS47 : array[0..11] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004D9E00),
  (Expr: E_DRAGADDR; Val: $0059C0A0),
  (Expr: E_EXMSGADDR; Val: $0059A8F0),
  (Expr: E_ITEMNAMEADDR; Val: $0056DAF0),
  (Expr: E_ITEMPROPADDR; Val: $0056D9F0),
  (Expr: E_MACROADDR; Val: $00575F30),
  (Expr: E_OLDDIR; Val: $005FB260),
  (Expr: E_PATHFINDADDR; Val: $004FF529),
  (Expr: E_REDIR; Val: $0058F3DD),
  (Expr: E_STATBAR; Val: $00541990),
  (Expr: E_SYSMSGADDR; Val: $005C5960),
  (Expr: LISTEND; Val: 0)
);

// Milestone 48 -- first introduced at client '7.0.8.0' (normalized '007.000.008.000')
SysVarMS48 : array[0..37] of TSysVarList = (
  (Expr: B_MEMBASE; Val: $00000000),
  (Expr: C_CHARDIR; Val: $00969A08),
  (Expr: C_CHARPTR; Val: $009AEB94),
  (Expr: C_CLILEFT; Val: $0096DF10),
  (Expr: C_CLILOGGED; Val: $006CD094),
  (Expr: C_CLIXRES; Val: $006CD63C),
  (Expr: C_CONTPOS; Val: $008488A8),
  (Expr: C_CURSORKIND; Val: $0096DE85),
  (Expr: C_ENEMYHITS; Val: $00910A74),
  (Expr: C_ENEMYID; Val: $00841E34),
  (Expr: C_JOURNALPTR; Val: $009EB530),
  (Expr: C_LHANDID; Val: $00968C4C),
  (Expr: C_LLIFTEDID; Val: $009AEBE0),
  (Expr: C_LSHARD; Val: $009B322C),
  (Expr: C_NEXTCPOS; Val: $00847E1C),
  (Expr: C_POPUPID; Val: $009B339C),
  (Expr: C_SHARDPOS; Val: $00847C80),
  (Expr: C_SKILLCAPS; Val: $00A2D820),
  (Expr: C_SKILLLOCK; Val: $00A2D7E4),
  (Expr: C_SKILLSPOS; Val: $00A2D898),
  (Expr: C_SYSMSG; Val: $00848888),
  (Expr: C_TARGETCURS; Val: $0096DEE4),
  (Expr: E_CONTTOP; Val: $004D9DE0),
  (Expr: E_DRAGADDR; Val: $0059C080),
  (Expr: E_EXMSGADDR; Val: $0059A8D0),
  (Expr: E_ITEMCHECKADDR; Val: $0043F970),
  (Expr: E_ITEMNAMEADDR; Val: $0056DAD0),
  (Expr: E_ITEMPROPADDR; Val: $0056D9D0),
  (Expr: E_ITEMPROPID; Val: $00964BBC),
  (Expr: E_ITEMREQADDR; Val: $00440B90),
  (Expr: E_MACROADDR; Val: $00575F10),
  (Expr: E_OLDDIR; Val: $005FB210),
  (Expr: E_PATHFINDADDR; Val: $004FF509),
  (Expr: E_REDIR; Val: $0058F3BD),
  (Expr: E_SENDPACKET; Val: $0045E000),
  (Expr: E_SLEEPADDR; Val: $0065C0EC),
  (Expr: E_SYSMSGADDR; Val: $005C5940),
  (Expr: LISTEND; Val: 0)
);

// Milestone 49 -- first introduced at client '7.0.7.1' (normalized '007.000.007.001')
SysVarMS49 : array[0..25] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00967800),
  (Expr: C_CHARPTR; Val: $009AC98C),
  (Expr: C_CLILEFT; Val: $0096BD08),
  (Expr: C_CONTPOS; Val: $008466D8),
  (Expr: C_CURSORKIND; Val: $0096BC7D),
  (Expr: C_ENEMYHITS; Val: $0090E8A4),
  (Expr: C_ENEMYID; Val: $0083FCB0),
  (Expr: C_JOURNALPTR; Val: $009E9328),
  (Expr: C_LHANDID; Val: $00966A44),
  (Expr: C_LLIFTEDID; Val: $009AC9D8),
  (Expr: C_LSHARD; Val: $009B1020),
  (Expr: C_NEXTCPOS; Val: $00845C4C),
  (Expr: C_POPUPID; Val: $009B1194),
  (Expr: C_SHARDPOS; Val: $00845AB0),
  (Expr: C_SKILLCAPS; Val: $00A2B618),
  (Expr: C_SKILLLOCK; Val: $00A2B5DC),
  (Expr: C_SKILLSPOS; Val: $00A2B690),
  (Expr: C_SYSMSG; Val: $008466B8),
  (Expr: C_TARGETCURS; Val: $0096BCDC),
  (Expr: E_DRAGADDR; Val: $0059B0D0),
  (Expr: E_EXMSGADDR; Val: $00599920),
  (Expr: E_ITEMPROPID; Val: $009629BC),
  (Expr: E_OLDDIR; Val: $005F9790),
  (Expr: E_REDIR; Val: $0058E40D),
  (Expr: E_SYSMSGADDR; Val: $005C4990),
  (Expr: LISTEND; Val: 0)
);

// Milestone 50 -- first introduced at client '7.0.7.0' (normalized '007.000.007.000')
SysVarMS50 : array[0..33] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $009677E0),
  (Expr: C_CHARPTR; Val: $009AC96C),
  (Expr: C_CLILEFT; Val: $0096BCE8),
  (Expr: C_CLILOGGED; Val: $006CB07C),
  (Expr: C_CLIXRES; Val: $006CB61C),
  (Expr: C_CONTPOS; Val: $008466B8),
  (Expr: C_CURSORKIND; Val: $0096BC5D),
  (Expr: C_ENEMYHITS; Val: $0090E884),
  (Expr: C_ENEMYID; Val: $0083FC90),
  (Expr: C_JOURNALPTR; Val: $009E9308),
  (Expr: C_LHANDID; Val: $00966A24),
  (Expr: C_LLIFTEDID; Val: $009AC9B8),
  (Expr: C_LSHARD; Val: $009B1000),
  (Expr: C_NEXTCPOS; Val: $00845C2C),
  (Expr: C_POPUPID; Val: $009B1174),
  (Expr: C_SHARDPOS; Val: $00845A90),
  (Expr: C_SKILLCAPS; Val: $00A2B5F8),
  (Expr: C_SKILLLOCK; Val: $00A2B5BC),
  (Expr: C_SKILLSPOS; Val: $00A2B670),
  (Expr: C_SYSMSG; Val: $00846698),
  (Expr: C_TARGETCURS; Val: $0096BCBC),
  (Expr: E_CONTTOP; Val: $004D92D0),
  (Expr: E_DRAGADDR; Val: $0059B070),
  (Expr: E_EXMSGADDR; Val: $005998C0),
  (Expr: E_ITEMNAMEADDR; Val: $0056D010),
  (Expr: E_ITEMPROPADDR; Val: $0056CF10),
  (Expr: E_ITEMPROPID; Val: $0096299C),
  (Expr: E_MACROADDR; Val: $00575270),
  (Expr: E_OLDDIR; Val: $005F9730),
  (Expr: E_PATHFINDADDR; Val: $004FE929),
  (Expr: E_REDIR; Val: $0058E3AD),
  (Expr: E_SLEEPADDR; Val: $0065A0EC),
  (Expr: E_SYSMSGADDR; Val: $005C4930),
  (Expr: LISTEND; Val: 0)
);

// Milestone 51 -- first introduced at client '7.0.6.4' (normalized '007.000.006.004')
SysVarMS51 : array[0..4] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $0059A9C0),
  (Expr: E_EXMSGADDR; Val: $00599210),
  (Expr: E_OLDDIR; Val: $005F8B10),
  (Expr: E_SYSMSGADDR; Val: $005C3B20),
  (Expr: LISTEND; Val: 0)
);

// Milestone 52 -- first introduced at client '7.0.6.3' (normalized '007.000.006.003')
SysVarMS52 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $009667E0),
  (Expr: C_CHARPTR; Val: $009AB954),
  (Expr: C_CLILEFT; Val: $0096ACD0),
  (Expr: C_CLILOGGED; Val: $006CA07C),
  (Expr: C_CLIXRES; Val: $006CA614),
  (Expr: C_CONTPOS; Val: $008456B8),
  (Expr: C_CURSORKIND; Val: $0096AC4D),
  (Expr: C_ENEMYHITS; Val: $0090D884),
  (Expr: C_ENEMYID; Val: $0083EC90),
  (Expr: C_JOURNALPTR; Val: $009E82F0),
  (Expr: C_LHANDID; Val: $00965A24),
  (Expr: C_LLIFTEDID; Val: $009AB9A0),
  (Expr: C_LSHARD; Val: $009AFFE8),
  (Expr: C_NEXTCPOS; Val: $00844C2C),
  (Expr: C_POPUPID; Val: $009B015C),
  (Expr: C_SHARDPOS; Val: $00844A90),
  (Expr: C_SKILLCAPS; Val: $00A2A5E0),
  (Expr: C_SKILLLOCK; Val: $00A2A5A4),
  (Expr: C_SKILLSPOS; Val: $00A2A658),
  (Expr: C_SYSMSG; Val: $00845698),
  (Expr: C_TARGETCURS; Val: $0096ACA4),
  (Expr: E_CONTTOP; Val: $004D9010),
  (Expr: E_DRAGADDR; Val: $0059AA00),
  (Expr: E_EXMSGADDR; Val: $00599250),
  (Expr: E_ITEMNAMEADDR; Val: $0056CB80),
  (Expr: E_ITEMPROPADDR; Val: $0056CA80),
  (Expr: E_ITEMPROPID; Val: $0096199C),
  (Expr: E_MACROADDR; Val: $00574D90),
  (Expr: E_OLDDIR; Val: $005F8B50),
  (Expr: E_PATHFINDADDR; Val: $004FE669),
  (Expr: E_REDIR; Val: $0058DE5D),
  (Expr: E_SENDPACKET; Val: $0045DF90),
  (Expr: E_SLEEPADDR; Val: $006590EC),
  (Expr: E_SYSMSGADDR; Val: $005C3B60),
  (Expr: LISTEND; Val: 0)
);

// Milestone 53 -- first introduced at client '7.0.5.0' (normalized '007.000.005.000')
SysVarMS53 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $009637E0),
  (Expr: C_CHARPTR; Val: $009A7844),
  (Expr: C_CLILEFT; Val: $00966BC0),
  (Expr: C_CLILOGGED; Val: $006C907C),
  (Expr: C_CLIXRES; Val: $006C9614),
  (Expr: C_CONTPOS; Val: $008426B8),
  (Expr: C_CURSORKIND; Val: $00966B3D),
  (Expr: C_ENEMYHITS; Val: $0090A884),
  (Expr: C_ENEMYID; Val: $0083BC90),
  (Expr: C_JOURNALPTR; Val: $009E41E0),
  (Expr: C_LHANDID; Val: $00962A24),
  (Expr: C_LLIFTEDID; Val: $009A7890),
  (Expr: C_LSHARD; Val: $009ABED8),
  (Expr: C_NEXTCPOS; Val: $00841C2C),
  (Expr: C_POPUPID; Val: $009AC04C),
  (Expr: C_SHARDPOS; Val: $00841A90),
  (Expr: C_SKILLCAPS; Val: $00A264D0),
  (Expr: C_SKILLLOCK; Val: $00A26494),
  (Expr: C_SKILLSPOS; Val: $00A26548),
  (Expr: C_SYSMSG; Val: $00842698),
  (Expr: C_TARGETCURS; Val: $00966B94),
  (Expr: E_CONTTOP; Val: $004D8D40),
  (Expr: E_DRAGADDR; Val: $0059A570),
  (Expr: E_EXMSGADDR; Val: $00598E00),
  (Expr: E_ITEMCHECKADDR; Val: $0043F920),
  (Expr: E_ITEMNAMEADDR; Val: $0056C8B0),
  (Expr: E_ITEMPROPADDR; Val: $0056C7B0),
  (Expr: E_ITEMPROPID; Val: $0095E99C),
  (Expr: E_ITEMREQADDR; Val: $00440B20),
  (Expr: E_MACROADDR; Val: $00574AC0),
  (Expr: E_OLDDIR; Val: $005F85A0),
  (Expr: E_PATHFINDADDR; Val: $004FE399),
  (Expr: E_REDIR; Val: $0058DA6D),
  (Expr: E_SENDPACKET; Val: $0045DCD0),
  (Expr: E_SLEEPADDR; Val: $006580EC),
  (Expr: E_SYSMSGADDR; Val: $005C36B0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 54 -- first introduced at client '7.0.4.5' (normalized '007.000.004.005')
SysVarMS54 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00960700),
  (Expr: C_CHARPTR; Val: $009A4764),
  (Expr: C_CLILEFT; Val: $00963AE0),
  (Expr: C_CLILOGGED; Val: $006C607C),
  (Expr: C_CLIXRES; Val: $006C660C),
  (Expr: C_CONTPOS; Val: $0083F5E8),
  (Expr: C_CURSORKIND; Val: $00963A5D),
  (Expr: C_ENEMYHITS; Val: $009077B4),
  (Expr: C_ENEMYID; Val: $00838BD0),
  (Expr: C_JOURNALPTR; Val: $009E1100),
  (Expr: C_LHANDID; Val: $0095F944),
  (Expr: C_LLIFTEDID; Val: $009A47B0),
  (Expr: C_LSHARD; Val: $009A8DF8),
  (Expr: C_NEXTCPOS; Val: $0083EB5C),
  (Expr: C_POPUPID; Val: $009A8F6C),
  (Expr: C_SHARDPOS; Val: $0083E9D0),
  (Expr: C_SKILLCAPS; Val: $00A233F0),
  (Expr: C_SKILLLOCK; Val: $00A233B4),
  (Expr: C_SKILLSPOS; Val: $00A23468),
  (Expr: C_SYSMSG; Val: $0083F5C8),
  (Expr: C_TARGETCURS; Val: $00963AB4),
  (Expr: E_CONTTOP; Val: $004D6840),
  (Expr: E_DRAGADDR; Val: $0597A60),
  (Expr: E_EXMSGADDR; Val: $005962F0),
  (Expr: E_ITEMCHECKADDR; Val: $0043F680),
  (Expr: E_ITEMNAMEADDR; Val: $00569690),
  (Expr: E_ITEMPROPADDR; Val: $00569590),
  (Expr: E_ITEMPROPID; Val: $0095B8BC),
  (Expr: E_ITEMREQADDR; Val: $00440880),
  (Expr: E_MACROADDR; Val: $005718A0),
  (Expr: E_OLDDIR; Val: $005F5940),
  (Expr: E_PATHFINDADDR; Val: $004FBE99),
  (Expr: E_REDIR; Val: $0058AF5D),
  (Expr: E_SENDPACKET; Val: $0045DA20),
  (Expr: E_SLEEPADDR; Val: $006560EC),
  (Expr: E_SYSMSGADDR; Val: $005C0AD0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 55 -- first introduced at client '7.0.4.4' (normalized '007.000.004.004')
SysVarMS55 : array[0..31] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $0095F700),
  (Expr: C_CHARPTR; Val: $009A3764),
  (Expr: C_CLILEFT; Val: $00962AE0),
  (Expr: C_CLILOGGED; Val: $006C507C),
  (Expr: C_CLIXRES; Val: $006C560C),
  (Expr: C_CONTPOS; Val: $0083E5E8),
  (Expr: C_CURSORKIND; Val: $00962A5D),
  (Expr: C_ENEMYHITS; Val: $009067B4),
  (Expr: C_ENEMYID; Val: $00837BD0),
  (Expr: C_JOURNALPTR; Val: $009E0100),
  (Expr: C_LHANDID; Val: $0095E944),
  (Expr: C_LLIFTEDID; Val: $009A37B0),
  (Expr: C_LSHARD; Val: $009A7DF8),
  (Expr: C_NEXTCPOS; Val: $0083DB5C),
  (Expr: C_POPUPID; Val: $009A7F6C),
  (Expr: C_SHARDPOS; Val: $0083D9D0),
  (Expr: C_SKILLCAPS; Val: $00A223F0),
  (Expr: C_SKILLLOCK; Val: $00A223B4),
  (Expr: C_SKILLSPOS; Val: $00A22468),
  (Expr: C_SYSMSG; Val: $0083E5C8),
  (Expr: C_TARGETCURS; Val: $00962AB4),
  (Expr: E_DRAGADDR; Val: $00597950),
  (Expr: E_EXMSGADDR; Val: $005961E0),
  (Expr: E_ITEMNAMEADDR; Val: $00569580),
  (Expr: E_ITEMPROPADDR; Val: $00569490),
  (Expr: E_ITEMPROPID; Val: $0095A8BC),
  (Expr: E_MACROADDR; Val: $00571790),
  (Expr: E_OLDDIR; Val: $005F5830),
  (Expr: E_REDIR; Val: $0058AE4D),
  (Expr: E_SLEEPADDR; Val: $006550EC),
  (Expr: E_SYSMSGADDR; Val: $005C09C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 56 -- first introduced at client '7.0.4.3' (normalized '007.000.004.003')
SysVarMS56 : array[0..31] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00960700),
  (Expr: C_CHARPTR; Val: $009A4764),
  (Expr: C_CLILEFT; Val: $00963AE0),
  (Expr: C_CLILOGGED; Val: $006C607C),
  (Expr: C_CLIXRES; Val: $006C660C),
  (Expr: C_CONTPOS; Val: $0083F5E8),
  (Expr: C_CURSORKIND; Val: $00963A5D),
  (Expr: C_ENEMYHITS; Val: $009077B4),
  (Expr: C_ENEMYID; Val: $00838BD0),
  (Expr: C_JOURNALPTR; Val: $009E1100),
  (Expr: C_LHANDID; Val: $0095F944),
  (Expr: C_LLIFTEDID; Val: $009A47B0),
  (Expr: C_LSHARD; Val: $009A8DF8),
  (Expr: C_NEXTCPOS; Val: $0083EB5C),
  (Expr: C_POPUPID; Val: $009A8F6C),
  (Expr: C_SHARDPOS; Val: $0083E9D0),
  (Expr: C_SKILLCAPS; Val: $00A233F0),
  (Expr: C_SKILLLOCK; Val: $00A233B4),
  (Expr: C_SKILLSPOS; Val: $00A23468),
  (Expr: C_SYSMSG; Val: $0083F5C8),
  (Expr: C_TARGETCURS; Val: $00963AB4),
  (Expr: E_DRAGADDR; Val: $00598390),
  (Expr: E_EXMSGADDR; Val: $00596C20),
  (Expr: E_ITEMNAMEADDR; Val: $005695A0),
  (Expr: E_ITEMPROPADDR; Val: $005694B0),
  (Expr: E_ITEMPROPID; Val: $0095B8BC),
  (Expr: E_MACROADDR; Val: $005717B0),
  (Expr: E_OLDDIR; Val: $005F6270),
  (Expr: E_REDIR; Val: $0058B88D),
  (Expr: E_SLEEPADDR; Val: $006560EC),
  (Expr: E_SYSMSGADDR; Val: $005C1400),
  (Expr: LISTEND; Val: 0)
);

// Milestone 57 -- first introduced at client '7.0.4.2' (normalized '007.000.004.002')
SysVarMS57 : array[0..10] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004D6740),
  (Expr: E_DRAGADDR; Val: $00597950),
  (Expr: E_EXMSGADDR; Val: $005961E0),
  (Expr: E_ITEMNAMEADDR; Val: $00569580),
  (Expr: E_ITEMPROPADDR; Val: $00569490),
  (Expr: E_MACROADDR; Val: $00571790),
  (Expr: E_OLDDIR; Val: $005F5830),
  (Expr: E_PATHFINDADDR; Val: $004FBD99),
  (Expr: E_REDIR; Val: $0058AE4D),
  (Expr: E_SYSMSGADDR; Val: $005C09C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 58 -- first introduced at client '7.0.4.1' (normalized '007.000.004.001')
SysVarMS58 : array[0..10] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004D6630),
  (Expr: E_DRAGADDR; Val: $00597840),
  (Expr: E_EXMSGADDR; Val: $005960D0),
  (Expr: E_ITEMNAMEADDR; Val: $00569470),
  (Expr: E_ITEMPROPADDR; Val: $00569380),
  (Expr: E_MACROADDR; Val: $00571680),
  (Expr: E_OLDDIR; Val: $005F5720),
  (Expr: E_PATHFINDADDR; Val: $004FBC89),
  (Expr: E_REDIR; Val: $0058AD3D),
  (Expr: E_SYSMSGADDR; Val: $005C08B0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 59 -- first introduced at client '7.0.4.0' (normalized '007.000.004.000')
SysVarMS59 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $0095F700),
  (Expr: C_CHARPTR; Val: $009A3764),
  (Expr: C_CLILEFT; Val: $00962AE0),
  (Expr: C_CLILOGGED; Val: $006C507C),
  (Expr: C_CLIXRES; Val: $006C560C),
  (Expr: C_CONTPOS; Val: $0083E5E8),
  (Expr: C_CURSORKIND; Val: $00962A5D),
  (Expr: C_ENEMYHITS; Val: $009067B4),
  (Expr: C_ENEMYID; Val: $00837BD0),
  (Expr: C_JOURNALPTR; Val: $009E0100),
  (Expr: C_LHANDID; Val: $0095E944),
  (Expr: C_LLIFTEDID; Val: $009A37B0),
  (Expr: C_LSHARD; Val: $009A7DF8),
  (Expr: C_NEXTCPOS; Val: $0083DB5C),
  (Expr: C_POPUPID; Val: $009A7F6C),
  (Expr: C_SHARDPOS; Val: $0083D9D0),
  (Expr: C_SKILLCAPS; Val: $00A223F0),
  (Expr: C_SKILLLOCK; Val: $00A223B4),
  (Expr: C_SKILLSPOS; Val: $00A22468),
  (Expr: C_SYSMSG; Val: $0083E5C8),
  (Expr: C_TARGETCURS; Val: $00962AB4),
  (Expr: E_CONTTOP; Val: $004D6620),
  (Expr: E_DRAGADDR; Val: $00597830),
  (Expr: E_EXMSGADDR; Val: $005960C0),
  (Expr: E_ITEMNAMEADDR; Val: $00569460),
  (Expr: E_ITEMPROPADDR; Val: $00569370),
  (Expr: E_ITEMPROPID; Val: $0095A8BC),
  (Expr: E_MACROADDR; Val: $00571670),
  (Expr: E_OLDDIR; Val: $005F5710),
  (Expr: E_PATHFINDADDR; Val: $004FBC79),
  (Expr: E_REDIR; Val: $0058AD2D),
  (Expr: E_SENDPACKET; Val: $0045D9B0),
  (Expr: E_SLEEPADDR; Val: $006550EC),
  (Expr: E_SYSMSGADDR; Val: $005C08A0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 60 -- first introduced at client '7.0.3.0' (normalized '007.000.003.000')
SysVarMS60 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $0095C3C8),
  (Expr: C_CHARPTR; Val: $009A0304),
  (Expr: C_CLILEFT; Val: $0095F680),
  (Expr: C_CLILOGGED; Val: $006C205C),
  (Expr: C_CLIXRES; Val: $006C25E4),
  (Expr: C_CONTPOS; Val: $0083B314),
  (Expr: C_CURSORKIND; Val: $0095F5FD),
  (Expr: C_ENEMYHITS; Val: $009034DC),
  (Expr: C_ENEMYID; Val: $00834990),
  (Expr: C_JOURNALPTR; Val: $009DCCA0),
  (Expr: C_LHANDID; Val: $0095B66C),
  (Expr: C_LLIFTEDID; Val: $009A0350),
  (Expr: C_LSHARD; Val: $009A4998),
  (Expr: C_NEXTCPOS; Val: $0083A88C),
  (Expr: C_POPUPID; Val: $009A4B0C),
  (Expr: C_SHARDPOS; Val: $0083A790),
  (Expr: C_SKILLCAPS; Val: $00A1EF90),
  (Expr: C_SKILLLOCK; Val: $00A1EF54),
  (Expr: C_SKILLSPOS; Val: $00A1F008),
  (Expr: C_SYSMSG; Val: $0083B2F4),
  (Expr: C_TARGETCURS; Val: $0095F654),
  (Expr: E_CONTTOP; Val: $004D4D30),
  (Expr: E_DRAGADDR; Val: $00594D40),
  (Expr: E_EXMSGADDR; Val: $005935D0),
  (Expr: E_ITEMCHECKADDR; Val: $0043F650),
  (Expr: E_ITEMNAMEADDR; Val: $005676E0),
  (Expr: E_ITEMPROPADDR; Val: $005675F0),
  (Expr: E_ITEMPROPID; Val: $009575E4),
  (Expr: E_ITEMREQADDR; Val: $00440850),
  (Expr: E_MACROADDR; Val: $0056F8F0),
  (Expr: E_OLDDIR; Val: $005F4890),
  (Expr: E_PATHFINDADDR; Val: $004FA3F9),
  (Expr: E_REDIR; Val: $0058823C),
  (Expr: E_SENDPACKET; Val: $0045D9A0),
  (Expr: E_SLEEPADDR; Val: $006530EC),
  (Expr: E_SYSMSGADDR; Val: $005BDDB0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 61 -- first introduced at client '7.0.2.1' (normalized '007.000.002.001')
SysVarMS61 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $0095B3C8),
  (Expr: C_CHARPTR; Val: $0099F304),
  (Expr: C_CLILEFT; Val: $0095E680),
  (Expr: C_CLILOGGED; Val: $006C105C),
  (Expr: C_CLIXRES; Val: $006C15E4),
  (Expr: C_CONTPOS; Val: $0083A314),
  (Expr: C_CURSORKIND; Val: $0095E5FD),
  (Expr: C_ENEMYHITS; Val: $009024DC),
  (Expr: C_ENEMYID; Val: $00833990),
  (Expr: C_JOURNALPTR; Val: $009DBCA0),
  (Expr: C_LHANDID; Val: $0095A66C),
  (Expr: C_LLIFTEDID; Val: $0099F350),
  (Expr: C_LSHARD; Val: $009A3998),
  (Expr: C_NEXTCPOS; Val: $0083988C),
  (Expr: C_POPUPID; Val: $009A3B0C),
  (Expr: C_SHARDPOS; Val: $00839790),
  (Expr: C_SKILLCAPS; Val: $00A1DF90),
  (Expr: C_SKILLLOCK; Val: $00A1DF54),
  (Expr: C_SKILLSPOS; Val: $00A1E008),
  (Expr: C_SYSMSG; Val: $0083A2F4),
  (Expr: C_TARGETCURS; Val: $0095E654),
  (Expr: E_CONTTOP; Val: $004D4120),
  (Expr: E_DRAGADDR; Val: $00594110),
  (Expr: E_EXMSGADDR; Val: $005929A0),
  (Expr: E_ITEMCHECKADDR; Val: $0043EA40),
  (Expr: E_ITEMNAMEADDR; Val: $00566A80),
  (Expr: E_ITEMPROPADDR; Val: $00566990),
  (Expr: E_ITEMPROPID; Val: $009565E4),
  (Expr: E_ITEMREQADDR; Val: $0043FC40),
  (Expr: E_MACROADDR; Val: $0056EC90),
  (Expr: E_OLDDIR; Val: $005F3C50),
  (Expr: E_PATHFINDADDR; Val: $004F97B9),
  (Expr: E_REDIR; Val: $005875DC),
  (Expr: E_SENDPACKET; Val: $0045CD90),
  (Expr: E_SLEEPADDR; Val: $006520EC),
  (Expr: E_SYSMSGADDR; Val: $005BD170),
  (Expr: LISTEND; Val: 0)
);

// Milestone 62 -- first introduced at client '7.0.1.1' (normalized '007.000.001.001')
SysVarMS62 : array[0..10] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004D2F00),
  (Expr: E_DRAGADDR; Val: $00592EF0),
  (Expr: E_EXMSGADDR; Val: $00591780),
  (Expr: E_ITEMNAMEADDR; Val: $00565860),
  (Expr: E_ITEMPROPADDR; Val: $00565770),
  (Expr: E_MACROADDR; Val: $0056DA70),
  (Expr: E_OLDDIR; Val: $005F27C0),
  (Expr: E_PATHFINDADDR; Val: $004F8599),
  (Expr: E_REDIR; Val: $005863BC),
  (Expr: E_SYSMSGADDR; Val: $005BBF10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 63 -- first introduced at client '7.0.0.4' (normalized '007.000.000.004')
SysVarMS63 : array[0..13] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004D2E00),
  (Expr: E_DRAGADDR; Val: $00592E40),
  (Expr: E_EXMSGADDR; Val: $005916D0),
  (Expr: E_ITEMCHECKADDR; Val: $0043D810),
  (Expr: E_ITEMNAMEADDR; Val: $005657B0),
  (Expr: E_ITEMPROPADDR; Val: $005656C0),
  (Expr: E_ITEMREQADDR; Val: $0043EA10),
  (Expr: E_MACROADDR; Val: $0056D9C0),
  (Expr: E_OLDDIR; Val: $005F2710),
  (Expr: E_PATHFINDADDR; Val: $004F8499),
  (Expr: E_REDIR; Val: $0058630C),
  (Expr: E_SENDPACKET; Val: $0045BB60),
  (Expr: E_SYSMSGADDR; Val: $005BBE60),
  (Expr: LISTEND; Val: 0)
);

// Milestone 64 -- first introduced at client '7.0.0.3' (normalized '007.000.000.003')
SysVarMS64 : array[0..9] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00592DF0),
  (Expr: E_EXMSGADDR; Val: $00591680),
  (Expr: E_ITEMNAMEADDR; Val: $00565760),
  (Expr: E_ITEMPROPADDR; Val: $00565670),
  (Expr: E_MACROADDR; Val: $0056D970),
  (Expr: E_OLDDIR; Val: $005F26C0),
  (Expr: E_PATHFINDADDR; Val: $004F8449),
  (Expr: E_REDIR; Val: $005862BC),
  (Expr: E_SYSMSGADDR; Val: $005BBE10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 65 -- first introduced at client '7.0.0.2' (normalized '007.000.000.002')
SysVarMS65 : array[0..27] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00957BF8),
  (Expr: C_CHARPTR; Val: $0099BB34),
  (Expr: C_CLILEFT; Val: $0095AEB0),
  (Expr: C_CURSORKIND; Val: $0095AE2D),
  (Expr: C_JOURNALPTR; Val: $009D84D0),
  (Expr: C_LHANDID; Val: $00956E9C),
  (Expr: C_LLIFTEDID; Val: $0099BB80),
  (Expr: C_LSHARD; Val: $009A01C8),
  (Expr: C_POPUPID; Val: $009A033C),
  (Expr: C_SKILLCAPS; Val: $00A1A7C0),
  (Expr: C_SKILLLOCK; Val: $00A1A784),
  (Expr: C_SKILLSPOS; Val: $00A1A838),
  (Expr: C_TARGETCURS; Val: $0095AE84),
  (Expr: E_CONTTOP; Val: $004D2DE0),
  (Expr: E_DRAGADDR; Val: $00592E50),
  (Expr: E_EXMSGADDR; Val: $005916E0),
  (Expr: E_ITEMCHECKADDR; Val: $0043D7F0),
  (Expr: E_ITEMNAMEADDR; Val: $005657C0),
  (Expr: E_ITEMPROPADDR; Val: $005656D0),
  (Expr: E_ITEMPROPID; Val: $00952E14),
  (Expr: E_ITEMREQADDR; Val: $0043E9F0),
  (Expr: E_MACROADDR; Val: $0056D9D0),
  (Expr: E_OLDDIR; Val: $005F2720),
  (Expr: E_PATHFINDADDR; Val: $004F84A9),
  (Expr: E_REDIR; Val: $0058631C),
  (Expr: E_SENDPACKET; Val: $0045BB40),
  (Expr: E_SYSMSGADDR; Val: $005BBE70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 66 -- first introduced at client '7.0.0.0' (normalized '007.000.000.000')
SysVarMS66 : array[0..40] of TSysVarList = (
  (Expr: B_FINDREP; Val: $000001A8),
  (Expr: B_ITEMID; Val: $00000088),
  (Expr: B_LLIFTEDKIND; Val: $00000038),
  (Expr: B_SKILLDIST; Val: $00000078),
  (Expr: C_CHARDIR; Val: $00957BE0),
  (Expr: C_CHARPTR; Val: $0099BB1C),
  (Expr: C_CLILEFT; Val: $0095AE98),
  (Expr: C_CLILOGGED; Val: $006BE05C),
  (Expr: C_CLIXRES; Val: $006BE5E4),
  (Expr: C_CONTPOS; Val: $00837314),
  (Expr: C_CURSORKIND; Val: $0095AE15),
  (Expr: C_ENEMYHITS; Val: $008FF4DC),
  (Expr: C_ENEMYID; Val: $00830990),
  (Expr: C_JOURNALPTR; Val: $009D84B8),
  (Expr: C_LHANDID; Val: $00956E84),
  (Expr: C_LLIFTEDID; Val: $0099BB68),
  (Expr: C_LSHARD; Val: $009A01B0),
  (Expr: C_NEXTCPOS; Val: $0083688C),
  (Expr: C_POPUPID; Val: $009A0324),
  (Expr: C_SHARDPOS; Val: $00836790),
  (Expr: C_SKILLCAPS; Val: $00A1A7A8),
  (Expr: C_SKILLLOCK; Val: $00A1A76C),
  (Expr: C_SKILLSPOS; Val: $00A1A820),
  (Expr: C_SYSMSG; Val: $008372F4),
  (Expr: C_TARGETCURS; Val: $0095AE6C),
  (Expr: E_CONTTOP; Val: $004D2BA0),
  (Expr: E_DRAGADDR; Val: $00592AF0),
  (Expr: E_EXMSGADDR; Val: $00591380),
  (Expr: E_ITEMCHECKADDR; Val: $0043D5E0),
  (Expr: E_ITEMNAMEADDR; Val: $00565460),
  (Expr: E_ITEMPROPADDR; Val: $00565370),
  (Expr: E_ITEMPROPID; Val: $00952DFC),
  (Expr: E_ITEMREQADDR; Val: $0043E7E0),
  (Expr: E_MACROADDR; Val: $0056D670),
  (Expr: E_OLDDIR; Val: $005F23B0),
  (Expr: E_PATHFINDADDR; Val: $004F8269),
  (Expr: E_REDIR; Val: $00585FBC),
  (Expr: E_SENDPACKET; Val: $0045B900),
  (Expr: E_SLEEPADDR; Val: $006500EC),
  (Expr: E_SYSMSGADDR; Val: $005BBB00),
  (Expr: LISTEND; Val: 0)
);

// Milestone 67 -- first introduced at client '6.0.14.2' (normalized '006.000.014.002')
SysVarMS67 : array[0..10] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $0047BFD0),
  (Expr: E_DRAGADDR; Val: $00511320),
  (Expr: E_EXMSGADDR; Val: $0050F220),
  (Expr: E_ITEMNAMEADDR; Val: $004EE4D0),
  (Expr: E_ITEMPROPADDR; Val: $004EE3E0),
  (Expr: E_MACROADDR; Val: $004F50C0),
  (Expr: E_OLDDIR; Val: $00544670),
  (Expr: E_PATHFINDADDR; Val: $0049A129),
  (Expr: E_REDIR; Val: $005063CC),
  (Expr: E_SYSMSGADDR; Val: $0052BF10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 68 -- first introduced at client '6.0.13.0' (normalized '006.000.013.000')
SysVarMS68 : array[0..11] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $0047C000),
  (Expr: E_DRAGADDR; Val: $00511350),
  (Expr: E_EXMSGADDR; Val: $0050F250),
  (Expr: E_ITEMNAMEADDR; Val: $004EE500),
  (Expr: E_ITEMPROPADDR; Val: $004EE410),
  (Expr: E_MACROADDR; Val: $004F50F0),
  (Expr: E_OLDDIR; Val: $005446A0),
  (Expr: E_PATHFINDADDR; Val: $0049A159),
  (Expr: E_REDIR; Val: $005063FC),
  (Expr: E_SENDPACKET; Val: $0041D020),
  (Expr: E_SYSMSGADDR; Val: $0052BF40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 69 -- first introduced at client '6.0.12.4' (normalized '006.000.012.004')
SysVarMS69 : array[0..20] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007F46F0),
  (Expr: C_CHARPTR; Val: $00838634),
  (Expr: C_CLILEFT; Val: $007F79A8),
  (Expr: C_CONTPOS; Val: $006D45BC),
  (Expr: C_CURSORKIND; Val: $007F7925),
  (Expr: C_ENEMYHITS; Val: $0079C49C),
  (Expr: C_ENEMYID; Val: $006CDC38),
  (Expr: C_JOURNALPTR; Val: $00874E58),
  (Expr: C_LHANDID; Val: $007F3994),
  (Expr: C_LLIFTEDID; Val: $00838680),
  (Expr: C_LSHARD; Val: $0083CC30),
  (Expr: C_NEXTCPOS; Val: $006D3B34),
  (Expr: C_POPUPID; Val: $0083CDC4),
  (Expr: C_SHARDPOS; Val: $006D3A38),
  (Expr: C_SKILLCAPS; Val: $008B68A8),
  (Expr: C_SKILLLOCK; Val: $008B6918),
  (Expr: C_SKILLSPOS; Val: $008B6950),
  (Expr: C_SYSMSG; Val: $006D459C),
  (Expr: C_TARGETCURS; Val: $007F797C),
  (Expr: E_ITEMPROPID; Val: $007EF90C),
  (Expr: LISTEND; Val: 0)
);

// Milestone 70 -- first introduced at client '6.0.12.3' (normalized '006.000.012.003')
SysVarMS70 : array[0..12] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $0047BEE0),
  (Expr: E_DRAGADDR; Val: $00511F00),
  (Expr: E_EXMSGADDR; Val: $0050FDE0),
  (Expr: E_ITEMCHECKADDR; Val: $00406A30),
  (Expr: E_ITEMNAMEADDR; Val: $004EE700),
  (Expr: E_ITEMPROPADDR; Val: $004EE610),
  (Expr: E_ITEMREQADDR; Val: $00406370),
  (Expr: E_MACROADDR; Val: $004F53C0),
  (Expr: E_OLDDIR; Val: $00544F30),
  (Expr: E_PATHFINDADDR; Val: $0049A1C9),
  (Expr: E_REDIR; Val: $0050702C),
  (Expr: E_SENDPACKET; Val: $0041CF80),
  (Expr: LISTEND; Val: 0)
);

// Milestone 71 -- first introduced at client '6.0.12.0' (normalized '006.000.012.000')
SysVarMS71 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007F46D0),
  (Expr: C_CHARPTR; Val: $00838614),
  (Expr: C_CLILEFT; Val: $007F7988),
  (Expr: C_CLILOGGED; Val: $005E0D84),
  (Expr: C_CLIXRES; Val: $005E130C),
  (Expr: C_CONTPOS; Val: $006D459C),
  (Expr: C_CURSORKIND; Val: $007F7905),
  (Expr: C_ENEMYHITS; Val: $0079C47C),
  (Expr: C_ENEMYID; Val: $006CDC18),
  (Expr: C_JOURNALPTR; Val: $00874E38),
  (Expr: C_LHANDID; Val: $007F3974),
  (Expr: C_LLIFTEDID; Val: $00838660),
  (Expr: C_LSHARD; Val: $0083CC10),
  (Expr: C_NEXTCPOS; Val: $006D3B14),
  (Expr: C_POPUPID; Val: $0083CDA4),
  (Expr: C_SHARDPOS; Val: $006D3A18),
  (Expr: C_SKILLCAPS; Val: $008B6888),
  (Expr: C_SKILLLOCK; Val: $008B68F8),
  (Expr: C_SKILLSPOS; Val: $008B6930),
  (Expr: C_SYSMSG; Val: $006D457C),
  (Expr: C_TARGETCURS; Val: $007F795C),
  (Expr: E_CONTTOP; Val: $0047BF90),
  (Expr: E_DRAGADDR; Val: $00511F60),
  (Expr: E_EXMSGADDR; Val: $0050FE40),
  (Expr: E_ITEMCHECKADDR; Val: $00406B70),
  (Expr: E_ITEMNAMEADDR; Val: $004EE960),
  (Expr: E_ITEMPROPADDR; Val: $004EE870),
  (Expr: E_ITEMPROPID; Val: $007EF8EC),
  (Expr: E_ITEMREQADDR; Val: $004064B0),
  (Expr: E_MACROADDR; Val: $004F5500),
  (Expr: E_OLDDIR; Val: $00544EB0),
  (Expr: E_PATHFINDADDR; Val: $0049A209),
  (Expr: E_REDIR; Val: $0050703C),
  (Expr: E_SENDPACKET; Val: $0041D090),
  (Expr: E_SLEEPADDR; Val: $0058B098),
  (Expr: E_SYSMSGADDR; Val: $0052CA10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 72 -- first introduced at client '6.0.11.0' (normalized '006.000.011.000')
SysVarMS72 : array[0..15] of TSysVarList = (
  (Expr: C_CLILOGGED; Val: $005DDD84),
  (Expr: C_CLIXRES; Val: $005DE30C),
  (Expr: E_CONTTOP; Val: $0047C0E0),
  (Expr: E_DRAGADDR; Val: $0050EE50),
  (Expr: E_EXMSGADDR; Val: $0050CD40),
  (Expr: E_ITEMCHECKADDR; Val: $00406A10),
  (Expr: E_ITEMNAMEADDR; Val: $004EE5E0),
  (Expr: E_ITEMPROPADDR; Val: $004EE4F0),
  (Expr: E_ITEMREQADDR; Val: $00406350),
  (Expr: E_MACROADDR; Val: $004F5040),
  (Expr: E_OLDDIR; Val: $00541F30),
  (Expr: E_PATHFINDADDR; Val: $0049A3F9),
  (Expr: E_REDIR; Val: $0050583C),
  (Expr: E_SENDPACKET; Val: $0041D0E0),
  (Expr: E_SYSMSGADDR; Val: $00529A10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 73 -- first introduced at client '6.0.8.0' (normalized '006.000.008.000')
SysVarMS73 : array[0..1] of TSysVarList = (
  (Expr: E_OLDDIR; Val: $005420C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 74 -- first introduced at client '6.0.7.0' (normalized '006.000.007.000')
SysVarMS74 : array[0..13] of TSysVarList = (
  (Expr: E_CONTTOP; Val: $004789C0),
  (Expr: E_DRAGADDR; Val: $0050BD00),
  (Expr: E_EXMSGADDR; Val: $00509BE0),
  (Expr: E_ITEMCHECKADDR; Val: $00403430),
  (Expr: E_ITEMNAMEADDR; Val: $004EB350),
  (Expr: E_ITEMPROPADDR; Val: $004EB260),
  (Expr: E_ITEMREQADDR; Val: $00402D70),
  (Expr: E_MACROADDR; Val: $004F1DB0),
  (Expr: E_OLDDIR; Val: $00542090),
  (Expr: E_PATHFINDADDR; Val: $00496CC9),
  (Expr: E_REDIR; Val: $0050266C),
  (Expr: E_SENDPACKET; Val: $00419BB0),
  (Expr: E_SYSMSGADDR; Val: $00526710),
  (Expr: LISTEND; Val: 0)
);

// Milestone 75 -- first introduced at client '6.0.6.2' (normalized '006.000.006.002')
SysVarMS75 : array[0..45] of TSysVarList = (
  (Expr: B_LANG; Val: $00000060),
  (Expr: B_LLIFTEDKIND; Val: $00000034),
  (Expr: B_LLIFTEDTYPE; Val: $00000004),
  (Expr: B_LTARGTILE; Val: $0000001C),
  (Expr: B_LTARGX; Val: $000001A8),
  (Expr: B_TARGPROC; Val: $0000000C),
  (Expr: C_CHARDIR; Val: $007F16D0),
  (Expr: C_CHARPTR; Val: $00835604),
  (Expr: C_CLILEFT; Val: $007F4988),
  (Expr: C_CLILOGGED; Val: $005DC714),
  (Expr: C_CLIXRES; Val: $005DCC9C),
  (Expr: C_CONTPOS; Val: $006D159C),
  (Expr: C_CURSORKIND; Val: $007F4905),
  (Expr: C_ENEMYHITS; Val: $0079947C),
  (Expr: C_ENEMYID; Val: $006CAC18),
  (Expr: C_JOURNALPTR; Val: $00871E28),
  (Expr: C_LHANDID; Val: $007F0974),
  (Expr: C_LLIFTEDID; Val: $00835650),
  (Expr: C_LSHARD; Val: $00839C00),
  (Expr: C_NEXTCPOS; Val: $006D0B14),
  (Expr: C_POPUPID; Val: $00839D94),
  (Expr: C_SHARDPOS; Val: $006D0A18),
  (Expr: C_SKILLCAPS; Val: $008B3878),
  (Expr: C_SKILLLOCK; Val: $008B38E8),
  (Expr: C_SKILLSPOS; Val: $008B3920),
  (Expr: C_SYSMSG; Val: $006D157C),
  (Expr: C_TARGETCNT; Val: $00000000),
  (Expr: C_TARGETCURS; Val: $007F495C),
  (Expr: E_CONTTOP; Val: $00478C00),
  (Expr: E_DRAGADDR; Val: $0050BA90),
  (Expr: E_EXMSGADDR; Val: $00509990),
  (Expr: E_ITEMCHECKADDR; Val: $004035B0),
  (Expr: E_ITEMNAMEADDR; Val: $004EB1E0),
  (Expr: E_ITEMPROPADDR; Val: $004EB0F0),
  (Expr: E_ITEMPROPID; Val: $007EC8EC),
  (Expr: E_ITEMREQADDR; Val: $00402EF0),
  (Expr: E_MACROADDR; Val: $004F1CC0),
  (Expr: E_OLDDIR; Val: $00542060),
  (Expr: E_PATHFINDADDR; Val: $00496E79),
  (Expr: E_REDIR; Val: $005023FC),
  (Expr: E_SENDPACKET; Val: $00419BA0),
  (Expr: E_SLEEPADDR; Val: $0058809C),
  (Expr: E_SYSMSGADDR; Val: $005265A0),
  (Expr: F_EXCHARSTATC; Val: $00000018),
  (Expr: F_PATHFINDVER; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 76 -- first introduced at client '6.0.6.1' (normalized '006.000.006.001')
SysVarMS76 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D95A8),
  (Expr: C_CHARPTR; Val: $0081D9F4),
  (Expr: C_CLILEFT; Val: $0081D454),
  (Expr: C_CLILOGGED; Val: $005BE34C),
  (Expr: C_CLIXRES; Val: $005BFB80),
  (Expr: C_CONTPOS; Val: $006B94D8),
  (Expr: C_CURSORKIND; Val: $0081D3D4),
  (Expr: C_ENEMYHITS; Val: $00781360),
  (Expr: C_ENEMYID; Val: $006B2AE8),
  (Expr: C_JOURNALPTR; Val: $00859E7C),
  (Expr: C_LHANDID; Val: $007D8940),
  (Expr: C_LLIFTEDID; Val: $0081DA40),
  (Expr: C_LSHARD; Val: $00821B60),
  (Expr: C_NEXTCPOS; Val: $006B8A4C),
  (Expr: C_POPUPID; Val: $00821CD0),
  (Expr: C_SHARDPOS; Val: $006B88E4),
  (Expr: C_SKILLCAPS; Val: $0089C184),
  (Expr: C_SKILLLOCK; Val: $0089C1F4),
  (Expr: C_SKILLSPOS; Val: $0089C22C),
  (Expr: C_SYSMSG; Val: $006B94B8),
  (Expr: C_TARGETCNT; Val: $0081A7E8),
  (Expr: C_TARGETCURS; Val: $0081D424),
  (Expr: E_DRAGADDR; Val: $00518E80),
  (Expr: E_EXMSGADDR; Val: $00513F10),
  (Expr: E_ITEMCHECKADDR; Val: $0053E360),
  (Expr: E_ITEMNAMEADDR; Val: $004F3AF0),
  (Expr: E_ITEMPROPADDR; Val: $004F3A10),
  (Expr: E_ITEMPROPID; Val: $007D47BC),
  (Expr: E_ITEMREQADDR; Val: $0053E990),
  (Expr: E_MACROADDR; Val: $004F8220),
  (Expr: E_OLDDIR; Val: $00553530),
  (Expr: E_PATHFINDADDR; Val: $0049C0FD),
  (Expr: E_REDIR; Val: $005091AC),
  (Expr: E_SENDPACKET; Val: $004169E0),
  (Expr: E_SLEEPADDR; Val: $0057C22C),
  (Expr: E_SYSMSGADDR; Val: $005280E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 77 -- first introduced at client '6.0.6.0' (normalized '006.000.006.000')
SysVarMS77 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007DA658),
  (Expr: C_CHARPTR; Val: $0081EAEC),
  (Expr: C_CLILEFT; Val: $0081E54C),
  (Expr: C_CLILOGGED; Val: $005BF394),
  (Expr: C_CLIXRES; Val: $005C0BC8),
  (Expr: C_CONTPOS; Val: $006BA578),
  (Expr: C_CURSORKIND; Val: $0081E4CC),
  (Expr: C_ENEMYHITS; Val: $00782400),
  (Expr: C_ENEMYID; Val: $006B3B88),
  (Expr: C_JOURNALPTR; Val: $0085AF74),
  (Expr: C_LHANDID; Val: $007D99E0),
  (Expr: C_LLIFTEDID; Val: $0081EB38),
  (Expr: C_LSHARD; Val: $00822C58),
  (Expr: C_NEXTCPOS; Val: $006B9AEC),
  (Expr: C_POPUPID; Val: $00822DC8),
  (Expr: C_SHARDPOS; Val: $006B9984),
  (Expr: C_SKILLCAPS; Val: $0089D27C),
  (Expr: C_SKILLLOCK; Val: $0089D2EC),
  (Expr: C_SKILLSPOS; Val: $0089D324),
  (Expr: C_SYSMSG; Val: $006BA558),
  (Expr: C_TARGETCNT; Val: $0081B8E0),
  (Expr: C_TARGETCURS; Val: $0081E51C),
  (Expr: E_DRAGADDR; Val: $005197B0),
  (Expr: E_EXMSGADDR; Val: $00514880),
  (Expr: E_ITEMCHECKADDR; Val: $0053EB70),
  (Expr: E_ITEMNAMEADDR; Val: $004F3FE0),
  (Expr: E_ITEMPROPADDR; Val: $004F3F00),
  (Expr: E_ITEMPROPID; Val: $007D585C),
  (Expr: E_ITEMREQADDR; Val: $0053F1A0),
  (Expr: E_MACROADDR; Val: $004F8710),
  (Expr: E_OLDDIR; Val: $00552E70),
  (Expr: E_PATHFINDADDR; Val: $0049C3AD),
  (Expr: E_REDIR; Val: $00509ABC),
  (Expr: E_SENDPACKET; Val: $00416B30),
  (Expr: E_SLEEPADDR; Val: $0057D22C),
  (Expr: E_SYSMSGADDR; Val: $00528A70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 78 -- first introduced at client '6.0.5.0' (normalized '006.000.005.000')
SysVarMS78 : array[0..12] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518E80),
  (Expr: E_EXMSGADDR; Val: $00513F10),
  (Expr: E_ITEMCHECKADDR; Val: $0053E360),
  (Expr: E_ITEMNAMEADDR; Val: $004F3AF0),
  (Expr: E_ITEMPROPADDR; Val: $004F3A10),
  (Expr: E_ITEMREQADDR; Val: $0053E990),
  (Expr: E_MACROADDR; Val: $004F8220),
  (Expr: E_OLDDIR; Val: $00553530),
  (Expr: E_PATHFINDADDR; Val: $0049C0FD),
  (Expr: E_REDIR; Val: $005091AC),
  (Expr: E_SENDPACKET; Val: $004169E0),
  (Expr: E_SYSMSGADDR; Val: $005280E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 79 -- first introduced at client '6.0.4.0' (normalized '006.000.004.000')
SysVarMS79 : array[0..22] of TSysVarList = (
  (Expr: C_CHARPTR; Val: $0081D9F4),
  (Expr: C_CLILEFT; Val: $0081D454),
  (Expr: C_CURSORKIND; Val: $0081D3D4),
  (Expr: C_JOURNALPTR; Val: $00859E7C),
  (Expr: C_LLIFTEDID; Val: $0081DA40),
  (Expr: C_LSHARD; Val: $00821B60),
  (Expr: C_POPUPID; Val: $00821CD0),
  (Expr: C_SKILLCAPS; Val: $0089C184),
  (Expr: C_SKILLLOCK; Val: $0089C1F4),
  (Expr: C_SKILLSPOS; Val: $0089C22C),
  (Expr: C_TARGETCNT; Val: $0081A7E8),
  (Expr: C_TARGETCURS; Val: $0081D424),
  (Expr: E_DRAGADDR; Val: $00518E00),
  (Expr: E_EXMSGADDR; Val: $00513E90),
  (Expr: E_ITEMCHECKADDR; Val: $0053E2E0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3A70),
  (Expr: E_ITEMPROPADDR; Val: $004F3990),
  (Expr: E_ITEMREQADDR; Val: $0053E910),
  (Expr: E_MACROADDR; Val: $004F81A0),
  (Expr: E_OLDDIR; Val: $005534B0),
  (Expr: E_PATHFINDADDR; Val: $0049C07D),
  (Expr: E_SYSMSGADDR; Val: $00528060),
  (Expr: LISTEND; Val: 0)
);

// Milestone 80 -- first introduced at client '6.0.3.0' (normalized '006.000.003.000')
SysVarMS80 : array[0..26] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D95A8),
  (Expr: C_CHARPTR; Val: $0081D974),
  (Expr: C_CLILEFT; Val: $0081D3D4),
  (Expr: C_CURSORKIND; Val: $0081D354),
  (Expr: C_JOURNALPTR; Val: $00859DFC),
  (Expr: C_LHANDID; Val: $007D8940),
  (Expr: C_LLIFTEDID; Val: $0081D9C0),
  (Expr: C_LSHARD; Val: $00821AE0),
  (Expr: C_POPUPID; Val: $00821C50),
  (Expr: C_SKILLCAPS; Val: $0089C104),
  (Expr: C_SKILLLOCK; Val: $0089C174),
  (Expr: C_SKILLSPOS; Val: $0089C1AC),
  (Expr: C_TARGETCNT; Val: $0081A76C),
  (Expr: C_TARGETCURS; Val: $0081D3A4),
  (Expr: E_DRAGADDR; Val: $00518DF0),
  (Expr: E_EXMSGADDR; Val: $00513E80),
  (Expr: E_ITEMCHECKADDR; Val: $0053E2D0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3A80),
  (Expr: E_ITEMPROPADDR; Val: $004F39A0),
  (Expr: E_ITEMPROPID; Val: $007D47BC),
  (Expr: E_ITEMREQADDR; Val: $0053E900),
  (Expr: E_MACROADDR; Val: $004F81B0),
  (Expr: E_OLDDIR; Val: $005534A0),
  (Expr: E_PATHFINDADDR; Val: $0049C08D),
  (Expr: E_REDIR; Val: $0050912C),
  (Expr: E_SYSMSGADDR; Val: $00528050),
  (Expr: LISTEND; Val: 0)
);

// Milestone 81 -- first introduced at client '6.0.1.7' (normalized '006.000.001.007')
SysVarMS81 : array[0..14] of TSysVarList = (
  (Expr: B_PACKETVER; Val: $00000001),
  (Expr: E_DRAGADDR; Val: $00518C60),
  (Expr: E_EXMSGADDR; Val: $00513CF0),
  (Expr: E_ITEMCHECKADDR; Val: $0053E230),
  (Expr: E_ITEMNAMEADDR; Val: $004F3970),
  (Expr: E_ITEMPROPADDR; Val: $004F3890),
  (Expr: E_ITEMREQADDR; Val: $0053E860),
  (Expr: E_MACROADDR; Val: $004F80A0),
  (Expr: E_OLDDIR; Val: $00553440),
  (Expr: E_PATHFINDADDR; Val: $0049C00D),
  (Expr: E_REDIR; Val: $0050901C),
  (Expr: E_SENDPACKET; Val: $004169D0),
  (Expr: E_SYSMSGADDR; Val: $00527F30),
  (Expr: F_PACKETVER; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 82 -- first introduced at client '6.0.1.5' (normalized '006.000.001.005')
SysVarMS82 : array[0..4] of TSysVarList = (
  (Expr: E_ITEMCHECKADDR; Val: $0053E1A0),
  (Expr: E_ITEMREQADDR; Val: $0053E7D0),
  (Expr: E_OLDDIR; Val: $00553420),
  (Expr: E_SYSMSGADDR; Val: $00527E70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 83 -- first introduced at client '6.0.1.3' (normalized '006.000.001.003')
SysVarMS83 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D95A0),
  (Expr: C_CHARPTR; Val: $0081D96C),
  (Expr: C_CLILEFT; Val: $0081D3CC),
  (Expr: C_CLILOGGED; Val: $005BE34C),
  (Expr: C_CLIXRES; Val: $005BFB80),
  (Expr: C_CONTPOS; Val: $006B94D8),
  (Expr: C_CURSORKIND; Val: $0081D34C),
  (Expr: C_ENEMYHITS; Val: $00781360),
  (Expr: C_ENEMYID; Val: $006B2AE8),
  (Expr: C_JOURNALPTR; Val: $00859DF4),
  (Expr: C_LHANDID; Val: $007D8938),
  (Expr: C_LLIFTEDID; Val: $0081D9B8),
  (Expr: C_LSHARD; Val: $00821AD8),
  (Expr: C_NEXTCPOS; Val: $006B8A4C),
  (Expr: C_POPUPID; Val: $00821C48),
  (Expr: C_SHARDPOS; Val: $006B88E4),
  (Expr: C_SKILLCAPS; Val: $0089C0FC),
  (Expr: C_SKILLLOCK; Val: $0089C16C),
  (Expr: C_SKILLSPOS; Val: $0089C1A4),
  (Expr: C_SYSMSG; Val: $006B94B8),
  (Expr: C_TARGETCNT; Val: $0081A764),
  (Expr: C_TARGETCURS; Val: $0081D39C),
  (Expr: E_DRAGADDR; Val: $00518BD0),
  (Expr: E_EXMSGADDR; Val: $00513C60),
  (Expr: E_ITEMCHECKADDR; Val: $0053E170),
  (Expr: E_ITEMNAMEADDR; Val: $004F37B0),
  (Expr: E_ITEMPROPADDR; Val: $004F36D0),
  (Expr: E_ITEMPROPID; Val: $007D47B4),
  (Expr: E_ITEMREQADDR; Val: $0053E7A0),
  (Expr: E_MACROADDR; Val: $004F7F40),
  (Expr: E_OLDDIR; Val: $005533F0),
  (Expr: E_PATHFINDADDR; Val: $0049BF8D),
  (Expr: E_REDIR; Val: $00508EEC),
  (Expr: E_SENDPACKET; Val: $004169C0),
  (Expr: E_SYSMSGADDR; Val: $00527E40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 84 -- first introduced at client '6.0.1.2' (normalized '006.000.001.002')
SysVarMS84 : array[0..12] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518B50),
  (Expr: E_EXMSGADDR; Val: $00513C30),
  (Expr: E_ITEMCHECKADDR; Val: $0053E010),
  (Expr: E_ITEMNAMEADDR; Val: $004F3A00),
  (Expr: E_ITEMPROPADDR; Val: $004F3920),
  (Expr: E_ITEMREQADDR; Val: $0053E640),
  (Expr: E_MACROADDR; Val: $004F8130),
  (Expr: E_OLDDIR; Val: $005531C0),
  (Expr: E_PATHFINDADDR; Val: $0049BCDD),
  (Expr: E_REDIR; Val: $00508F5C),
  (Expr: E_SENDPACKET; Val: $00416B60),
  (Expr: E_SYSMSGADDR; Val: $00527DD0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 85 -- first introduced at client '6.0.1.0' (normalized '006.000.001.000')
SysVarMS85 : array[0..32] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D9520),
  (Expr: C_CHARPTR; Val: $0081D8EC),
  (Expr: C_CLILEFT; Val: $0081D34C),
  (Expr: C_CONTPOS; Val: $006B9458),
  (Expr: C_CURSORKIND; Val: $0081D2CC),
  (Expr: C_ENEMYHITS; Val: $007812E0),
  (Expr: C_ENEMYID; Val: $006B2A68),
  (Expr: C_JOURNALPTR; Val: $00859D74),
  (Expr: C_LHANDID; Val: $007D88B8),
  (Expr: C_LLIFTEDID; Val: $0081D938),
  (Expr: C_LSHARD; Val: $00821A58),
  (Expr: C_NEXTCPOS; Val: $006B89CC),
  (Expr: C_POPUPID; Val: $00821BC8),
  (Expr: C_SHARDPOS; Val: $006B8864),
  (Expr: C_SKILLCAPS; Val: $0089C07C),
  (Expr: C_SKILLLOCK; Val: $0089C0EC),
  (Expr: C_SKILLSPOS; Val: $0089C124),
  (Expr: C_SYSMSG; Val: $006B9438),
  (Expr: C_TARGETCNT; Val: $0081A6E4),
  (Expr: C_TARGETCURS; Val: $0081D31C),
  (Expr: E_DRAGADDR; Val: $00518CE0),
  (Expr: E_EXMSGADDR; Val: $00513DB0),
  (Expr: E_ITEMCHECKADDR; Val: $0053DF20),
  (Expr: E_ITEMNAMEADDR; Val: $004F3AE0),
  (Expr: E_ITEMPROPADDR; Val: $004F3A00),
  (Expr: E_ITEMPROPID; Val: $007D4734),
  (Expr: E_ITEMREQADDR; Val: $0053E550),
  (Expr: E_MACROADDR; Val: $004F8270),
  (Expr: E_OLDDIR; Val: $00553190),
  (Expr: E_PATHFINDADDR; Val: $0049BD3D),
  (Expr: E_REDIR; Val: $0050910C),
  (Expr: E_SYSMSGADDR; Val: $00527ED0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 86 -- first introduced at client '6.0.0.0' (normalized '006.000.000.000')
SysVarMS86 : array[0..33] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D9550),
  (Expr: C_CHARPTR; Val: $0081D91C),
  (Expr: C_CLILEFT; Val: $0081D37C),
  (Expr: C_CONTPOS; Val: $006B9488),
  (Expr: C_CURSORKIND; Val: $0081D2FC),
  (Expr: C_ENEMYHITS; Val: $00781310),
  (Expr: C_ENEMYID; Val: $006B2A98),
  (Expr: C_JOURNALPTR; Val: $00859DA4),
  (Expr: C_LHANDID; Val: $007D88E8),
  (Expr: C_LLIFTEDID; Val: $0081D968),
  (Expr: C_LSHARD; Val: $00821A88),
  (Expr: C_NEXTCPOS; Val: $006B89FC),
  (Expr: C_POPUPID; Val: $00821BF8),
  (Expr: C_SHARDPOS; Val: $006B8894),
  (Expr: C_SKILLCAPS; Val: $0089C0AC),
  (Expr: C_SKILLLOCK; Val: $0089C11C),
  (Expr: C_SKILLSPOS; Val: $0089C154),
  (Expr: C_SYSMSG; Val: $006B9468),
  (Expr: C_TARGETCNT; Val: $0081A714),
  (Expr: C_TARGETCURS; Val: $0081D34C),
  (Expr: E_DRAGADDR; Val: $00518DA0),
  (Expr: E_EXMSGADDR; Val: $00513E70),
  (Expr: E_ITEMCHECKADDR; Val: $0053DF30),
  (Expr: E_ITEMNAMEADDR; Val: $004F3AA0),
  (Expr: E_ITEMPROPADDR; Val: $004F39C0),
  (Expr: E_ITEMPROPID; Val: $007D4764),
  (Expr: E_ITEMREQADDR; Val: $0053E560),
  (Expr: E_MACROADDR; Val: $004F81D0),
  (Expr: E_OLDDIR; Val: $00553140),
  (Expr: E_PATHFINDADDR; Val: $0049C08D),
  (Expr: E_REDIR; Val: $0050900C),
  (Expr: E_SENDPACKET; Val: $004169D0),
  (Expr: E_SYSMSGADDR; Val: $00528010),
  (Expr: LISTEND; Val: 0)
);

// Milestone 87 -- first introduced at client '5.0.9.1' (normalized '005.000.009.001')
SysVarMS87 : array[0..4] of TSysVarList = (
  (Expr: E_ITEMCHECKADDR; Val: $0053DE50),
  (Expr: E_ITEMREQADDR; Val: $0053E480),
  (Expr: E_OLDDIR; Val: $00552FE0),
  (Expr: E_SYSMSGADDR; Val: $00527E90),
  (Expr: LISTEND; Val: 0)
);

// Milestone 88 -- first introduced at client '5.0.9.0' (normalized '005.000.009.000')
SysVarMS88 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D94A0),
  (Expr: C_CHARPTR; Val: $0081D86C),
  (Expr: C_CLILEFT; Val: $0081D2CC),
  (Expr: C_CLILOGGED; Val: $005BE2C4),
  (Expr: C_CLIXRES; Val: $005BFAF8),
  (Expr: C_CONTPOS; Val: $006B93F8),
  (Expr: C_CURSORKIND; Val: $0081D24C),
  (Expr: C_ENEMYHITS; Val: $00781280),
  (Expr: C_ENEMYID; Val: $006B2A08),
  (Expr: C_JOURNALPTR; Val: $00859CF4),
  (Expr: C_LHANDID; Val: $007D8838),
  (Expr: C_LLIFTEDID; Val: $0081D8B8),
  (Expr: C_LSHARD; Val: $008219D8),
  (Expr: C_NEXTCPOS; Val: $006B896C),
  (Expr: C_POPUPID; Val: $00821B48),
  (Expr: C_SHARDPOS; Val: $006B8804),
  (Expr: C_SKILLCAPS; Val: $0089BFFC),
  (Expr: C_SKILLLOCK; Val: $0089C06C),
  (Expr: C_SKILLSPOS; Val: $0089C0A4),
  (Expr: C_SYSMSG; Val: $006B93D8),
  (Expr: C_TARGETCNT; Val: $0081A664),
  (Expr: C_TARGETCURS; Val: $0081D29C),
  (Expr: E_DRAGADDR; Val: $00518CA0),
  (Expr: E_EXMSGADDR; Val: $00513DA0),
  (Expr: E_ITEMCHECKADDR; Val: $0053DEA0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3870),
  (Expr: E_ITEMPROPADDR; Val: $004F3790),
  (Expr: E_ITEMPROPID; Val: $007D46B4),
  (Expr: E_ITEMREQADDR; Val: $0053E4D0),
  (Expr: E_MACROADDR; Val: $004F7FA0),
  (Expr: E_OLDDIR; Val: $00553030),
  (Expr: E_PATHFINDADDR; Val: $0049BF5D),
  (Expr: E_REDIR; Val: $00508F6C),
  (Expr: E_SENDPACKET; Val: $00416A20),
  (Expr: E_SLEEPADDR; Val: $0057C22C),
  (Expr: E_SYSMSGADDR; Val: $00527EE0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 89 -- first introduced at client '5.0.8.1' (normalized '005.000.008.001')
SysVarMS89 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D8480),
  (Expr: C_CHARPTR; Val: $0081C84C),
  (Expr: C_CLILEFT; Val: $0081C2AC),
  (Expr: C_CLILOGGED; Val: $005BD2A4),
  (Expr: C_CLIXRES; Val: $005BEAD8),
  (Expr: C_CONTPOS; Val: $006B83D8),
  (Expr: C_CURSORKIND; Val: $0081C22C),
  (Expr: C_ENEMYHITS; Val: $00780260),
  (Expr: C_ENEMYID; Val: $006B19E8),
  (Expr: C_JOURNALPTR; Val: $00858CD4),
  (Expr: C_LHANDID; Val: $007D7818),
  (Expr: C_LLIFTEDID; Val: $0081C898),
  (Expr: C_LSHARD; Val: $008209B8),
  (Expr: C_NEXTCPOS; Val: $006B794C),
  (Expr: C_POPUPID; Val: $00820B28),
  (Expr: C_SHARDPOS; Val: $006B77E4),
  (Expr: C_SKILLCAPS; Val: $0089AFDC),
  (Expr: C_SKILLLOCK; Val: $0089B04C),
  (Expr: C_SKILLSPOS; Val: $0089B084),
  (Expr: C_SYSMSG; Val: $006B83B8),
  (Expr: C_TARGETCNT; Val: $00819644),
  (Expr: C_TARGETCURS; Val: $0081C27C),
  (Expr: E_DRAGADDR; Val: $005181F0),
  (Expr: E_EXMSGADDR; Val: $00513A30),
  (Expr: E_ITEMCHECKADDR; Val: $0053D5F0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3490),
  (Expr: E_ITEMPROPADDR; Val: $004F33B0),
  (Expr: E_ITEMPROPID; Val: $007D3694),
  (Expr: E_ITEMREQADDR; Val: $0053DC20),
  (Expr: E_MACROADDR; Val: $004F7BC0),
  (Expr: E_OLDDIR; Val: $005527D0),
  (Expr: E_PATHFINDADDR; Val: $0049BBBD),
  (Expr: E_REDIR; Val: $00508D1C),
  (Expr: E_SENDPACKET; Val: $004169F0),
  (Expr: E_SLEEPADDR; Val: $0057B22C),
  (Expr: E_SYSMSGADDR; Val: $00527430),
  (Expr: LISTEND; Val: 0)
);

// Milestone 90 -- first introduced at client '5.0.7.2' (normalized '005.000.007.002')
SysVarMS90 : array[0..10] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00519A20),
  (Expr: E_EXMSGADDR; Val: $00515240),
  (Expr: E_ITEMCHECKADDR; Val: $0053EDD0),
  (Expr: E_ITEMNAMEADDR; Val: $004F36B0),
  (Expr: E_ITEMPROPADDR; Val: $004F35D0),
  (Expr: E_ITEMREQADDR; Val: $0053F400),
  (Expr: E_MACROADDR; Val: $004F7DE0),
  (Expr: E_OLDDIR; Val: $00553FB0),
  (Expr: E_REDIR; Val: $0050A4FC),
  (Expr: E_SYSMSGADDR; Val: $00528C10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 91 -- first introduced at client '5.0.7.1' (normalized '005.000.007.001')
SysVarMS91 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007DA480),
  (Expr: C_CHARPTR; Val: $0081E84C),
  (Expr: C_CLILEFT; Val: $0081E2AC),
  (Expr: C_CLILOGGED; Val: $005BF2A4),
  (Expr: C_CLIXRES; Val: $005C0AD8),
  (Expr: C_CONTPOS; Val: $006BA3D8),
  (Expr: C_CURSORKIND; Val: $0081E22C),
  (Expr: C_ENEMYHITS; Val: $00782260),
  (Expr: C_ENEMYID; Val: $006B39E8),
  (Expr: C_JOURNALPTR; Val: $0085ACD4),
  (Expr: C_LHANDID; Val: $007D9818),
  (Expr: C_LLIFTEDID; Val: $0081E898),
  (Expr: C_LSHARD; Val: $008229B8),
  (Expr: C_NEXTCPOS; Val: $006B994C),
  (Expr: C_POPUPID; Val: $00822B28),
  (Expr: C_SHARDPOS; Val: $006B97E4),
  (Expr: C_SKILLCAPS; Val: $0089CFDC),
  (Expr: C_SKILLLOCK; Val: $0089D04C),
  (Expr: C_SKILLSPOS; Val: $0089D084),
  (Expr: C_SYSMSG; Val: $006BA3B8),
  (Expr: C_TARGETCNT; Val: $0081B644),
  (Expr: C_TARGETCURS; Val: $0081E27C),
  (Expr: E_DRAGADDR; Val: $00519B40),
  (Expr: E_EXMSGADDR; Val: $00515360),
  (Expr: E_ITEMCHECKADDR; Val: $0053EEF0),
  (Expr: E_ITEMNAMEADDR; Val: $004F37D0),
  (Expr: E_ITEMPROPADDR; Val: $004F36F0),
  (Expr: E_ITEMPROPID; Val: $007D5694),
  (Expr: E_ITEMREQADDR; Val: $0053F520),
  (Expr: E_MACROADDR; Val: $004F7F00),
  (Expr: E_OLDDIR; Val: $005540D0),
  (Expr: E_PATHFINDADDR; Val: $0049BD5D),
  (Expr: E_REDIR; Val: $0050A61C),
  (Expr: E_SENDPACKET; Val: $004169C0),
  (Expr: E_SLEEPADDR; Val: $0057D22C),
  (Expr: E_SYSMSGADDR; Val: $00528D30),
  (Expr: LISTEND; Val: 0)
);

// Milestone 92 -- first introduced at client '5.0.6.5' (normalized '005.000.006.005')
SysVarMS92 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D9480),
  (Expr: C_CHARPTR; Val: $0081D84C),
  (Expr: C_CLILEFT; Val: $0081D2AC),
  (Expr: C_CLILOGGED; Val: $005BE2A4),
  (Expr: C_CLIXRES; Val: $005BFAD8),
  (Expr: C_CONTPOS; Val: $006B93D8),
  (Expr: C_CURSORKIND; Val: $0081D22C),
  (Expr: C_ENEMYHITS; Val: $00781260),
  (Expr: C_ENEMYID; Val: $006B29E8),
  (Expr: C_JOURNALPTR; Val: $00859CD4),
  (Expr: C_LHANDID; Val: $007D8818),
  (Expr: C_LLIFTEDID; Val: $0081D898),
  (Expr: C_LSHARD; Val: $008219B8),
  (Expr: C_NEXTCPOS; Val: $006B894C),
  (Expr: C_POPUPID; Val: $00821B28),
  (Expr: C_SHARDPOS; Val: $006B87E4),
  (Expr: C_SKILLCAPS; Val: $0089BF64),
  (Expr: C_SKILLLOCK; Val: $0089BFD4),
  (Expr: C_SKILLSPOS; Val: $0089C00C),
  (Expr: C_SYSMSG; Val: $006B93B8),
  (Expr: C_TARGETCNT; Val: $0081A644),
  (Expr: C_TARGETCURS; Val: $0081D27C),
  (Expr: E_DRAGADDR; Val: $005183B0),
  (Expr: E_EXMSGADDR; Val: $00513BF0),
  (Expr: E_ITEMCHECKADDR; Val: $0053D7B0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3650),
  (Expr: E_ITEMPROPADDR; Val: $004F3570),
  (Expr: E_ITEMPROPID; Val: $007D4694),
  (Expr: E_ITEMREQADDR; Val: $0053DDE0),
  (Expr: E_MACROADDR; Val: $004F7D80),
  (Expr: E_OLDDIR; Val: $00552990),
  (Expr: E_PATHFINDADDR; Val: $0049BC5D),
  (Expr: E_REDIR; Val: $00508EDC),
  (Expr: E_SENDPACKET; Val: $004169F0),
  (Expr: E_SLEEPADDR; Val: $0057C22C),
  (Expr: E_SYSMSGADDR; Val: $005275F0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 93 -- first introduced at client '5.0.5c' (normalized '005.000.005.c')
SysVarMS93 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D7458),
  (Expr: C_CHARPTR; Val: $0081B824),
  (Expr: C_CLILEFT; Val: $0081B284),
  (Expr: C_CLILOGGED; Val: $005BC284),
  (Expr: C_CLIXRES; Val: $005BDAB8),
  (Expr: C_CONTPOS; Val: $006B73B0),
  (Expr: C_CURSORKIND; Val: $0081B204),
  (Expr: C_ENEMYHITS; Val: $0077F238),
  (Expr: C_ENEMYID; Val: $006B09C0),
  (Expr: C_JOURNALPTR; Val: $00857CAC),
  (Expr: C_LHANDID; Val: $007D67F0),
  (Expr: C_LLIFTEDID; Val: $0081B870),
  (Expr: C_LSHARD; Val: $0081F990),
  (Expr: C_NEXTCPOS; Val: $006B6924),
  (Expr: C_POPUPID; Val: $0081FB00),
  (Expr: C_SHARDPOS; Val: $006B67BC),
  (Expr: C_SKILLCAPS; Val: $00899F3C),
  (Expr: C_SKILLLOCK; Val: $00899FAC),
  (Expr: C_SKILLSPOS; Val: $00899FE4),
  (Expr: C_SYSMSG; Val: $006B7390),
  (Expr: C_TARGETCNT; Val: $0081861C),
  (Expr: C_TARGETCURS; Val: $0081B254),
  (Expr: E_DRAGADDR; Val: $00518380),
  (Expr: E_EXMSGADDR; Val: $00513BC0),
  (Expr: E_ITEMCHECKADDR; Val: $0053D2D0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3850),
  (Expr: E_ITEMPROPADDR; Val: $004F3770),
  (Expr: E_ITEMPROPID; Val: $007D266C),
  (Expr: E_ITEMREQADDR; Val: $0053D900),
  (Expr: E_MACROADDR; Val: $004F7F80),
  (Expr: E_OLDDIR; Val: $00552590),
  (Expr: E_PATHFINDADDR; Val: $0049BB4D),
  (Expr: E_REDIR; Val: $00508F0C),
  (Expr: E_SENDPACKET; Val: $004169A0),
  (Expr: E_SLEEPADDR; Val: $0057B224),
  (Expr: E_SYSMSGADDR; Val: $00527510),
  (Expr: LISTEND; Val: 0)
);

// Milestone 94 -- first introduced at client '5.0.5a' (normalized '005.000.005.a')
SysVarMS94 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518260),
  (Expr: E_EXMSGADDR; Val: $00513AA0),
  (Expr: E_ITEMCHECKADDR; Val: $0053D240),
  (Expr: E_ITEMNAMEADDR; Val: $004F3480),
  (Expr: E_ITEMPROPADDR; Val: $004F33A0),
  (Expr: E_ITEMPROPID; Val: $007D264C),
  (Expr: E_ITEMREQADDR; Val: $0053D870),
  (Expr: E_MACROADDR; Val: $004F7BB0),
  (Expr: E_OLDDIR; Val: $00552480),
  (Expr: E_REDIR; Val: $00508C9C),
  (Expr: E_SYSMSGADDR; Val: $005273C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 95 -- first introduced at client '5.0.4e' (normalized '005.000.004.e')
SysVarMS95 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518100),
  (Expr: E_EXMSGADDR; Val: $00513940),
  (Expr: E_ITEMCHECKADDR; Val: $0053D0E0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3340),
  (Expr: E_ITEMPROPADDR; Val: $004F3260),
  (Expr: E_ITEMPROPID; Val: $007D262C),
  (Expr: E_ITEMREQADDR; Val: $0053D710),
  (Expr: E_MACROADDR; Val: $004F7A70),
  (Expr: E_OLDDIR; Val: $00552320),
  (Expr: E_REDIR; Val: $00508B5C),
  (Expr: E_SYSMSGADDR; Val: $00527260),
  (Expr: LISTEND; Val: 0)
);

// Milestone 96 -- first introduced at client '5.0.4d' (normalized '005.000.004.d')
SysVarMS96 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518060),
  (Expr: E_EXMSGADDR; Val: $005138A0),
  (Expr: E_ITEMCHECKADDR; Val: $0053D040),
  (Expr: E_ITEMNAMEADDR; Val: $004F32A0),
  (Expr: E_ITEMPROPADDR; Val: $004F31C0),
  (Expr: E_ITEMREQADDR; Val: $0053D670),
  (Expr: E_MACROADDR; Val: $004F79D0),
  (Expr: E_OLDDIR; Val: $00552280),
  (Expr: E_PATHFINDADDR; Val: $0049BC3D),
  (Expr: E_REDIR; Val: $00508ABC),
  (Expr: E_SYSMSGADDR; Val: $005271C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 97 -- first introduced at client '5.0.4b' (normalized '005.000.004.b')
SysVarMS97 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518160),
  (Expr: E_EXMSGADDR; Val: $005139A0),
  (Expr: E_ITEMCHECKADDR; Val: $0053CFC0),
  (Expr: E_ITEMNAMEADDR; Val: $004F34F0),
  (Expr: E_ITEMPROPADDR; Val: $004F3410),
  (Expr: E_ITEMREQADDR; Val: $0053D5F0),
  (Expr: E_MACROADDR; Val: $004F7C20),
  (Expr: E_PATHFINDADDR; Val: $0049BBBD),
  (Expr: E_REDIR; Val: $00508D0C),
  (Expr: E_SENDPACKET; Val: $004169E0),
  (Expr: E_SYSMSGADDR; Val: $005272C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 98 -- first introduced at client '5.0.4a' (normalized '005.000.004.a')
SysVarMS98 : array[0..36] of TSysVarList = (
  (Expr: B_LANG; Val: $00000148),
  (Expr: C_CHARDIR; Val: $00000000),
  (Expr: C_CHARPTR; Val: $00000000),
  (Expr: C_CLILEFT; Val: $00000000),
  (Expr: C_CLILOGGED; Val: $00000000),
  (Expr: C_CLIXRES; Val: $00000000),
  (Expr: C_CONTPOS; Val: $00000000),
  (Expr: C_CURSORKIND; Val: $00000000),
  (Expr: C_ENEMYHITS; Val: $00000000),
  (Expr: C_ENEMYID; Val: $00000000),
  (Expr: C_JOURNALPTR; Val: $00000000),
  (Expr: C_LHANDID; Val: $00000000),
  (Expr: C_LLIFTEDID; Val: $00000000),
  (Expr: C_LSHARD; Val: $00000000),
  (Expr: C_NEXTCPOS; Val: $00000000),
  (Expr: C_POPUPID; Val: $00000000),
  (Expr: C_SHARDPOS; Val: $00000000),
  (Expr: C_SKILLCAPS; Val: $00000000),
  (Expr: C_SKILLLOCK; Val: $00000000),
  (Expr: C_SKILLSPOS; Val: $00000000),
  (Expr: C_SYSMSG; Val: $00000000),
  (Expr: C_TARGETCNT; Val: $00000000),
  (Expr: C_TARGETCURS; Val: $00000000),
  (Expr: E_DRAGADDR; Val: $00518080),
  (Expr: E_EXMSGADDR; Val: $005138C0),
  (Expr: E_ITEMCHECKADDR; Val: $0053CEE0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3410),
  (Expr: E_ITEMPROPADDR; Val: $004F3330),
  (Expr: E_ITEMPROPID; Val: $007D261C),
  (Expr: E_ITEMREQADDR; Val: $0053D510),
  (Expr: E_MACROADDR; Val: $004F7B30),
  (Expr: E_OLDDIR; Val: $00552200),
  (Expr: E_PATHFINDADDR; Val: $0049BACD),
  (Expr: E_REDIR; Val: $00508C4C),
  (Expr: E_SENDPACKET; Val: $00416990),
  (Expr: E_SYSMSGADDR; Val: $005271E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 99 -- first introduced at client '5.0.3' (normalized '005.000.003')
SysVarMS99 : array[0..37] of TSysVarList = (
  (Expr: B_FINDREP; Val: $00000184),
  (Expr: C_CHARDIR; Val: $007D73A0),
  (Expr: C_CHARPTR; Val: $0081B764),
  (Expr: C_CLILEFT; Val: $0081B1C4),
  (Expr: C_CLILOGGED; Val: $005BC264),
  (Expr: C_CLIXRES; Val: $005BDA98),
  (Expr: C_CONTPOS; Val: $006B7300),
  (Expr: C_CURSORKIND; Val: $0081B14C),
  (Expr: C_ENEMYHITS; Val: $0077F188),
  (Expr: C_ENEMYID; Val: $006B0910),
  (Expr: C_JOURNALPTR; Val: $00857BEC),
  (Expr: C_LHANDID; Val: $007D673C),
  (Expr: C_LLIFTEDID; Val: $0081B7B0),
  (Expr: C_LSHARD; Val: $0081F8D0),
  (Expr: C_NEXTCPOS; Val: $006B6874),
  (Expr: C_POPUPID; Val: $0081FA40),
  (Expr: C_SHARDPOS; Val: $006B670C),
  (Expr: C_SKILLCAPS; Val: $00899E7C),
  (Expr: C_SKILLLOCK; Val: $00899EEC),
  (Expr: C_SKILLSPOS; Val: $00899F24),
  (Expr: C_SYSMSG; Val: $006B72E0),
  (Expr: C_TARGETCNT; Val: $00818564),
  (Expr: C_TARGETCURS; Val: $0081B194),
  (Expr: E_DRAGADDR; Val: $00517E80),
  (Expr: E_EXMSGADDR; Val: $00513710),
  (Expr: E_ITEMCHECKADDR; Val: $0053CD10),
  (Expr: E_ITEMNAMEADDR; Val: $004F33C0),
  (Expr: E_ITEMPROPADDR; Val: $004F32E0),
  (Expr: E_ITEMPROPID; Val: $007D25BC),
  (Expr: E_ITEMREQADDR; Val: $0053D340),
  (Expr: E_MACROADDR; Val: $004F7AF0),
  (Expr: E_OLDDIR; Val: $00551DB0),
  (Expr: E_PATHFINDADDR; Val: $0049BEAD),
  (Expr: E_REDIR; Val: $00508A3C),
  (Expr: E_SENDPACKET; Val: $004169E0),
  (Expr: E_SLEEPADDR; Val: $0057B220),
  (Expr: E_SYSMSGADDR; Val: $00527090),
  (Expr: LISTEND; Val: 0)
);

// Milestone 100 -- first introduced at client '5.0.2f' (normalized '005.000.002.f')
SysVarMS100 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007D63A0),
  (Expr: C_CHARPTR; Val: $0081A764),
  (Expr: C_CLILEFT; Val: $0081A1C4),
  (Expr: C_CLILOGGED; Val: $005BB264),
  (Expr: C_CLIXRES; Val: $005BCA98),
  (Expr: C_CONTPOS; Val: $006B6300),
  (Expr: C_CURSORKIND; Val: $0081A14C),
  (Expr: C_ENEMYHITS; Val: $0077E188),
  (Expr: C_ENEMYID; Val: $006AF910),
  (Expr: C_JOURNALPTR; Val: $00856BEC),
  (Expr: C_LHANDID; Val: $007D573C),
  (Expr: C_LLIFTEDID; Val: $0081A7B0),
  (Expr: C_LSHARD; Val: $0081E8D0),
  (Expr: C_NEXTCPOS; Val: $006B5874),
  (Expr: C_POPUPID; Val: $0081EA40),
  (Expr: C_SHARDPOS; Val: $006B570C),
  (Expr: C_SKILLCAPS; Val: $00898E7C),
  (Expr: C_SKILLLOCK; Val: $00898EEC),
  (Expr: C_SKILLSPOS; Val: $00898F24),
  (Expr: C_SYSMSG; Val: $006B62E0),
  (Expr: C_TARGETCNT; Val: $00817564),
  (Expr: C_TARGETCURS; Val: $0081A194),
  (Expr: E_DRAGADDR; Val: $005177E0),
  (Expr: E_EXMSGADDR; Val: $005130F0),
  (Expr: E_ITEMCHECKADDR; Val: $0053C7D0),
  (Expr: E_ITEMNAMEADDR; Val: $004F2C60),
  (Expr: E_ITEMPROPADDR; Val: $004F2B80),
  (Expr: E_ITEMPROPID; Val: $007D15BC),
  (Expr: E_ITEMREQADDR; Val: $0053CE00),
  (Expr: E_MACROADDR; Val: $004F73E0),
  (Expr: E_OLDDIR; Val: $00551940),
  (Expr: E_PATHFINDADDR; Val: $0049B89D),
  (Expr: E_REDIR; Val: $0050830C),
  (Expr: E_SLEEPADDR; Val: $0057A220),
  (Expr: E_SYSMSGADDR; Val: $005269F0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 101 -- first introduced at client '5.0.2c' (normalized '005.000.002.c')
SysVarMS101 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00518780),
  (Expr: E_EXMSGADDR; Val: $00514090),
  (Expr: E_ITEMCHECKADDR; Val: $0053D770),
  (Expr: E_ITEMNAMEADDR; Val: $004F3C00),
  (Expr: E_ITEMPROPADDR; Val: $004F3B20),
  (Expr: E_ITEMREQADDR; Val: $0053DDA0),
  (Expr: E_MACROADDR; Val: $004F8380),
  (Expr: E_OLDDIR; Val: $005528E0),
  (Expr: E_PATHFINDADDR; Val: $0049C96D),
  (Expr: E_REDIR; Val: $005092AC),
  (Expr: E_SYSMSGADDR; Val: $00527900),
  (Expr: LISTEND; Val: 0)
);

// Milestone 102 -- first introduced at client '5.0.2b' (normalized '005.000.002.b')
SysVarMS102 : array[0..12] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005185E0),
  (Expr: E_EXMSGADDR; Val: $00513EF0),
  (Expr: E_ITEMCHECKADDR; Val: $0053D7B0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3A50),
  (Expr: E_ITEMPROPADDR; Val: $004F3970),
  (Expr: E_ITEMREQADDR; Val: $0053DDE0),
  (Expr: E_MACROADDR; Val: $004F81D0),
  (Expr: E_OLDDIR; Val: $00552920),
  (Expr: E_PATHFINDADDR; Val: $0049C8BD),
  (Expr: E_REDIR; Val: $0050910C),
  (Expr: E_SENDPACKET; Val: $004168E0),
  (Expr: E_SYSMSGADDR; Val: $005277D0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 103 -- first introduced at client '5.0.2a' (normalized '005.000.002.a')
SysVarMS103 : array[0..38] of TSysVarList = (
  (Expr: B_LANG; Val: $00000144),
  (Expr: C_CHARDIR; Val: $007D93A0),
  (Expr: C_CHARPTR; Val: $0081D764),
  (Expr: C_CLILEFT; Val: $0081D1C4),
  (Expr: C_CLILOGGED; Val: $005BE264),
  (Expr: C_CLIXRES; Val: $005BFA98),
  (Expr: C_CONTPOS; Val: $006B9300),
  (Expr: C_CURSORKIND; Val: $0081D14C),
  (Expr: C_ENEMYHITS; Val: $00781188),
  (Expr: C_ENEMYID; Val: $006B2910),
  (Expr: C_JOURNALPTR; Val: $00859BEC),
  (Expr: C_LHANDID; Val: $007D873C),
  (Expr: C_LLIFTEDID; Val: $0081D7B0),
  (Expr: C_LSHARD; Val: $008218D0),
  (Expr: C_NEXTCPOS; Val: $006B8874),
  (Expr: C_POPUPID; Val: $00821A40),
  (Expr: C_SHARDPOS; Val: $006B870C),
  (Expr: C_SKILLCAPS; Val: $0089BE7C),
  (Expr: C_SKILLLOCK; Val: $0089BEEC),
  (Expr: C_SKILLSPOS; Val: $0089BF24),
  (Expr: C_SYSMSG; Val: $006B92E0),
  (Expr: C_TARGETCNT; Val: $0081A564),
  (Expr: C_TARGETCURS; Val: $0081D194),
  (Expr: E_DRAGADDR; Val: $00518880),
  (Expr: E_EXMSGADDR; Val: $00514180),
  (Expr: E_ITEMCHECKADDR; Val: $0053D780),
  (Expr: E_ITEMNAMEADDR; Val: $004F3E60),
  (Expr: E_ITEMPROPADDR; Val: $004F3D80),
  (Expr: E_ITEMPROPID; Val: $007D45BC),
  (Expr: E_ITEMREQADDR; Val: $0053DDB0),
  (Expr: E_MACROADDR; Val: $004F8580),
  (Expr: E_OLDDIR; Val: $00552880),
  (Expr: E_PATHFINDADDR; Val: $0049CE2D),
  (Expr: E_REDIR; Val: $0050931C),
  (Expr: E_SENDPACKET; Val: $00416920),
  (Expr: E_SLEEPADDR; Val: $0057C220),
  (Expr: E_SYSMSGADDR; Val: $00527920),
  (Expr: F_MACROMAP; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 104 -- first introduced at client '5.0.2' (normalized '005.000.002')
SysVarMS104 : array[0..39] of TSysVarList = (
  (Expr: B_LANG; Val: $00000140),
  (Expr: B_MEMBASE; Val: $00868000),
  (Expr: C_CHARDIR; Val: $007D84E0),
  (Expr: C_CHARPTR; Val: $0081C8A4),
  (Expr: C_CLILEFT; Val: $0081C304),
  (Expr: C_CLILOGGED; Val: $005BD2AC),
  (Expr: C_CLIXRES; Val: $005BEAC4),
  (Expr: C_CONTPOS; Val: $006B8440),
  (Expr: C_CURSORKIND; Val: $0081C28C),
  (Expr: C_ENEMYHITS; Val: $007802C8),
  (Expr: C_ENEMYID; Val: $006B1A50),
  (Expr: C_JOURNALPTR; Val: $00858D2C),
  (Expr: C_LHANDID; Val: $007D7878),
  (Expr: C_LLIFTEDID; Val: $0081C8F0),
  (Expr: C_LSHARD; Val: $00820A10),
  (Expr: C_NEXTCPOS; Val: $006B79B4),
  (Expr: C_POPUPID; Val: $00820B80),
  (Expr: C_SHARDPOS; Val: $006B784C),
  (Expr: C_SKILLCAPS; Val: $0089AFBC),
  (Expr: C_SKILLLOCK; Val: $0089B02C),
  (Expr: C_SKILLSPOS; Val: $0089B064),
  (Expr: C_SYSMSG; Val: $006B8420),
  (Expr: C_TARGETCNT; Val: $008196A4),
  (Expr: C_TARGETCURS; Val: $0081C2D4),
  (Expr: E_DRAGADDR; Val: $00517EC0),
  (Expr: E_EXMSGADDR; Val: $005137D0),
  (Expr: E_ITEMCHECKADDR; Val: $0053CEE0),
  (Expr: E_ITEMNAMEADDR; Val: $004F3BA0),
  (Expr: E_ITEMPROPADDR; Val: $004F3AC0),
  (Expr: E_ITEMPROPID; Val: $007D36FC),
  (Expr: E_ITEMREQADDR; Val: $0053D510),
  (Expr: E_MACROADDR; Val: $004F82C0),
  (Expr: E_OLDDIR; Val: $00551FE0),
  (Expr: E_PATHFINDADDR; Val: $0049C84D),
  (Expr: E_REDIR; Val: $00508B6C),
  (Expr: E_SENDPACKET; Val: $004169A0),
  (Expr: E_SLEEPADDR; Val: $0057B220),
  (Expr: E_SYSMSGADDR; Val: $00526F20),
  (Expr: F_MACROMAP; Val: $00000002),
  (Expr: LISTEND; Val: 0)
);

// Milestone 105 -- first introduced at client '5.0.1j' (normalized '005.000.001.j')
SysVarMS105 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C2A00),
  (Expr: C_CHARPTR; Val: $00806DAC),
  (Expr: C_CLILEFT; Val: $0080680C),
  (Expr: C_CLIXRES; Val: $005AF4A8),
  (Expr: C_CONTPOS; Val: $006A29B0),
  (Expr: C_CURSORKIND; Val: $00806794),
  (Expr: C_ENEMYHITS; Val: $0076A838),
  (Expr: C_ENEMYID; Val: $006A1D90),
  (Expr: C_JOURNALPTR; Val: $00843234),
  (Expr: C_LHANDID; Val: $007C1DA0),
  (Expr: C_LLIFTEDID; Val: $00806DF8),
  (Expr: C_LSHARD; Val: $0080AF18),
  (Expr: C_NEXTCPOS; Val: $006A1F24),
  (Expr: C_POPUPID; Val: $0080B088),
  (Expr: C_SHARDPOS; Val: $006A1DCC),
  (Expr: C_SKILLCAPS; Val: $008854C4),
  (Expr: C_SKILLLOCK; Val: $00885534),
  (Expr: C_SKILLSPOS; Val: $0088556C),
  (Expr: C_SYSMSG; Val: $006A2990),
  (Expr: C_TARGETCNT; Val: $00803BAC),
  (Expr: C_TARGETCURS; Val: $008067DC),
  (Expr: E_DRAGADDR; Val: $00510500),
  (Expr: E_EXMSGADDR; Val: $0050BE20),
  (Expr: E_ITEMCHECKADDR; Val: $00530800),
  (Expr: E_ITEMNAMEADDR; Val: $004ECB20),
  (Expr: E_ITEMPROPADDR; Val: $004ECA40),
  (Expr: E_ITEMPROPID; Val: $007BDC1C),
  (Expr: E_ITEMREQADDR; Val: $00530E30),
  (Expr: E_MACROADDR; Val: $004F1250),
  (Expr: E_OLDDIR; Val: $00545970),
  (Expr: E_PATHFINDADDR; Val: $004991ED),
  (Expr: E_REDIR; Val: $0050126C),
  (Expr: E_SENDPACKET; Val: $00416780),
  (Expr: E_SYSMSGADDR; Val: $0051F420),
  (Expr: LISTEND; Val: 0)
);

// Milestone 106 -- first introduced at client '5.0.1i' (normalized '005.000.001.i')
SysVarMS106 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C29D0),
  (Expr: C_CHARPTR; Val: $00806D7C),
  (Expr: C_CLILEFT; Val: $008067DC),
  (Expr: C_CLIXRES; Val: $005AF490),
  (Expr: C_CONTPOS; Val: $006A2980),
  (Expr: C_CURSORKIND; Val: $00806764),
  (Expr: C_ENEMYHITS; Val: $0076A808),
  (Expr: C_ENEMYID; Val: $006A1D60),
  (Expr: C_JOURNALPTR; Val: $00843204),
  (Expr: C_LHANDID; Val: $007C1D70),
  (Expr: C_LLIFTEDID; Val: $00806DC8),
  (Expr: C_LSHARD; Val: $0080AEE8),
  (Expr: C_NEXTCPOS; Val: $006A1EF4),
  (Expr: C_POPUPID; Val: $0080B058),
  (Expr: C_SHARDPOS; Val: $006A1D9C),
  (Expr: C_SKILLCAPS; Val: $00885494),
  (Expr: C_SKILLLOCK; Val: $00885504),
  (Expr: C_SKILLSPOS; Val: $0088553C),
  (Expr: C_SYSMSG; Val: $006A2960),
  (Expr: C_TARGETCNT; Val: $00803B7C),
  (Expr: C_TARGETCURS; Val: $008067AC),
  (Expr: E_DRAGADDR; Val: $00510800),
  (Expr: E_EXMSGADDR; Val: $0050C100),
  (Expr: E_ITEMCHECKADDR; Val: $005308F0),
  (Expr: E_ITEMNAMEADDR; Val: $004ECB90),
  (Expr: E_ITEMPROPADDR; Val: $004ECAB0),
  (Expr: E_ITEMPROPID; Val: $007BDBEC),
  (Expr: E_ITEMREQADDR; Val: $00530F20),
  (Expr: E_MACROADDR; Val: $004F12D0),
  (Expr: E_OLDDIR; Val: $00545A10),
  (Expr: E_PATHFINDADDR; Val: $004992DD),
  (Expr: E_REDIR; Val: $0050144B),
  (Expr: E_SENDPACKET; Val: $00416890),
  (Expr: E_SYSMSGADDR; Val: $0051F710),
  (Expr: LISTEND; Val: 0)
);

// Milestone 107 -- first introduced at client '5.0.1f' (normalized '005.000.001.f')
SysVarMS107 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C2860),
  (Expr: C_CHARPTR; Val: $00806C04),
  (Expr: C_CLILEFT; Val: $00806664),
  (Expr: C_CLILOGGED; Val: $005ADD1C),
  (Expr: C_CLIXRES; Val: $005AF484),
  (Expr: C_CONTPOS; Val: $006A2810),
  (Expr: C_CURSORKIND; Val: $008065EC),
  (Expr: C_ENEMYHITS; Val: $0076A698),
  (Expr: C_ENEMYID; Val: $006A1BF0),
  (Expr: C_JOURNALPTR; Val: $0084308C),
  (Expr: C_LHANDID; Val: $007C1BFC),
  (Expr: C_LLIFTEDID; Val: $00806C50),
  (Expr: C_LSHARD; Val: $0080AD70),
  (Expr: C_NEXTCPOS; Val: $006A1D84),
  (Expr: C_POPUPID; Val: $0080AEE0),
  (Expr: C_SHARDPOS; Val: $006A1C2C),
  (Expr: C_SKILLCAPS; Val: $008852CC),
  (Expr: C_SKILLLOCK; Val: $0088533C),
  (Expr: C_SKILLSPOS; Val: $00885374),
  (Expr: C_SYSMSG; Val: $006A27F0),
  (Expr: C_TARGETCNT; Val: $00803A04),
  (Expr: C_TARGETCURS; Val: $00806634),
  (Expr: E_DRAGADDR; Val: $0050FDD0),
  (Expr: E_EXMSGADDR; Val: $0050B6F0),
  (Expr: E_ITEMCHECKADDR; Val: $005301C0),
  (Expr: E_ITEMNAMEADDR; Val: $004EC7A0),
  (Expr: E_ITEMPROPADDR; Val: $004EC6C0),
  (Expr: E_ITEMPROPID; Val: $007BDA7C),
  (Expr: E_ITEMREQADDR; Val: $005307F0),
  (Expr: E_MACROADDR; Val: $004F0CA0),
  (Expr: E_OLDDIR; Val: $005452D0),
  (Expr: E_PATHFINDADDR; Val: $0049961B),
  (Expr: E_REDIR; Val: $00500B5C),
  (Expr: E_SENDPACKET; Val: $004168A0),
  (Expr: E_SYSMSGADDR; Val: $0051EB70),
  (Expr: LISTEND; Val: 0)
);

// Milestone 108 -- first introduced at client '5.0.1d' (normalized '005.000.001.d')
SysVarMS108 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C2830),
  (Expr: C_CHARPTR; Val: $00806BD4),
  (Expr: C_CLILEFT; Val: $00806634),
  (Expr: C_CLILOGGED; Val: $005ADCE4),
  (Expr: C_CLIXRES; Val: $005AF44C),
  (Expr: C_CONTPOS; Val: $006A27E0),
  (Expr: C_CURSORKIND; Val: $008065BC),
  (Expr: C_ENEMYHITS; Val: $0076A668),
  (Expr: C_ENEMYID; Val: $006A1BC0),
  (Expr: C_JOURNALPTR; Val: $0084305C),
  (Expr: C_LHANDID; Val: $007C1BCC),
  (Expr: C_LLIFTEDID; Val: $00806C20),
  (Expr: C_LSHARD; Val: $0080AD40),
  (Expr: C_NEXTCPOS; Val: $006A1D54),
  (Expr: C_POPUPID; Val: $0080AEB0),
  (Expr: C_SHARDPOS; Val: $006A1BFC),
  (Expr: C_SKILLCAPS; Val: $0088529C),
  (Expr: C_SKILLLOCK; Val: $0088530C),
  (Expr: C_SKILLSPOS; Val: $00885344),
  (Expr: C_SYSMSG; Val: $006A27C0),
  (Expr: C_TARGETCNT; Val: $008039D4),
  (Expr: C_TARGETCURS; Val: $00806604),
  (Expr: E_DRAGADDR; Val: $0050FD40),
  (Expr: E_EXMSGADDR; Val: $0050B660),
  (Expr: E_ITEMCHECKADDR; Val: $00530200),
  (Expr: E_ITEMNAMEADDR; Val: $004EC7F0),
  (Expr: E_ITEMPROPADDR; Val: $004EC710),
  (Expr: E_ITEMPROPID; Val: $007BDA4C),
  (Expr: E_ITEMREQADDR; Val: $00530830),
  (Expr: E_MACROADDR; Val: $004F0CF0),
  (Expr: E_OLDDIR; Val: $00545270),
  (Expr: E_PATHFINDADDR; Val: $0049925B),
  (Expr: E_REDIR; Val: $00500A4C),
  (Expr: E_SENDPACKET; Val: $00416700),
  (Expr: E_SLEEPADDR; Val: $0056E21C),
  (Expr: E_SYSMSGADDR; Val: $0051EBE0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 109 -- first introduced at client '5.0.1d1' (normalized '005.000.001.d')
SysVarMS109 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C0820),
  (Expr: C_CHARPTR; Val: $00804BC4),
  (Expr: C_CLILEFT; Val: $00804624),
  (Expr: C_CLILOGGED; Val: $005ABCD4),
  (Expr: C_CLIXRES; Val: $005AD43C),
  (Expr: C_CONTPOS; Val: $006A07D0),
  (Expr: C_CURSORKIND; Val: $008045AC),
  (Expr: C_ENEMYHITS; Val: $00768658),
  (Expr: C_ENEMYID; Val: $0069FBB0),
  (Expr: C_JOURNALPTR; Val: $0084104C),
  (Expr: C_LHANDID; Val: $007BFBBC),
  (Expr: C_LLIFTEDID; Val: $00804C10),
  (Expr: C_LSHARD; Val: $00808D30),
  (Expr: C_NEXTCPOS; Val: $0069FD44),
  (Expr: C_POPUPID; Val: $00808EA0),
  (Expr: C_SHARDPOS; Val: $0069FBEC),
  (Expr: C_SKILLCAPS; Val: $0088328C),
  (Expr: C_SKILLLOCK; Val: $008832FC),
  (Expr: C_SKILLSPOS; Val: $00883334),
  (Expr: C_SYSMSG; Val: $006A07B0),
  (Expr: C_TARGETCNT; Val: $008019C4),
  (Expr: C_TARGETCURS; Val: $008045F4),
  (Expr: E_DRAGADDR; Val: $0050E280),
  (Expr: E_EXMSGADDR; Val: $00509B60),
  (Expr: E_ITEMCHECKADDR; Val: $0052E860),
  (Expr: E_ITEMNAMEADDR; Val: $004EA9E0),
  (Expr: E_ITEMPROPADDR; Val: $004EA900),
  (Expr: E_ITEMPROPID; Val: $007BBA3C),
  (Expr: E_ITEMREQADDR; Val: $0052EE90),
  (Expr: E_MACROADDR; Val: $004EEEF0),
  (Expr: E_OLDDIR; Val: $00543880),
  (Expr: E_PATHFINDADDR; Val: $0049748B),
  (Expr: E_REDIR; Val: $004FEDDC),
  (Expr: E_SENDPACKET; Val: $00416850),
  (Expr: E_SYSMSGADDR; Val: $0051D080),
  (Expr: LISTEND; Val: 0)
);

// Milestone 110 -- first introduced at client '5.0.1a' (normalized '005.000.001.a')
SysVarMS110 : array[0..11] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $0050DC40),
  (Expr: E_EXMSGADDR; Val: $00509560),
  (Expr: E_ITEMCHECKADDR; Val: $0052E160),
  (Expr: E_ITEMNAMEADDR; Val: $004EA4E0),
  (Expr: E_ITEMPROPADDR; Val: $004EA400),
  (Expr: E_ITEMREQADDR; Val: $0052E790),
  (Expr: E_MACROADDR; Val: $004EE9E0),
  (Expr: E_OLDDIR; Val: $005433F0),
  (Expr: E_PATHFINDADDR; Val: $004972DB),
  (Expr: E_REDIR; Val: $004FE8FC),
  (Expr: E_SYSMSGADDR; Val: $0051C9D0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 111 -- first introduced at client '5.0.1a1' (normalized '005.000.001.a')
SysVarMS111 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007C07E0),
  (Expr: C_CHARPTR; Val: $00804B84),
  (Expr: C_CLILEFT; Val: $008045E4),
  (Expr: C_CLILOGGED; Val: $005ABC94),
  (Expr: C_CLIXRES; Val: $005AD3FC),
  (Expr: C_CONTPOS; Val: $006A0790),
  (Expr: C_CURSORKIND; Val: $0080456C),
  (Expr: C_ENEMYHITS; Val: $00768618),
  (Expr: C_ENEMYID; Val: $0069FB70),
  (Expr: C_JOURNALPTR; Val: $0084100C),
  (Expr: C_LHANDID; Val: $007BFB7C),
  (Expr: C_LLIFTEDID; Val: $00804BD0),
  (Expr: C_LSHARD; Val: $00808CF0),
  (Expr: C_NEXTCPOS; Val: $0069FD04),
  (Expr: C_POPUPID; Val: $00808E60),
  (Expr: C_SHARDPOS; Val: $0069FBAC),
  (Expr: C_SKILLCAPS; Val: $0088324C),
  (Expr: C_SKILLLOCK; Val: $008832BC),
  (Expr: C_SKILLSPOS; Val: $008832F4),
  (Expr: C_SYSMSG; Val: $006A0770),
  (Expr: C_TARGETCNT; Val: $00801984),
  (Expr: C_TARGETCURS; Val: $008045B4),
  (Expr: E_DRAGADDR; Val: $0050DC70),
  (Expr: E_EXMSGADDR; Val: $00509590),
  (Expr: E_ITEMCHECKADDR; Val: $0052E190),
  (Expr: E_ITEMNAMEADDR; Val: $004EA510),
  (Expr: E_ITEMPROPADDR; Val: $004EA430),
  (Expr: E_ITEMPROPID; Val: $007BB9FC),
  (Expr: E_ITEMREQADDR; Val: $0052E7C0),
  (Expr: E_MACROADDR; Val: $004EEA10),
  (Expr: E_OLDDIR; Val: $00543420),
  (Expr: E_PATHFINDADDR; Val: $0049730B),
  (Expr: E_REDIR; Val: $004FE92C),
  (Expr: E_SENDPACKET; Val: $00416640),
  (Expr: E_SLEEPADDR; Val: $0056C21C),
  (Expr: E_SYSMSGADDR; Val: $0051CA00),
  (Expr: LISTEND; Val: 0)
);

// Milestone 112 -- first introduced at client '5.0.0b' (normalized '005.000.000.b')
SysVarMS112 : array[0..12] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $0050DFD0),
  (Expr: E_EXMSGADDR; Val: $005098F0),
  (Expr: E_ITEMCHECKADDR; Val: $0052D860),
  (Expr: E_ITEMNAMEADDR; Val: $004EA9C0),
  (Expr: E_ITEMPROPADDR; Val: $004EA8E0),
  (Expr: E_ITEMREQADDR; Val: $0052DE90),
  (Expr: E_MACROADDR; Val: $004EEF20),
  (Expr: E_OLDDIR; Val: $00542A10),
  (Expr: E_PATHFINDADDR; Val: $0049768B),
  (Expr: E_REDIR; Val: $004FEC5C),
  (Expr: E_SENDPACKET; Val: $00416750),
  (Expr: E_SYSMSGADDR; Val: $0051CDA0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 113 -- first introduced at client '5.0.0a' (normalized '005.000.000.a')
SysVarMS113 : array[0..40] of TSysVarList = (
  (Expr: B_FINDREP; Val: $00000178),
  (Expr: B_MEMBASE; Val: $00850000),
  (Expr: B_SKILLDIST; Val: $00000070),
  (Expr: B_STATML; Val: $00000002),
  (Expr: C_CHARDIR; Val: $007BE7B0),
  (Expr: C_CHARPTR; Val: $00802B54),
  (Expr: C_CLILEFT; Val: $008025B4),
  (Expr: C_CLILOGGED; Val: $005A9C94),
  (Expr: C_CLIXRES; Val: $005AB3FC),
  (Expr: C_CONTPOS; Val: $0069E760),
  (Expr: C_CURSORKIND; Val: $0080253C),
  (Expr: C_ENEMYHITS; Val: $007665E8),
  (Expr: C_ENEMYID; Val: $0069DB40),
  (Expr: C_JOURNALPTR; Val: $0083EFDC),
  (Expr: C_LHANDID; Val: $007BDB4C),
  (Expr: C_LLIFTEDID; Val: $00802BA0),
  (Expr: C_LSHARD; Val: $00806CC0),
  (Expr: C_NEXTCPOS; Val: $0069DCD4),
  (Expr: C_POPUPID; Val: $00806E30),
  (Expr: C_SHARDPOS; Val: $0069DB7C),
  (Expr: C_SKILLCAPS; Val: $0088120C),
  (Expr: C_SKILLLOCK; Val: $0088127C),
  (Expr: C_SKILLSPOS; Val: $008812B4),
  (Expr: C_SYSMSG; Val: $0069E740),
  (Expr: C_TARGETCNT; Val: $007FF954),
  (Expr: C_TARGETCURS; Val: $00802584),
  (Expr: E_DRAGADDR; Val: $0050E330),
  (Expr: E_EXMSGADDR; Val: $00509C50),
  (Expr: E_ITEMCHECKADDR; Val: $0052DCE0),
  (Expr: E_ITEMNAMEADDR; Val: $004EAD70),
  (Expr: E_ITEMPROPADDR; Val: $004EAC90),
  (Expr: E_ITEMPROPID; Val: $007B99CC),
  (Expr: E_ITEMREQADDR; Val: $0052E310),
  (Expr: E_MACROADDR; Val: $004EF280),
  (Expr: E_OLDDIR; Val: $00542D30),
  (Expr: E_PATHFINDADDR; Val: $004977DB),
  (Expr: E_REDIR; Val: $004FEFBC),
  (Expr: E_SENDPACKET; Val: $00416930),
  (Expr: E_SLEEPADDR; Val: $0056B21C),
  (Expr: E_SYSMSGADDR; Val: $0051D090),
  (Expr: LISTEND; Val: 0)
);

// Milestone 114 -- first introduced at client '4.0.11e' (normalized '004.000.011.e')
SysVarMS114 : array[0..23] of TSysVarList = (
  (Expr: C_CHARPTR; Val: $007E8A7C),
  (Expr: C_CLILEFT; Val: $007E84DC),
  (Expr: C_CLIXRES; Val: $005A2328),
  (Expr: C_CURSORKIND; Val: $007E8464),
  (Expr: C_JOURNALPTR; Val: $00824F04),
  (Expr: C_LLIFTEDID; Val: $007E8AC8),
  (Expr: C_LSHARD; Val: $007ECBE8),
  (Expr: C_POPUPID; Val: $007ECD58),
  (Expr: C_SKILLCAPS; Val: $00867134),
  (Expr: C_SKILLLOCK; Val: $008671A0),
  (Expr: C_SKILLSPOS; Val: $008671D8),
  (Expr: C_TARGETCURS; Val: $007E84AC),
  (Expr: E_DRAGADDR; Val: $00505BD0),
  (Expr: E_EXMSGADDR; Val: $00501600),
  (Expr: E_ITEMCHECKADDR; Val: $00524B40),
  (Expr: E_ITEMNAMEADDR; Val: $004E28B0),
  (Expr: E_ITEMPROPADDR; Val: $004E27D0),
  (Expr: E_ITEMREQADDR; Val: $00525170),
  (Expr: E_MACROADDR; Val: $004E6CA0),
  (Expr: E_OLDDIR; Val: $00539D20),
  (Expr: E_PATHFINDADDR; Val: $00495DCB),
  (Expr: E_REDIR; Val: $004F6AEC),
  (Expr: E_SYSMSGADDR; Val: $00514150),
  (Expr: LISTEND; Val: 0)
);

// Milestone 115 -- first introduced at client '4.0.11c' (normalized '004.000.011.c')
SysVarMS115 : array[0..12] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00505B20),
  (Expr: E_EXMSGADDR; Val: $00501550),
  (Expr: E_ITEMCHECKADDR; Val: $00524A90),
  (Expr: E_ITEMNAMEADDR; Val: $004E2800),
  (Expr: E_ITEMPROPADDR; Val: $004E2720),
  (Expr: E_ITEMREQADDR; Val: $005250C0),
  (Expr: E_MACROADDR; Val: $004E6BF0),
  (Expr: E_OLDDIR; Val: $00539C70),
  (Expr: E_PATHFINDADDR; Val: $00495DBB),
  (Expr: E_REDIR; Val: $004F6A3C),
  (Expr: E_SENDPACKET; Val: $004160E0),
  (Expr: E_SYSMSGADDR; Val: $005140A0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 116 -- first introduced at client '4.0.11b' (normalized '004.000.011.b')
SysVarMS116 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007B5038),
  (Expr: C_CHARPTR; Val: $007E8A14),
  (Expr: C_CLILEFT; Val: $007E8474),
  (Expr: C_CLIXRES; Val: $005A2320),
  (Expr: C_CONTPOS; Val: $00695388),
  (Expr: C_CURSORKIND; Val: $007E8400),
  (Expr: C_ENEMYHITS; Val: $0075D118),
  (Expr: C_ENEMYID; Val: $00694770),
  (Expr: C_JOURNALPTR; Val: $00824E9C),
  (Expr: C_LHANDID; Val: $007B43D8),
  (Expr: C_LLIFTEDID; Val: $007E8A60),
  (Expr: C_LSHARD; Val: $007ECB80),
  (Expr: C_NEXTCPOS; Val: $00694904),
  (Expr: C_POPUPID; Val: $007ECCF0),
  (Expr: C_SHARDPOS; Val: $006947AC),
  (Expr: C_SKILLCAPS; Val: $008670CC),
  (Expr: C_SKILLLOCK; Val: $00867138),
  (Expr: C_SKILLSPOS; Val: $00867170),
  (Expr: C_SYSMSG; Val: $00695368),
  (Expr: C_TARGETCNT; Val: $007E61DC),
  (Expr: C_TARGETCURS; Val: $007E8444),
  (Expr: E_DRAGADDR; Val: $00505900),
  (Expr: E_EXMSGADDR; Val: $00501330),
  (Expr: E_ITEMCHECKADDR; Val: $00524B40),
  (Expr: E_ITEMNAMEADDR; Val: $004E2770),
  (Expr: E_ITEMPROPADDR; Val: $004E2690),
  (Expr: E_ITEMPROPID; Val: $007B0258),
  (Expr: E_ITEMREQADDR; Val: $00525170),
  (Expr: E_MACROADDR; Val: $004E6B00),
  (Expr: E_OLDDIR; Val: $00539C20),
  (Expr: E_PATHFINDADDR; Val: $0049592B),
  (Expr: E_REDIR; Val: $004F682C),
  (Expr: E_SENDPACKET; Val: $00415F90),
  (Expr: E_SYSMSGADDR; Val: $00513EC0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 117 -- first introduced at client '4.0.11a' (normalized '004.000.011.a')
SysVarMS117 : array[0..37] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007B5050),
  (Expr: C_CHARPTR; Val: $007E8A2C),
  (Expr: C_CLILEFT; Val: $007E848C),
  (Expr: C_CLILOGGED; Val: $005A0AE4),
  (Expr: C_CLIXRES; Val: $005A233C),
  (Expr: C_CONTPOS; Val: $006953A8),
  (Expr: C_CURSORKIND; Val: $007E8418),
  (Expr: C_ENEMYHITS; Val: $0075D138),
  (Expr: C_ENEMYID; Val: $00694790),
  (Expr: C_JOURNALPTR; Val: $00824EB4),
  (Expr: C_LHANDID; Val: $007B43F0),
  (Expr: C_LLIFTEDID; Val: $007E8A78),
  (Expr: C_LSHARD; Val: $007ECB98),
  (Expr: C_NEXTCPOS; Val: $00694924),
  (Expr: C_POPUPID; Val: $007ECD08),
  (Expr: C_SHARDPOS; Val: $006947CC),
  (Expr: C_SKILLCAPS; Val: $008670E4),
  (Expr: C_SKILLLOCK; Val: $00867150),
  (Expr: C_SKILLSPOS; Val: $00867188),
  (Expr: C_SYSMSG; Val: $00695388),
  (Expr: C_TARGETCNT; Val: $007E61F4),
  (Expr: C_TARGETCURS; Val: $007E845C),
  (Expr: E_DRAGADDR; Val: $00505AF0),
  (Expr: E_EXMSGADDR; Val: $00501520),
  (Expr: E_ITEMCHECKADDR; Val: $00524940),
  (Expr: E_ITEMNAMEADDR; Val: $004E28D0),
  (Expr: E_ITEMPROPADDR; Val: $004E27F0),
  (Expr: E_ITEMPROPID; Val: $007B0270),
  (Expr: E_ITEMREQADDR; Val: $00524F70),
  (Expr: E_MACROADDR; Val: $004E6C60),
  (Expr: E_OLDDIR; Val: $00539AF0),
  (Expr: E_PATHFINDADDR; Val: $004959FB),
  (Expr: E_REDIR; Val: $004F696C),
  (Expr: E_SENDPACKET; Val: $00415F10),
  (Expr: E_SLEEPADDR; Val: $00562224),
  (Expr: E_SYSMSGADDR; Val: $005140F0),
  (Expr: F_EXCHARSTATC; Val: $00000014),
  (Expr: LISTEND; Val: 0)
);

// Milestone 118 -- first introduced at client '4.0.10b' (normalized '004.000.010.b')
SysVarMS118 : array[0..10] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $005038D0),
  (Expr: E_EXMSGADDR; Val: $004FF300),
  (Expr: E_ITEMCHECKADDR; Val: $00522B80),
  (Expr: E_ITEMNAMEADDR; Val: $004E0740),
  (Expr: E_ITEMPROPADDR; Val: $004E0660),
  (Expr: E_ITEMREQADDR; Val: $005231B0),
  (Expr: E_MACROADDR; Val: $004E4AD0),
  (Expr: E_OLDDIR; Val: $00537D70),
  (Expr: E_REDIR; Val: $004F47EC),
  (Expr: E_SYSMSGADDR; Val: $00511E40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 119 -- first introduced at client '4.0.10a' (normalized '004.000.010.a')
SysVarMS119 : array[0..38] of TSysVarList = (
  (Expr: B_FINDREP; Val: $00000170),
  (Expr: B_GUMPPTR; Val: $00000044),
  (Expr: C_CHARDIR; Val: $007B19E0),
  (Expr: C_CHARPTR; Val: $007E539C),
  (Expr: C_CLILEFT; Val: $007E4DFC),
  (Expr: C_CLILOGGED; Val: $0059D53C),
  (Expr: C_CLIXRES; Val: $0059ED50),
  (Expr: C_CONTPOS; Val: $00691D38),
  (Expr: C_CURSORKIND; Val: $007E4D88),
  (Expr: C_ENEMYHITS; Val: $00759AC8),
  (Expr: C_ENEMYID; Val: $00691120),
  (Expr: C_JOURNALPTR; Val: $00821694),
  (Expr: C_LHANDID; Val: $007B0D80),
  (Expr: C_LLIFTEDID; Val: $007E53E8),
  (Expr: C_LSHARD; Val: $007E9378),
  (Expr: C_NEXTCPOS; Val: $006912B4),
  (Expr: C_POPUPID; Val: $007E94E8),
  (Expr: C_SHARDPOS; Val: $0069115C),
  (Expr: C_SKILLCAPS; Val: $008638C4),
  (Expr: C_SKILLLOCK; Val: $00863930),
  (Expr: C_SKILLSPOS; Val: $00863968),
  (Expr: C_SYSMSG; Val: $00691D18),
  (Expr: C_TARGETCNT; Val: $007E2B84),
  (Expr: C_TARGETCURS; Val: $007E4DCC),
  (Expr: E_DRAGADDR; Val: $00503890),
  (Expr: E_EXMSGADDR; Val: $004FF2C0),
  (Expr: E_ITEMCHECKADDR; Val: $00522B40),
  (Expr: E_ITEMNAMEADDR; Val: $004E0700),
  (Expr: E_ITEMPROPADDR; Val: $004E0620),
  (Expr: E_ITEMPROPID; Val: $007ACC00),
  (Expr: E_ITEMREQADDR; Val: $00523170),
  (Expr: E_MACROADDR; Val: $004E4A90),
  (Expr: E_OLDDIR; Val: $00537D30),
  (Expr: E_PATHFINDADDR; Val: $00493C9B),
  (Expr: E_REDIR; Val: $004F47AC),
  (Expr: E_SENDPACKET; Val: $00415F40),
  (Expr: E_SLEEPADDR; Val: $00560224),
  (Expr: E_SYSMSGADDR; Val: $00511E00),
  (Expr: LISTEND; Val: 0)
);

// Milestone 120 -- first introduced at client '4.0.9a' (normalized '004.000.009.a')
SysVarMS120 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007AE900),
  (Expr: C_CHARPTR; Val: $007E22BC),
  (Expr: C_CLILEFT; Val: $007E1D1C),
  (Expr: C_CLILOGGED; Val: $0059A53C),
  (Expr: C_CLIXRES; Val: $0059BCE8),
  (Expr: C_CONTPOS; Val: $0068EC58),
  (Expr: C_CURSORKIND; Val: $007E1CA8),
  (Expr: C_ENEMYHITS; Val: $007569E8),
  (Expr: C_ENEMYID; Val: $0068E040),
  (Expr: C_JOURNALPTR; Val: $0081E5B4),
  (Expr: C_LHANDID; Val: $007ADCA0),
  (Expr: C_LLIFTEDID; Val: $007E2308),
  (Expr: C_LSHARD; Val: $007E6294),
  (Expr: C_NEXTCPOS; Val: $0068E1D4),
  (Expr: C_POPUPID; Val: $007E6408),
  (Expr: C_SHARDPOS; Val: $0068E07C),
  (Expr: C_SKILLCAPS; Val: $008607E4),
  (Expr: C_SKILLLOCK; Val: $00860850),
  (Expr: C_SKILLSPOS; Val: $00860888),
  (Expr: C_SYSMSG; Val: $0068EC38),
  (Expr: C_TARGETCNT; Val: $007DFAA4),
  (Expr: C_TARGETCURS; Val: $007E1CEC),
  (Expr: E_DRAGADDR; Val: $005017E0),
  (Expr: E_EXMSGADDR; Val: $004FD1F0),
  (Expr: E_ITEMCHECKADDR; Val: $005203E0),
  (Expr: E_ITEMNAMEADDR; Val: $004DE890),
  (Expr: E_ITEMPROPADDR; Val: $004DE7B0),
  (Expr: E_ITEMPROPID; Val: $007A9B20),
  (Expr: E_ITEMREQADDR; Val: $00520A10),
  (Expr: E_MACROADDR; Val: $004E2C20),
  (Expr: E_OLDDIR; Val: $005355F0),
  (Expr: E_PATHFINDADDR; Val: $004934BB),
  (Expr: E_REDIR; Val: $004F28BC),
  (Expr: E_SENDPACKET; Val: $00416060),
  (Expr: E_SYSMSGADDR; Val: $0050FCA0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 121 -- first introduced at client '4.0.7b' (normalized '004.000.007.b')
SysVarMS121 : array[0..10] of TSysVarList = (
  (Expr: E_DRAGADDR; Val: $00501200),
  (Expr: E_EXMSGADDR; Val: $004FCC20),
  (Expr: E_ITEMCHECKADDR; Val: $0051FE40),
  (Expr: E_ITEMNAMEADDR; Val: $004DE210),
  (Expr: E_ITEMPROPADDR; Val: $004DE130),
  (Expr: E_ITEMREQADDR; Val: $00520470),
  (Expr: E_MACROADDR; Val: $004E25A0),
  (Expr: E_OLDDIR; Val: $00535030),
  (Expr: E_REDIR; Val: $004F236C),
  (Expr: E_SYSMSGADDR; Val: $0050F6B0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 122 -- first introduced at client '4.0.7a' (normalized '004.000.007.a')
SysVarMS122 : array[0..34] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007AE8C0),
  (Expr: C_CHARPTR; Val: $007E227C),
  (Expr: C_CLILEFT; Val: $007E1CDC),
  (Expr: C_CLIXRES; Val: $0059BCB0),
  (Expr: C_CONTPOS; Val: $0068EC18),
  (Expr: C_CURSORKIND; Val: $007E1C68),
  (Expr: C_ENEMYHITS; Val: $007569A8),
  (Expr: C_ENEMYID; Val: $0068E000),
  (Expr: C_JOURNALPTR; Val: $0081E574),
  (Expr: C_LHANDID; Val: $007ADC60),
  (Expr: C_LLIFTEDID; Val: $007E22C8),
  (Expr: C_LSHARD; Val: $007E6254),
  (Expr: C_NEXTCPOS; Val: $0068E194),
  (Expr: C_POPUPID; Val: $007E63C8),
  (Expr: C_SHARDPOS; Val: $0068E03C),
  (Expr: C_SKILLCAPS; Val: $008607A4),
  (Expr: C_SKILLLOCK; Val: $00860810),
  (Expr: C_SKILLSPOS; Val: $00860848),
  (Expr: C_SYSMSG; Val: $0068EBF8),
  (Expr: C_TARGETCNT; Val: $007DFA64),
  (Expr: C_TARGETCURS; Val: $007E1CAC),
  (Expr: E_DRAGADDR; Val: $005011D0),
  (Expr: E_EXMSGADDR; Val: $004FCBF0),
  (Expr: E_ITEMCHECKADDR; Val: $0051FE10),
  (Expr: E_ITEMNAMEADDR; Val: $004DE1E0),
  (Expr: E_ITEMPROPADDR; Val: $004DE100),
  (Expr: E_ITEMPROPID; Val: $007A9AE0),
  (Expr: E_ITEMREQADDR; Val: $00520440),
  (Expr: E_MACROADDR; Val: $004E2570),
  (Expr: E_OLDDIR; Val: $00535000),
  (Expr: E_PATHFINDADDR; Val: $00492BBB),
  (Expr: E_REDIR; Val: $004F233C),
  (Expr: E_SENDPACKET; Val: $00415F70),
  (Expr: E_SYSMSGADDR; Val: $0050F680),
  (Expr: LISTEND; Val: 0)
);

// Milestone 123 -- first introduced at client '4.0.6a' (normalized '004.000.006.a')
SysVarMS123 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $007AE860),
  (Expr: C_CHARPTR; Val: $007E221C),
  (Expr: C_CLILEFT; Val: $007E1C7C),
  (Expr: C_CLILOGGED; Val: $0059A504),
  (Expr: C_CLIXRES; Val: $0059BC50),
  (Expr: C_CONTPOS; Val: $0068EBB8),
  (Expr: C_CURSORKIND; Val: $007E1C08),
  (Expr: C_ENEMYHITS; Val: $00756948),
  (Expr: C_ENEMYID; Val: $0068DFA0),
  (Expr: C_JOURNALPTR; Val: $0081E514),
  (Expr: C_LHANDID; Val: $007ADC00),
  (Expr: C_LLIFTEDID; Val: $007E2268),
  (Expr: C_LSHARD; Val: $007E61F4),
  (Expr: C_NEXTCPOS; Val: $0068E134),
  (Expr: C_POPUPID; Val: $007E6368),
  (Expr: C_SHARDPOS; Val: $0068DFDC),
  (Expr: C_SKILLCAPS; Val: $00860744),
  (Expr: C_SKILLLOCK; Val: $008607B0),
  (Expr: C_SKILLSPOS; Val: $008607E8),
  (Expr: C_SYSMSG; Val: $0068EB98),
  (Expr: C_TARGETCNT; Val: $007DFA04),
  (Expr: C_TARGETCURS; Val: $007E1C4C),
  (Expr: E_DRAGADDR; Val: $00500E00),
  (Expr: E_EXMSGADDR; Val: $004FC810),
  (Expr: E_ITEMCHECKADDR; Val: $0051FC30),
  (Expr: E_ITEMNAMEADDR; Val: $004DE070),
  (Expr: E_ITEMPROPADDR; Val: $004DDF90),
  (Expr: E_ITEMPROPID; Val: $007A9A80),
  (Expr: E_ITEMREQADDR; Val: $00520260),
  (Expr: E_MACROADDR; Val: $004E2460),
  (Expr: E_OLDDIR; Val: $00534E50),
  (Expr: E_PATHFINDADDR; Val: $00492B0B),
  (Expr: E_REDIR; Val: $004F205C),
  (Expr: E_SENDPACKET; Val: $00415F80),
  (Expr: E_SLEEPADDR; Val: $0055D224),
  (Expr: E_SYSMSGADDR; Val: $0050F2E0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 124 -- first introduced at client '4.0.5b' (normalized '004.000.005.b')
SysVarMS124 : array[0..11] of TSysVarList = (
  (Expr: C_CLILOGGED; Val: $0059A4F4),
  (Expr: C_CLIXRES; Val: $0059BC40),
  (Expr: E_DRAGADDR; Val: $00501810),
  (Expr: E_EXMSGADDR; Val: $004FD240),
  (Expr: E_ITEMCHECKADDR; Val: $005206E0),
  (Expr: E_ITEMREQADDR; Val: $00520D10),
  (Expr: E_OLDDIR; Val: $00535830),
  (Expr: E_PATHFINDADDR; Val: $0049263B),
  (Expr: E_REDIR; Val: $004F290C),
  (Expr: E_SENDPACKET; Val: $00415F10),
  (Expr: E_SYSMSGADDR; Val: $0050FD60),
  (Expr: LISTEND; Val: 0)
);

// Milestone 125 -- first introduced at client '4.0.5a' (normalized '004.000.005.a')
SysVarMS125 : array[0..42] of TSysVarList = (
  (Expr: B_BILLFIRST; Val: $000000DC),
  (Expr: B_CONTITEM; Val: $0000004C),
  (Expr: B_CONTNEXT; Val: $00000058),
  (Expr: B_ENEMYHPVAL; Val: $000000C4),
  (Expr: B_EVSKILLPAR; Val: $000000D8),
  (Expr: B_SHOPCURRENT; Val: $000000CC),
  (Expr: B_SKILLDIST; Val: $0000006C),
  (Expr: B_STATNAME; Val: $000000C4),
  (Expr: B_SYSMSGSTR; Val: $00000100),
  (Expr: C_CHARDIR; Val: $00DCC778),
  (Expr: C_CHARPTR; Val: $00E00134),
  (Expr: C_CLILEFT; Val: $00DFFB94),
  (Expr: C_CONTPOS; Val: $008638D8),
  (Expr: C_CURSORKIND; Val: $00DFFB20),
  (Expr: C_ENEMYHITS; Val: $0092B668),
  (Expr: C_ENEMYID; Val: $0068E0C0),
  (Expr: C_JOURNALPTR; Val: $00E5249C),
  (Expr: C_LHANDID; Val: $00DCAB78),
  (Expr: C_LLIFTEDID; Val: $00E00180),
  (Expr: C_LSHARD; Val: $00E0410C),
  (Expr: C_NEXTCPOS; Val: $00862E54),
  (Expr: C_POPUPID; Val: $00E09280),
  (Expr: C_SHARDPOS; Val: $0068E0FC),
  (Expr: C_SKILLCAPS; Val: $00E946CC),
  (Expr: C_SKILLLOCK; Val: $00E94738),
  (Expr: C_SKILLSPOS; Val: $00E94770),
  (Expr: C_SYSMSG; Val: $008638B8),
  (Expr: C_TARGETCNT; Val: $00DFD91C),
  (Expr: C_TARGETCURS; Val: $00DFFB64),
  (Expr: E_DRAGADDR; Val: $00501630),
  (Expr: E_EXMSGADDR; Val: $004FD040),
  (Expr: E_ITEMCHECKADDR; Val: $00520620),
  (Expr: E_ITEMNAMEADDR; Val: $004DED00),
  (Expr: E_ITEMPROPADDR; Val: $004DEC20),
  (Expr: E_ITEMPROPID; Val: $00DC69F8),
  (Expr: E_ITEMREQADDR; Val: $00520C50),
  (Expr: E_MACROADDR; Val: $004E3090),
  (Expr: E_OLDDIR; Val: $005357A0),
  (Expr: E_PATHFINDADDR; Val: $0049246B),
  (Expr: E_REDIR; Val: $004F27AC),
  (Expr: E_SLEEPADDR; Val: $0055D228),
  (Expr: E_SYSMSGADDR; Val: $0050FC40),
  (Expr: LISTEND; Val: 0)
);

// Milestone 126 -- first introduced at client '4.0.4t' (normalized '004.000.004.t')
SysVarMS126 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00DCC780),
  (Expr: C_CHARPTR; Val: $00E0013C),
  (Expr: C_CLILEFT; Val: $00DFFB9C),
  (Expr: C_CLILOGGED; Val: $0059A4DC),
  (Expr: C_CLIXRES; Val: $0059BC28),
  (Expr: C_CONTPOS; Val: $008638E8),
  (Expr: C_CURSORKIND; Val: $00DFFB28),
  (Expr: C_ENEMYHITS; Val: $0092B670),
  (Expr: C_ENEMYID; Val: $0068E0C8),
  (Expr: C_JOURNALPTR; Val: $00E524A4),
  (Expr: C_LHANDID; Val: $00DCAB80),
  (Expr: C_LLIFTEDID; Val: $00E00188),
  (Expr: C_LSHARD; Val: $00E04114),
  (Expr: C_NEXTCPOS; Val: $00862E64),
  (Expr: C_POPUPID; Val: $00E09288),
  (Expr: C_SHARDPOS; Val: $0068E110),
  (Expr: C_SKILLCAPS; Val: $00E94044),
  (Expr: C_SKILLLOCK; Val: $00E940B0),
  (Expr: C_SKILLSPOS; Val: $00E940E8),
  (Expr: C_SYSMSG; Val: $008638C8),
  (Expr: C_TARGETCNT; Val: $00DFD924),
  (Expr: C_TARGETCURS; Val: $00DFFB6C),
  (Expr: E_DRAGADDR; Val: $00501530),
  (Expr: E_EXMSGADDR; Val: $004FCF50),
  (Expr: E_ITEMCHECKADDR; Val: $005205C0),
  (Expr: E_ITEMNAMEADDR; Val: $004DEB90),
  (Expr: E_ITEMPROPADDR; Val: $004DEAB0),
  (Expr: E_ITEMPROPID; Val: $00DC6A00),
  (Expr: E_ITEMREQADDR; Val: $00520BF0),
  (Expr: E_MACROADDR; Val: $004E2F80),
  (Expr: E_OLDDIR; Val: $00535700),
  (Expr: E_PATHFINDADDR; Val: $0049222B),
  (Expr: E_REDIR; Val: $004F268C),
  (Expr: E_SENDPACKET; Val: $00415FA0),
  (Expr: E_SLEEPADDR; Val: $0055D224),
  (Expr: E_SYSMSGADDR; Val: $0050FB50),
  (Expr: LISTEND; Val: 0)
);

// Milestone 127 -- first introduced at client '4.0.4b' (normalized '004.000.004.b')
SysVarMS127 : array[0..29] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00D9EE38),
  (Expr: C_CHARPTR; Val: $00DC27F4),
  (Expr: C_CLILEFT; Val: $00DC2254),
  (Expr: C_CURSORKIND; Val: $00DC21E0),
  (Expr: C_ENEMYHITS; Val: $00923E90),
  (Expr: C_ENEMYID; Val: $00686B00),
  (Expr: C_JOURNALPTR; Val: $00E14B4C),
  (Expr: C_LHANDID; Val: $00D9B2F8),
  (Expr: C_LLIFTEDID; Val: $00DC2840),
  (Expr: C_LSHARD; Val: $00DC67CC),
  (Expr: C_POPUPID; Val: $00DCB940),
  (Expr: C_SHARDPOS; Val: $00686B3C),
  (Expr: C_SKILLCAPS; Val: $00E56D7C),
  (Expr: C_SKILLLOCK; Val: $00E56DE4),
  (Expr: C_SKILLSPOS; Val: $00E56E18),
  (Expr: C_TARGETCNT; Val: $00DBFFDC),
  (Expr: C_TARGETCURS; Val: $00DC2224),
  (Expr: E_ITEMCHECKADDR; Val: $0051A0C0),
  (Expr: E_ITEMNAMEADDR; Val: $004D9160),
  (Expr: E_ITEMPROPADDR; Val: $004D9080),
  (Expr: E_ITEMPROPID; Val: $00D97178),
  (Expr: E_ITEMREQADDR; Val: $0051A6F0),
  (Expr: E_MACROADDR; Val: $004DD4B0),
  (Expr: E_OLDDIR; Val: $0052EB60),
  (Expr: E_PATHFINDADDR; Val: $0048EB5B),
  (Expr: E_REDIR; Val: $004ED95C),
  (Expr: E_SENDPACKET; Val: $00415B90),
  (Expr: E_SLEEPADDR; Val: $00556228),
  (Expr: E_SYSMSGADDR; Val: $00509730),
  (Expr: LISTEND; Val: 0)
);

// Milestone 128 -- first introduced at client '4.0.4a' (normalized '004.000.004.a')
SysVarMS128 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00D9EE30),
  (Expr: C_CHARPTR; Val: $00DC27EC),
  (Expr: C_CLILEFT; Val: $00DC224C),
  (Expr: C_CLILOGGED; Val: $00593314),
  (Expr: C_CLIXRES; Val: $00594A2C),
  (Expr: C_CONTPOS; Val: $0085C2F8),
  (Expr: C_CURSORKIND; Val: $00DC21D8),
  (Expr: C_ENEMYHITS; Val: $00923E88),
  (Expr: C_ENEMYID; Val: $00686AF8),
  (Expr: C_JOURNALPTR; Val: $00E14B44),
  (Expr: C_LHANDID; Val: $00D9B2F0),
  (Expr: C_LLIFTEDID; Val: $00DC2838),
  (Expr: C_LSHARD; Val: $00DC67C4),
  (Expr: C_NEXTCPOS; Val: $0085B874),
  (Expr: C_POPUPID; Val: $00DCB938),
  (Expr: C_SHARDPOS; Val: $00686B40),
  (Expr: C_SKILLCAPS; Val: $00E566E4),
  (Expr: C_SKILLLOCK; Val: $00E5674C),
  (Expr: C_SKILLSPOS; Val: $00E56780),
  (Expr: C_SYSMSG; Val: $0085C2D8),
  (Expr: C_TARGETCNT; Val: $00DBFFD4),
  (Expr: C_TARGETCURS; Val: $00DC221C),
  (Expr: E_DRAGADDR; Val: $004FC790),
  (Expr: E_EXMSGADDR; Val: $004F81E0),
  (Expr: E_ITEMCHECKADDR; Val: $00519FE0),
  (Expr: E_ITEMNAMEADDR; Val: $004D9170),
  (Expr: E_ITEMPROPADDR; Val: $004D9090),
  (Expr: E_ITEMPROPID; Val: $00D97170),
  (Expr: E_ITEMREQADDR; Val: $0051A610),
  (Expr: E_MACROADDR; Val: $004DD4C0),
  (Expr: E_OLDDIR; Val: $0052EA70),
  (Expr: E_PATHFINDADDR; Val: $0048E87B),
  (Expr: E_REDIR; Val: $004ED9BC),
  (Expr: E_SENDPACKET; Val: $00415A00),
  (Expr: E_SLEEPADDR; Val: $00556224),
  (Expr: E_SYSMSGADDR; Val: $005097A0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 129 -- first introduced at client '4.0.3e' (normalized '004.000.003.e')
SysVarMS129 : array[0..30] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00D9EDE0),
  (Expr: C_CHARPTR; Val: $00DC2764),
  (Expr: C_CLILEFT; Val: $00DC21D0),
  (Expr: C_CLILOGGED; Val: $005932EC),
  (Expr: C_CLIXRES; Val: $00594A04),
  (Expr: C_CONTPOS; Val: $0085C2A8),
  (Expr: C_CURSORKIND; Val: $00DC2188),
  (Expr: C_ENEMYHITS; Val: $00923E38),
  (Expr: C_ENEMYID; Val: $00686AA8),
  (Expr: C_JOURNALPTR; Val: $00E14ABC),
  (Expr: C_LHANDID; Val: $00D9B2A0),
  (Expr: C_LLIFTEDID; Val: $00DC27B0),
  (Expr: C_LSHARD; Val: $00DC673C),
  (Expr: C_NEXTCPOS; Val: $0085B824),
  (Expr: C_POPUPID; Val: $00DCB8B0),
  (Expr: C_SHARDPOS; Val: $00686AF0),
  (Expr: C_SKILLCAPS; Val: $00E5665C),
  (Expr: C_SKILLLOCK; Val: $00E566C4),
  (Expr: C_SKILLSPOS; Val: $00E566F8),
  (Expr: C_SYSMSG; Val: $0085C288),
  (Expr: C_TARGETCNT; Val: $00DBFF84),
  (Expr: C_TARGETCURS; Val: $00DC21A0),
  (Expr: E_ITEMCHECKADDR; Val: $00519560),
  (Expr: E_ITEMPROPID; Val: $00D97120),
  (Expr: E_ITEMREQADDR; Val: $00519B90),
  (Expr: E_OLDDIR; Val: $0052E030),
  (Expr: E_PATHFINDADDR; Val: $0048E9EB),
  (Expr: E_REDIR; Val: $004ED4AC),
  (Expr: E_SENDPACKET; Val: $00415A10),
  (Expr: E_SYSMSGADDR; Val: $00508CE0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 130 -- first introduced at client '4.0.3d' (normalized '004.000.003.d')
SysVarMS130 : array[0..36] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00D9EDF0),
  (Expr: C_CHARPTR; Val: $00DC2774),
  (Expr: C_CLILEFT; Val: $00DC21E0),
  (Expr: C_CLILOGGED; Val: $005932FC),
  (Expr: C_CLIXRES; Val: $00594A14),
  (Expr: C_CONTPOS; Val: $0085C2B8),
  (Expr: C_CURSORKIND; Val: $00DC2198),
  (Expr: C_ENEMYHITS; Val: $00923E48),
  (Expr: C_ENEMYID; Val: $00686AB8),
  (Expr: C_JOURNALPTR; Val: $00E14ACC),
  (Expr: C_LHANDID; Val: $00D9B2B0),
  (Expr: C_LLIFTEDID; Val: $00DC27C0),
  (Expr: C_LSHARD; Val: $00DC674C),
  (Expr: C_NEXTCPOS; Val: $0085B834),
  (Expr: C_POPUPID; Val: $00DCB8C0),
  (Expr: C_SHARDPOS; Val: $00686B00),
  (Expr: C_SKILLCAPS; Val: $00E5666C),
  (Expr: C_SKILLLOCK; Val: $00E566D4),
  (Expr: C_SKILLSPOS; Val: $00E56708),
  (Expr: C_SYSMSG; Val: $0085C298),
  (Expr: C_TARGETCNT; Val: $00DBFF94),
  (Expr: C_TARGETCURS; Val: $00DC21B0),
  (Expr: E_DRAGADDR; Val: $004FBD20),
  (Expr: E_EXMSGADDR; Val: $004F7770),
  (Expr: E_ITEMCHECKADDR; Val: $00519350),
  (Expr: E_ITEMNAMEADDR; Val: $004D8DF0),
  (Expr: E_ITEMPROPADDR; Val: $004D8D10),
  (Expr: E_ITEMPROPID; Val: $00D97130),
  (Expr: E_ITEMREQADDR; Val: $00519980),
  (Expr: E_MACROADDR; Val: $004DD010),
  (Expr: E_OLDDIR; Val: $0052DE90),
  (Expr: E_PATHFINDADDR; Val: $0048EAAB),
  (Expr: E_REDIR; Val: $004ED49C),
  (Expr: E_SENDPACKET; Val: $00415BE0),
  (Expr: E_SLEEPADDR; Val: $0055621C),
  (Expr: E_SYSMSGADDR; Val: $00508C90),
  (Expr: LISTEND; Val: 0)
);

// Milestone 131 -- first introduced at client '4.0.3c' (normalized '004.000.003.c')
SysVarMS131 : array[0..40] of TSysVarList = (
  (Expr: B_CHARSTATUS; Val: $00000024),
  (Expr: B_FINDREP; Val: $00000164),
  (Expr: B_GUMPPTR; Val: $00000038),
  (Expr: B_SHOPPRICE; Val: $00000030),
  (Expr: C_CHARDIR; Val: $00D9DDD0),
  (Expr: C_CHARPTR; Val: $00DC1754),
  (Expr: C_CLILEFT; Val: $00DC11C0),
  (Expr: C_CLILOGGED; Val: $005922FC),
  (Expr: C_CLIXRES; Val: $005939FC),
  (Expr: C_CONTPOS; Val: $0085B298),
  (Expr: C_CURSORKIND; Val: $00DC1178),
  (Expr: C_ENEMYHITS; Val: $00922E28),
  (Expr: C_ENEMYID; Val: $00685A98),
  (Expr: C_JOURNALPTR; Val: $00E13AAC),
  (Expr: C_LHANDID; Val: $00D9A290),
  (Expr: C_LLIFTEDID; Val: $00DC17A0),
  (Expr: C_LSHARD; Val: $00DC572C),
  (Expr: C_NEXTCPOS; Val: $0085A814),
  (Expr: C_POPUPID; Val: $00DCA8A0),
  (Expr: C_SHARDPOS; Val: $00685AE0),
  (Expr: C_SKILLCAPS; Val: $00E5564C),
  (Expr: C_SKILLLOCK; Val: $00E556B4),
  (Expr: C_SKILLSPOS; Val: $00E556E8),
  (Expr: C_SYSMSG; Val: $0085B278),
  (Expr: C_TARGETCNT; Val: $00DBEF74),
  (Expr: C_TARGETCURS; Val: $00DC1190),
  (Expr: E_DRAGADDR; Val: $004FBA50),
  (Expr: E_EXMSGADDR; Val: $004F7450),
  (Expr: E_ITEMCHECKADDR; Val: $00519240),
  (Expr: E_ITEMNAMEADDR; Val: $004D8940),
  (Expr: E_ITEMPROPADDR; Val: $004D8860),
  (Expr: E_ITEMPROPID; Val: $00D96110),
  (Expr: E_ITEMREQADDR; Val: $00519870),
  (Expr: E_MACROADDR; Val: $004DCB60),
  (Expr: E_OLDDIR; Val: $0052DD30),
  (Expr: E_PATHFINDADDR; Val: $0048E73B),
  (Expr: E_REDIR; Val: $004ED12C),
  (Expr: E_SENDPACKET; Val: $00415A60),
  (Expr: E_SLEEPADDR; Val: $0055521C),
  (Expr: E_SYSMSGADDR; Val: $005089C0),
  (Expr: LISTEND; Val: 0)
);

// Milestone 132 -- first introduced at client '4.0.3b' (normalized '004.000.003.b')
SysVarMS132 : array[0..37] of TSysVarList = (
  (Expr: B_LANG; Val: $00000148),
  (Expr: C_CHARDIR; Val: $00DC0DD0),
  (Expr: C_CHARPTR; Val: $00DE4764),
  (Expr: C_CLILEFT; Val: $00DE41D0),
  (Expr: C_CLILOGGED; Val: $005A8DDC),
  (Expr: C_CLIXRES; Val: $005AB33C),
  (Expr: C_CONTPOS; Val: $0087E298),
  (Expr: C_CURSORKIND; Val: $00DE4188),
  (Expr: C_ENEMYHITS; Val: $00945E28),
  (Expr: C_ENEMYID; Val: $006A8AB0),
  (Expr: C_JOURNALPTR; Val: $00E36ABC),
  (Expr: C_LHANDID; Val: $00DBD290),
  (Expr: C_LLIFTEDID; Val: $00DE47B0),
  (Expr: C_LSHARD; Val: $00DE873C),
  (Expr: C_NEXTCPOS; Val: $0087D814),
  (Expr: C_POPUPID; Val: $00DED8B0),
  (Expr: C_SHARDPOS; Val: $006A8AF8),
  (Expr: C_SKILLCAPS; Val: $00E786BC),
  (Expr: C_SKILLLOCK; Val: $00E78724),
  (Expr: C_SKILLSPOS; Val: $00E78758),
  (Expr: C_SYSMSG; Val: $0087E278),
  (Expr: C_TARGETCNT; Val: $00DE1F84),
  (Expr: C_TARGETCURS; Val: $00DE41A0),
  (Expr: E_DRAGADDR; Val: $004FE200),
  (Expr: E_EXMSGADDR; Val: $004F99E0),
  (Expr: E_ITEMCHECKADDR; Val: $0051C8C0),
  (Expr: E_ITEMNAMEADDR; Val: $004DA750),
  (Expr: E_ITEMPROPADDR; Val: $004DA670),
  (Expr: E_ITEMPROPID; Val: $00DB9110),
  (Expr: E_ITEMREQADDR; Val: $0051CEF0),
  (Expr: E_MACROADDR; Val: $004DEBE0),
  (Expr: E_OLDDIR; Val: $0053E300),
  (Expr: E_PATHFINDADDR; Val: $0049050B),
  (Expr: E_REDIR; Val: $004EF55C),
  (Expr: E_SENDPACKET; Val: $00415AD0),
  (Expr: E_SLEEPADDR; Val: $00567220),
  (Expr: E_SYSMSGADDR; Val: $0050BE90),
  (Expr: LISTEND; Val: 0)
);

// Milestone 133 -- first introduced at client '4.0.3a' (normalized '004.000.003.a')
SysVarMS133 : array[0..35] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00DBA598),
  (Expr: C_CHARPTR; Val: $00DDDD8C),
  (Expr: C_CLILEFT; Val: $00DDD7F8),
  (Expr: C_CLILOGGED; Val: $005A1E4C),
  (Expr: C_CLIXRES; Val: $005A4AA4),
  (Expr: C_CONTPOS; Val: $00877A2C),
  (Expr: C_CURSORKIND; Val: $00DDD7B0),
  (Expr: C_ENEMYHITS; Val: $0093F5C4),
  (Expr: C_ENEMYID; Val: $006A2240),
  (Expr: C_JOURNALPTR; Val: $00E300EC),
  (Expr: C_LHANDID; Val: $00DB6A3C),
  (Expr: C_LLIFTEDID; Val: $00DDDDD8),
  (Expr: C_LSHARD; Val: $00DE1D74),
  (Expr: C_NEXTCPOS; Val: $00876FA4),
  (Expr: C_POPUPID; Val: $00DE6EE8),
  (Expr: C_SHARDPOS; Val: $006A2288),
  (Expr: C_SKILLCAPS; Val: $00E71CE8),
  (Expr: C_SKILLLOCK; Val: $00E71D50),
  (Expr: C_SKILLSPOS; Val: $00E71D88),
  (Expr: C_SYSMSG; Val: $00877A0C),
  (Expr: C_TARGETCNT; Val: $00DDB5A4),
  (Expr: C_TARGETCURS; Val: $00DDD7C8),
  (Expr: E_DRAGADDR; Val: $004FA450),
  (Expr: E_EXMSGADDR; Val: $004F5D40),
  (Expr: E_ITEMCHECKADDR; Val: $00518310),
  (Expr: E_ITEMNAMEADDR; Val: $004D7150),
  (Expr: E_ITEMPROPADDR; Val: $004D7070),
  (Expr: E_ITEMPROPID; Val: $00DB28B8),
  (Expr: E_ITEMREQADDR; Val: $005189B0),
  (Expr: E_MACROADDR; Val: $004DB2F0),
  (Expr: E_OLDDIR; Val: $00539A30),
  (Expr: E_PATHFINDADDR; Val: $0048E27B),
  (Expr: E_REDIR; Val: $004EBADC),
  (Expr: E_SENDPACKET; Val: $004156F0),
  (Expr: E_SYSMSGADDR; Val: $00507D90),
  (Expr: LISTEND; Val: 0)
);

// Milestone 134 -- first introduced at client '4.0.2a' (normalized '004.000.002.a')
SysVarMS134 : array[0..46] of TSysVarList = (
  (Expr: B_BILLFIRST; Val: $000000CC),
  (Expr: B_CONTITEM; Val: $0000003C),
  (Expr: B_CONTNEXT; Val: $00000048),
  (Expr: B_CONTSIZEX; Val: $00000024),
  (Expr: B_CONTX; Val: $00000034),
  (Expr: B_ENEMYHPVAL; Val: $000000B4),
  (Expr: B_EVSKILLPAR; Val: $000000C8),
  (Expr: B_SHOPCURRENT; Val: $000000BC),
  (Expr: B_STATNAME; Val: $000000B4),
  (Expr: B_SYSMSGSTR; Val: $000000F0),
  (Expr: C_CHARDIR; Val: $00DBA560),
  (Expr: C_CHARPTR; Val: $00DDDD54),
  (Expr: C_CLILEFT; Val: $00DDD7C0),
  (Expr: C_CLILOGGED; Val: $005A1E34),
  (Expr: C_CLIXRES; Val: $005A4A84),
  (Expr: C_CONTPOS; Val: $008779FC),
  (Expr: C_CURSORKIND; Val: $00DDD778),
  (Expr: C_ENEMYHITS; Val: $0093F594),
  (Expr: C_ENEMYID; Val: $006A2210),
  (Expr: C_JOURNALPTR; Val: $00E300B4),
  (Expr: C_LHANDID; Val: $00DB6A04),
  (Expr: C_LLIFTEDID; Val: $00DDDDA0),
  (Expr: C_LSHARD; Val: $00DE1D3C),
  (Expr: C_NEXTCPOS; Val: $00876F74),
  (Expr: C_POPUPID; Val: $00DE6EB0),
  (Expr: C_SHARDPOS; Val: $006A2258),
  (Expr: C_SKILLCAPS; Val: $00E71CB0),
  (Expr: C_SKILLLOCK; Val: $00E71D18),
  (Expr: C_SKILLSPOS; Val: $00E71D50),
  (Expr: C_SYSMSG; Val: $008779DC),
  (Expr: C_TARGETCNT; Val: $00DDB56C),
  (Expr: C_TARGETCURS; Val: $00DDD790),
  (Expr: E_DRAGADDR; Val: $004FA240),
  (Expr: E_EXMSGADDR; Val: $004F5AB0),
  (Expr: E_ITEMCHECKADDR; Val: $005182B0),
  (Expr: E_ITEMNAMEADDR; Val: $004D6EC0),
  (Expr: E_ITEMPROPADDR; Val: $004D6DE0),
  (Expr: E_ITEMPROPID; Val: $00DB2880),
  (Expr: E_ITEMREQADDR; Val: $00518950),
  (Expr: E_MACROADDR; Val: $004DB050),
  (Expr: E_OLDDIR; Val: $005399B0),
  (Expr: E_PATHFINDADDR; Val: $0048DEEB),
  (Expr: E_REDIR; Val: $004EB7FC),
  (Expr: E_SENDPACKET; Val: $00415620),
  (Expr: E_SLEEPADDR; Val: $00562220),
  (Expr: E_SYSMSGADDR; Val: $00507D80),
  (Expr: LISTEND; Val: 0)
);

// Milestone 135 -- first introduced at client '4.0.1b' (normalized '004.000.001.b')
SysVarMS135 : array[0..37] of TSysVarList = (
  (Expr: C_CHARDIR; Val: $00DB9848),
  (Expr: C_CHARPTR; Val: $00DDD03C),
  (Expr: C_CLILEFT; Val: $00DDCAA8),
  (Expr: C_CLILOGGED; Val: $005A11FC),
  (Expr: C_CLIXRES; Val: $005A3E4C),
  (Expr: C_CONTPOS; Val: $00876CEC),
  (Expr: C_CURSORKIND; Val: $00DDCA60),
  (Expr: C_ENEMYHITS; Val: $0093E884),
  (Expr: C_ENEMYID; Val: $006A1500),
  (Expr: C_JOURNALPTR; Val: $00E2F39C),
  (Expr: C_LHANDID; Val: $00DB5CEC),
  (Expr: C_LLIFTEDID; Val: $00DDD088),
  (Expr: C_LSHARD; Val: $00DE1024),
  (Expr: C_NEXTCPOS; Val: $00876264),
  (Expr: C_POPUPID; Val: $00DE6198),
  (Expr: C_SHARDPOS; Val: $006A1548),
  (Expr: C_SKILLCAPS; Val: $00E70F98),
  (Expr: C_SKILLLOCK; Val: $00E71000),
  (Expr: C_SKILLSPOS; Val: $00E71038),
  (Expr: C_SYSMSG; Val: $00876CCC),
  (Expr: C_TARGETCNT; Val: $00DDA854),
  (Expr: C_TARGETCURS; Val: $00DDCA78),
  (Expr: E_DRAGADDR; Val: $004F9090),
  (Expr: E_EXMSGADDR; Val: $004F4700),
  (Expr: E_ITEMCHECKADDR; Val: $00517250),
  (Expr: E_ITEMNAMEADDR; Val: $004D5B90),
  (Expr: E_ITEMPROPADDR; Val: $004D5AB0),
  (Expr: E_ITEMPROPID; Val: $00DB1B68),
  (Expr: E_ITEMREQADDR; Val: $005178F0),
  (Expr: E_MACROADDR; Val: $004D9D60),
  (Expr: E_OLDDIR; Val: $00538290),
  (Expr: E_PATHFINDADDR; Val: $0048DC9B),
  (Expr: E_REDIR; Val: $004EA42C),
  (Expr: E_SENDPACKET; Val: $00415790),
  (Expr: E_SLEEPADDR; Val: $00561218),
  (Expr: E_SYSMSGADDR; Val: $00506C20),
  (Expr: F_EVPROPERTY; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 136 -- first introduced at client '4.0.0c' (normalized '004.000.000.c')
SysVarMS136 : array[0..50] of TSysVarList = (
  (Expr: B_BILLFIRST; Val: $000000C8),
  (Expr: B_CONTNEXT; Val: $00000044),
  (Expr: B_ENEMYHPVAL; Val: $000000B0),
  (Expr: B_EVSKILLPAR; Val: $000000C4),
  (Expr: B_ITEMSLOT; Val: $00000025),
  (Expr: B_ITEMSTACK; Val: $0000003E),
  (Expr: B_ITEMTYPE; Val: $00000038),
  (Expr: B_LANG; Val: $00000160),
  (Expr: B_SHOPCURRENT; Val: $000000B8),
  (Expr: B_SHOPNEXT; Val: $00000044),
  (Expr: B_SKILLDIST; Val: $00000068),
  (Expr: B_STATAR; Val: $0000003A),
  (Expr: B_STATNAME; Val: $000000B0),
  (Expr: B_STATWEIGHT; Val: $00000038),
  (Expr: B_SYSMSGSTR; Val: $000000EC),
  (Expr: B_TITHE; Val: $00000064),
  (Expr: C_CHARDIR; Val: $00DA2910),
  (Expr: C_CHARPTR; Val: $00DC6104),
  (Expr: C_CLILEFT; Val: $00DC5B70),
  (Expr: C_CLILOGGED; Val: $0058A8CC),
  (Expr: C_CLIXRES; Val: $0058D394),
  (Expr: C_CONTPOS; Val: $0085FF6C),
  (Expr: C_CURSORKIND; Val: $00DC5B28),
  (Expr: C_ENEMYHITS; Val: $00927B04),
  (Expr: C_ENEMYID; Val: $0068A780),
  (Expr: C_JOURNALPTR; Val: $00E1475C),
  (Expr: C_LHANDID; Val: $00D9EE5C),
  (Expr: C_LLIFTEDID; Val: $00DC6150),
  (Expr: C_NEXTCPOS; Val: $0085F4E0),
  (Expr: C_POPUPID; Val: $00DCB558),
  (Expr: C_SHARDPOS; Val: $0068A7C8),
  (Expr: C_SKILLCAPS; Val: $00E56358),
  (Expr: C_SKILLLOCK; Val: $00E563C0),
  (Expr: C_SKILLSPOS; Val: $00E563F8),
  (Expr: C_SYSMSG; Val: $0085FF4C),
  (Expr: C_TARGETCNT; Val: $00DC391C),
  (Expr: C_TARGETCURS; Val: $00DC5B40),
  (Expr: E_DRAGADDR; Val: $004EBC80),
  (Expr: E_EXMSGADDR; Val: $004E7410),
  (Expr: E_MACROADDR; Val: $004D1710),
  (Expr: E_OLDDIR; Val: $00527AD0),
  (Expr: E_PATHFINDADDR; Val: $00487AEB),
  (Expr: E_REDIR; Val: $004DD19C),
  (Expr: E_SENDECX; Val: $00000000),
  (Expr: E_SENDLEN; Val: $00000000),
  (Expr: E_SENDPACKET; Val: $004154E0),
  (Expr: E_SLEEPADDR; Val: $0054E1FC),
  (Expr: E_SYSMSGADDR; Val: $004F8660),
  (Expr: F_EXTSTAT; Val: $00000001),
  (Expr: F_MACROMAP; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

// Milestone 137 -- first introduced at client '3.0.0c' (normalized '003.000.000.c')
SysVarMS137 : array[0..34] of TSysVarList = (
  (Expr: B_ITEMID; Val: $00000080),
  (Expr: B_ITEMSTACK; Val: $00000042),
  (Expr: B_LLIFTEDKIND; Val: $00000030),
  (Expr: B_LLIFTEDTYPE; Val: $00000006),
  (Expr: B_SHOPNEXT; Val: $00000048),
  (Expr: C_CHARDIR; Val: $00CDB4B8),
  (Expr: C_CHARPTR; Val: $00CDEC8C),
  (Expr: C_CLILEFT; Val: $00CDE6F8),
  (Expr: C_CLILOGGED; Val: $005211CC),
  (Expr: C_CLIXRES; Val: $005239C8),
  (Expr: C_CONTPOS; Val: $0080B19C),
  (Expr: C_CURSORKIND; Val: $00CDE6B0),
  (Expr: C_ENEMYHITS; Val: $008D2B10),
  (Expr: C_ENEMYID; Val: $0063591C),
  (Expr: C_JOURNALPTR; Val: $00D2D1DC),
  (Expr: C_LHANDID; Val: $00CD7A34),
  (Expr: C_LLIFTEDID; Val: $00CDECD8),
  (Expr: C_NEXTCPOS; Val: $0080A730),
  (Expr: C_SHARDPOS; Val: $00635A4C),
  (Expr: C_SKILLLOCK; Val: $00D6EDD4),
  (Expr: C_SKILLSPOS; Val: $00D6EE08),
  (Expr: C_SYSMSG; Val: $0080B180),
  (Expr: C_TARGETCURS; Val: $00CDE6C8),
  (Expr: E_DRAGADDR; Val: $004CA5E0),
  (Expr: E_EXMSGADDR; Val: $004C5CD0),
  (Expr: E_MACROADDR; Val: $004B4B50),
  (Expr: E_OLDDIR; Val: $0049B060),
  (Expr: E_PATHFINDADDR; Val: $0047B97B),
  (Expr: E_REDIR; Val: $004CA226),
  (Expr: E_SENDECX; Val: $00CDE690),
  (Expr: E_SENDLEN; Val: $00635978),
  (Expr: E_SENDPACKET; Val: $0042EFF0),
  (Expr: E_SLEEPADDR; Val: $005001EC),
  (Expr: E_SYSMSGADDR; Val: $004D4D10),
  (Expr: LISTEND; Val: 0)
);

// Milestone 138 -- first introduced at client '2.0.3' (normalized '002.000.003')
SysVarMS138 : array[0..31] of TSysVarList = (
  (Expr: B_EVSKILLPAR; Val: $000000B8),
  (Expr: C_CHARDIR; Val: $00CC1FA8),
  (Expr: C_CHARPTR; Val: $00CC535C),
  (Expr: C_CLILEFT; Val: $00CC51CC),
  (Expr: C_CLILOGGED; Val: $0050A1C4),
  (Expr: C_CLIXRES; Val: $0050CC3C),
  (Expr: C_CONTPOS; Val: $00B6614C),
  (Expr: C_CURSORKIND; Val: $00CC5184),
  (Expr: C_ENEMYHITS; Val: $00D15B28),
  (Expr: C_ENEMYID; Val: $00CC5358),
  (Expr: C_JOURNALPTR; Val: $00D16B88),
  (Expr: C_LHANDID; Val: $00CC044C),
  (Expr: C_LLIFTEDID; Val: $00CC53A4),
  (Expr: C_NEXTCPOS; Val: $00B656E0),
  (Expr: C_SHARDPOS; Val: $00741CCC),
  (Expr: C_SKILLLOCK; Val: $00D5874C),
  (Expr: C_SKILLSPOS; Val: $00D58780),
  (Expr: C_SYSMSG; Val: $00B66130),
  (Expr: C_TARGETCURS; Val: $00CC519C),
  (Expr: E_DRAGADDR; Val: $004884D0),
  (Expr: E_EXMSGADDR; Val: $004842A0),
  (Expr: E_MACROADDR; Val: $004735F0),
  (Expr: E_OLDDIR; Val: $004E6281),
  (Expr: E_PATHFINDADDR; Val: $0047677B),
  (Expr: E_REDIR; Val: $004E0BA7),
  (Expr: E_SENDECX; Val: $00CC516C),
  (Expr: E_SENDLEN; Val: $00D15AF0),
  (Expr: E_SENDPACKET; Val: $004C2F70),
  (Expr: E_SLEEPADDR; Val: $004F1170),
  (Expr: E_SYSMSGADDR; Val: $004C4A70),
  (Expr: F_MACROMAP; Val: $00000000),
  (Expr: LISTEND; Val: 0)
);

// Milestone 139 -- first introduced at client '2.0.0' (normalized '002.000.000')
SysVarMS139 : array[0..59] of TSysVarList = (
  (Expr: B_BILLFIRST; Val: $000000BC),
  (Expr: B_CHARSTATUS; Val: $00000020),
  (Expr: B_CONTITEM; Val: $00000038),
  (Expr: B_CONTNEXT; Val: $00000040),
  (Expr: B_CONTSIZEX; Val: $00000020),
  (Expr: B_CONTX; Val: $00000030),
  (Expr: B_ENEMYHPVAL; Val: $000000A4),
  (Expr: B_EVSKILLPAR; Val: $000000B4),
  (Expr: B_FINDREP; Val: $00000160),
  (Expr: B_GUMPPTR; Val: $00000034),
  (Expr: B_ITEMID; Val: $0000007C),
  (Expr: B_ITEMSLOT; Val: $00000021),
  (Expr: B_ITEMSTACK; Val: $00000040),
  (Expr: B_ITEMTYPE; Val: $0000003C),
  (Expr: B_LANG; Val: $00000158),
  (Expr: B_LLIFTEDKIND; Val: $0000002C),
  (Expr: B_LLIFTEDTYPE; Val: $00000004),
  (Expr: B_LTARGTILE; Val: $00000028),
  (Expr: B_LTARGX; Val: $00000020),
  (Expr: B_MEMBASE; Val: $00830000),
  (Expr: B_SHOPCURRENT; Val: $000000AC),
  (Expr: B_SHOPNEXT; Val: $00000044),
  (Expr: B_SHOPPRICE; Val: $0000002C),
  (Expr: B_SKILLDIST; Val: $00000064),
  (Expr: B_STATAR; Val: $00000038),
  (Expr: B_STATNAME; Val: $000000A4),
  (Expr: B_STATWEIGHT; Val: $0000003A),
  (Expr: B_SYSMSGSTR; Val: $000000E0),
  (Expr: B_TARGPROC; Val: $00000010),
  (Expr: C_CHARDIR; Val: $00C85330),
  (Expr: C_CHARPTR; Val: $00C8850C),
  (Expr: C_CLILEFT; Val: $00C88378),
  (Expr: C_CLILOGGED; Val: $005000FC),
  (Expr: C_CLIXRES; Val: $0050284C),
  (Expr: C_CONTPOS; Val: $00B2950C),
  (Expr: C_CURSORKIND; Val: $00C88330),
  (Expr: C_ENEMYHITS; Val: $00CD8CA8),
  (Expr: C_ENEMYID; Val: $00C88508),
  (Expr: C_JOURNALPTR; Val: $00CD9D08),
  (Expr: C_LHANDID; Val: $00C837F4),
  (Expr: C_LLIFTEDID; Val: $00C88554),
  (Expr: C_NEXTCPOS; Val: $00B28AA0),
  (Expr: C_SHARDPOS; Val: $00705088),
  (Expr: C_SKILLLOCK; Val: $00D1B8BC),
  (Expr: C_SKILLSPOS; Val: $00D1B8F0),
  (Expr: C_SYSMSG; Val: $00B294F0),
  (Expr: C_TARGETCURS; Val: $00C88348),
  (Expr: E_DRAGADDR; Val: $00484210),
  (Expr: E_EXMSGADDR; Val: $004800C0),
  (Expr: E_MACROADDR; Val: $00471530),
  (Expr: E_OLDDIR; Val: $004DBEA6),
  (Expr: E_PATHFINDADDR; Val: $0047458B),
  (Expr: E_REDIR; Val: $004D7C57),
  (Expr: E_SENDECX; Val: $00C88330),
  (Expr: E_SENDLEN; Val: $00CD8C70),
  (Expr: E_SENDPACKET; Val: $004BCD60),
  (Expr: E_SLEEPADDR; Val: $004E7164),
  (Expr: E_SYSMSGADDR; Val: $004BE5A0),
  (Expr: F_MACROMAP; Val: $00000001),
  (Expr: LISTEND; Val: 0)
);

Milestones : array[0..139] of TMilestoneEntry = (
  (NormVer: '007.000.108.000'; List: @SysVarMS0),
  (NormVer: '007.000.099.001'; List: @SysVarMS1),
  (NormVer: '007.000.047.000'; List: @SysVarMS2),
  (NormVer: '007.000.046.024'; List: @SysVarMS3),
  (NormVer: '007.000.046.000'; List: @SysVarMS4),
  (NormVer: '007.000.045.089'; List: @SysVarMS5),
  (NormVer: '007.000.045.077'; List: @SysVarMS6),
  (NormVer: '007.000.045.065'; List: @SysVarMS7),
  (NormVer: '007.000.040.010'; List: @SysVarMS8),
  (NormVer: '007.000.038.000'; List: @SysVarMS9),
  (NormVer: '007.000.035.023'; List: @SysVarMS10),
  (NormVer: '007.000.035.003'; List: @SysVarMS11),
  (NormVer: '007.000.034.023'; List: @SysVarMS12),
  (NormVer: '007.000.034.015'; List: @SysVarMS13),
  (NormVer: '007.000.034.006'; List: @SysVarMS14),
  (NormVer: '007.000.034.002'; List: @SysVarMS15),
  (NormVer: '007.000.033.001'; List: @SysVarMS16),
  (NormVer: '007.000.032.011'; List: @SysVarMS17),
  (NormVer: '007.000.031.000'; List: @SysVarMS18),
  (NormVer: '007.000.030.001'; List: @SysVarMS19),
  (NormVer: '007.000.029.002'; List: @SysVarMS20),
  (NormVer: '007.000.027.066'; List: @SysVarMS21),
  (NormVer: '007.000.027.009'; List: @SysVarMS22),
  (NormVer: '007.000.027.007'; List: @SysVarMS23),
  (NormVer: '007.000.027.005'; List: @SysVarMS24),
  (NormVer: '007.000.026.004'; List: @SysVarMS25),
  (NormVer: '007.000.025.006'; List: @SysVarMS26),
  (NormVer: '007.000.024.003'; List: @SysVarMS27),
  (NormVer: '007.000.022.000'; List: @SysVarMS28),
  (NormVer: '007.000.021.002'; List: @SysVarMS29),
  (NormVer: '007.000.021.001'; List: @SysVarMS30),
  (NormVer: '007.000.020.000'; List: @SysVarMS31),
  (NormVer: '007.000.019.001'; List: @SysVarMS32),
  (NormVer: '007.000.019.000'; List: @SysVarMS33),
  (NormVer: '007.000.017.000'; List: @SysVarMS34),
  (NormVer: '007.000.016.000'; List: @SysVarMS35),
  (NormVer: '007.000.014.004'; List: @SysVarMS36),
  (NormVer: '007.000.014.003'; List: @SysVarMS37),
  (NormVer: '007.000.014.000'; List: @SysVarMS38),
  (NormVer: '007.000.013.001'; List: @SysVarMS39),
  (NormVer: '007.000.013.000'; List: @SysVarMS40),
  (NormVer: '007.000.012.000'; List: @SysVarMS41),
  (NormVer: '007.000.011.002'; List: @SysVarMS42),
  (NormVer: '007.000.011.000'; List: @SysVarMS43),
  (NormVer: '007.000.010.002'; List: @SysVarMS44),
  (NormVer: '007.000.010.001'; List: @SysVarMS45),
  (NormVer: '007.000.009.000'; List: @SysVarMS46),
  (NormVer: '007.000.008.002'; List: @SysVarMS47),
  (NormVer: '007.000.008.000'; List: @SysVarMS48),
  (NormVer: '007.000.007.001'; List: @SysVarMS49),
  (NormVer: '007.000.007.000'; List: @SysVarMS50),
  (NormVer: '007.000.006.004'; List: @SysVarMS51),
  (NormVer: '007.000.006.003'; List: @SysVarMS52),
  (NormVer: '007.000.005.000'; List: @SysVarMS53),
  (NormVer: '007.000.004.005'; List: @SysVarMS54),
  (NormVer: '007.000.004.004'; List: @SysVarMS55),
  (NormVer: '007.000.004.003'; List: @SysVarMS56),
  (NormVer: '007.000.004.002'; List: @SysVarMS57),
  (NormVer: '007.000.004.001'; List: @SysVarMS58),
  (NormVer: '007.000.004.000'; List: @SysVarMS59),
  (NormVer: '007.000.003.000'; List: @SysVarMS60),
  (NormVer: '007.000.002.001'; List: @SysVarMS61),
  (NormVer: '007.000.001.001'; List: @SysVarMS62),
  (NormVer: '007.000.000.004'; List: @SysVarMS63),
  (NormVer: '007.000.000.003'; List: @SysVarMS64),
  (NormVer: '007.000.000.002'; List: @SysVarMS65),
  (NormVer: '007.000.000.000'; List: @SysVarMS66),
  (NormVer: '006.000.014.002'; List: @SysVarMS67),
  (NormVer: '006.000.013.000'; List: @SysVarMS68),
  (NormVer: '006.000.012.004'; List: @SysVarMS69),
  (NormVer: '006.000.012.003'; List: @SysVarMS70),
  (NormVer: '006.000.012.000'; List: @SysVarMS71),
  (NormVer: '006.000.011.000'; List: @SysVarMS72),
  (NormVer: '006.000.008.000'; List: @SysVarMS73),
  (NormVer: '006.000.007.000'; List: @SysVarMS74),
  (NormVer: '006.000.006.002'; List: @SysVarMS75),
  (NormVer: '006.000.006.001'; List: @SysVarMS76),
  (NormVer: '006.000.006.000'; List: @SysVarMS77),
  (NormVer: '006.000.005.000'; List: @SysVarMS78),
  (NormVer: '006.000.004.000'; List: @SysVarMS79),
  (NormVer: '006.000.003.000'; List: @SysVarMS80),
  (NormVer: '006.000.001.007'; List: @SysVarMS81),
  (NormVer: '006.000.001.005'; List: @SysVarMS82),
  (NormVer: '006.000.001.003'; List: @SysVarMS83),
  (NormVer: '006.000.001.002'; List: @SysVarMS84),
  (NormVer: '006.000.001.000'; List: @SysVarMS85),
  (NormVer: '006.000.000.000'; List: @SysVarMS86),
  (NormVer: '005.000.009.001'; List: @SysVarMS87),
  (NormVer: '005.000.009.000'; List: @SysVarMS88),
  (NormVer: '005.000.008.001'; List: @SysVarMS89),
  (NormVer: '005.000.007.002'; List: @SysVarMS90),
  (NormVer: '005.000.007.001'; List: @SysVarMS91),
  (NormVer: '005.000.006.005'; List: @SysVarMS92),
  (NormVer: '005.000.005.c'; List: @SysVarMS93),
  (NormVer: '005.000.005.a'; List: @SysVarMS94),
  (NormVer: '005.000.004.e'; List: @SysVarMS95),
  (NormVer: '005.000.004.d'; List: @SysVarMS96),
  (NormVer: '005.000.004.b'; List: @SysVarMS97),
  (NormVer: '005.000.004.a'; List: @SysVarMS98),
  (NormVer: '005.000.003'; List: @SysVarMS99),
  (NormVer: '005.000.002.f'; List: @SysVarMS100),
  (NormVer: '005.000.002.c'; List: @SysVarMS101),
  (NormVer: '005.000.002.b'; List: @SysVarMS102),
  (NormVer: '005.000.002.a'; List: @SysVarMS103),
  (NormVer: '005.000.002'; List: @SysVarMS104),
  (NormVer: '005.000.001.j'; List: @SysVarMS105),
  (NormVer: '005.000.001.i'; List: @SysVarMS106),
  (NormVer: '005.000.001.f'; List: @SysVarMS107),
  (NormVer: '005.000.001.d'; List: @SysVarMS108),
  (NormVer: '005.000.001.d'; List: @SysVarMS109),
  (NormVer: '005.000.001.a'; List: @SysVarMS110),
  (NormVer: '005.000.001.a'; List: @SysVarMS111),
  (NormVer: '005.000.000.b'; List: @SysVarMS112),
  (NormVer: '005.000.000.a'; List: @SysVarMS113),
  (NormVer: '004.000.011.e'; List: @SysVarMS114),
  (NormVer: '004.000.011.c'; List: @SysVarMS115),
  (NormVer: '004.000.011.b'; List: @SysVarMS116),
  (NormVer: '004.000.011.a'; List: @SysVarMS117),
  (NormVer: '004.000.010.b'; List: @SysVarMS118),
  (NormVer: '004.000.010.a'; List: @SysVarMS119),
  (NormVer: '004.000.009.a'; List: @SysVarMS120),
  (NormVer: '004.000.007.b'; List: @SysVarMS121),
  (NormVer: '004.000.007.a'; List: @SysVarMS122),
  (NormVer: '004.000.006.a'; List: @SysVarMS123),
  (NormVer: '004.000.005.b'; List: @SysVarMS124),
  (NormVer: '004.000.005.a'; List: @SysVarMS125),
  (NormVer: '004.000.004.t'; List: @SysVarMS126),
  (NormVer: '004.000.004.b'; List: @SysVarMS127),
  (NormVer: '004.000.004.a'; List: @SysVarMS128),
  (NormVer: '004.000.003.e'; List: @SysVarMS129),
  (NormVer: '004.000.003.d'; List: @SysVarMS130),
  (NormVer: '004.000.003.c'; List: @SysVarMS131),
  (NormVer: '004.000.003.b'; List: @SysVarMS132),
  (NormVer: '004.000.003.a'; List: @SysVarMS133),
  (NormVer: '004.000.002.a'; List: @SysVarMS134),
  (NormVer: '004.000.001.b'; List: @SysVarMS135),
  (NormVer: '004.000.000.c'; List: @SysVarMS136),
  (NormVer: '003.000.000.c'; List: @SysVarMS137),
  (NormVer: '002.000.003'; List: @SysVarMS138),
  (NormVer: '002.000.000'; List: @SysVarMS139)
);

VersionIndex : array[0..221] of TVersionIndexEntry = (
  (Cli: '7.0.108.0'; Milestone: 0),
  (Cli: '7.0.99.1'; Milestone: 1),
  (Cli: '7.0.47.0'; Milestone: 2),
  (Cli: '7.0.46.24'; Milestone: 3),
  (Cli: '7.0.46.2'; Milestone: 4),
  (Cli: '7.0.46.0'; Milestone: 4),
  (Cli: '7.0.45.89'; Milestone: 5),
  (Cli: '7.0.45.77'; Milestone: 6),
  (Cli: '7.0.45.65'; Milestone: 7),
  (Cli: '7.0.45.0'; Milestone: 8),
  (Cli: '7.0.44.2'; Milestone: 8),
  (Cli: '7.0.43.1'; Milestone: 8),
  (Cli: '7.0.42.0'; Milestone: 8),
  (Cli: '7.0.41.1'; Milestone: 8),
  (Cli: '7.0.40.10'; Milestone: 8),
  (Cli: '7.0.40.1'; Milestone: 9),
  (Cli: '7.0.40.0'; Milestone: 9),
  (Cli: '7.0.39.0'; Milestone: 9),
  (Cli: '7.0.38.2'; Milestone: 9),
  (Cli: '7.0.38.1'; Milestone: 9),
  (Cli: '7.0.38.0'; Milestone: 9),
  (Cli: '7.0.37.0'; Milestone: 10),
  (Cli: '7.0.36.0'; Milestone: 10),
  (Cli: '7.0.35.23'; Milestone: 10),
  (Cli: '7.0.35.6'; Milestone: 11),
  (Cli: '7.0.35.3'; Milestone: 11),
  (Cli: '7.0.35.1'; Milestone: 12),
  (Cli: '7.0.35.0'; Milestone: 12),
  (Cli: '7.0.34.23'; Milestone: 12),
  (Cli: '7.0.34.15'; Milestone: 13),
  (Cli: '7.0.34.6'; Milestone: 14),
  (Cli: '7.0.34.2'; Milestone: 15),
  (Cli: '7.0.33.1'; Milestone: 16),
  (Cli: '7.0.32.11'; Milestone: 17),
  (Cli: '7.0.31.0'; Milestone: 18),
  (Cli: '7.0.30.3'; Milestone: 19),
  (Cli: '7.0.30.2'; Milestone: 19),
  (Cli: '7.0.30.1'; Milestone: 19),
  (Cli: '7.0.29.3'; Milestone: 20),
  (Cli: '7.0.29.2'; Milestone: 20),
  (Cli: '7.0.28.0'; Milestone: 21),
  (Cli: '7.0.27.66'; Milestone: 21),
  (Cli: '7.0.27.9'; Milestone: 22),
  (Cli: '7.0.27.8'; Milestone: 23),
  (Cli: '7.0.27.7'; Milestone: 23),
  (Cli: '7.0.27.5'; Milestone: 24),
  (Cli: '7.0.26.5'; Milestone: 25),
  (Cli: '7.0.26.4'; Milestone: 25),
  (Cli: '7.0.25.7'; Milestone: 26),
  (Cli: '7.0.25.6'; Milestone: 26),
  (Cli: '7.0.24.5'; Milestone: 27),
  (Cli: '7.0.24.3'; Milestone: 27),
  (Cli: '7.0.23.1'; Milestone: 28),
  (Cli: '7.0.23.0'; Milestone: 28),
  (Cli: '7.0.22.8'; Milestone: 28),
  (Cli: '7.0.22.0'; Milestone: 28),
  (Cli: '7.0.21.2'; Milestone: 29),
  (Cli: '7.0.21.1'; Milestone: 30),
  (Cli: '7.0.20.0'; Milestone: 31),
  (Cli: '7.0.19.1'; Milestone: 32),
  (Cli: '7.0.19.0'; Milestone: 33),
  (Cli: '7.0.18.0'; Milestone: 34),
  (Cli: '7.0.17.0'; Milestone: 34),
  (Cli: '7.0.16.3'; Milestone: 35),
  (Cli: '7.0.16.1'; Milestone: 35),
  (Cli: '7.0.16.0'; Milestone: 35),
  (Cli: '7.0.15.1'; Milestone: 36),
  (Cli: '7.0.14.4'; Milestone: 36),
  (Cli: '7.0.14.3'; Milestone: 37),
  (Cli: '7.0.14.2'; Milestone: 38),
  (Cli: '7.0.14.0'; Milestone: 38),
  (Cli: '7.0.13.4'; Milestone: 39),
  (Cli: '7.0.13.3'; Milestone: 39),
  (Cli: '7.0.13.2'; Milestone: 39),
  (Cli: '7.0.13.1'; Milestone: 39),
  (Cli: '7.0.13.0'; Milestone: 40),
  (Cli: '7.0.12.1'; Milestone: 41),
  (Cli: '7.0.12.0'; Milestone: 41),
  (Cli: '7.0.11.4'; Milestone: 42),
  (Cli: '7.0.11.3'; Milestone: 42),
  (Cli: '7.0.11.2'; Milestone: 42),
  (Cli: '7.0.11.1'; Milestone: 43),
  (Cli: '7.0.11.0'; Milestone: 43),
  (Cli: '7.0.10.3'; Milestone: 44),
  (Cli: '7.0.10.2'; Milestone: 44),
  (Cli: '7.0.10.1'; Milestone: 45),
  (Cli: '7.0.9.1'; Milestone: 46),
  (Cli: '7.0.9.0'; Milestone: 46),
  (Cli: '7.0.8.2'; Milestone: 47),
  (Cli: '7.0.8.1'; Milestone: 48),
  (Cli: '7.0.8.0'; Milestone: 48),
  (Cli: '7.0.7.3'; Milestone: 49),
  (Cli: '7.0.7.1'; Milestone: 49),
  (Cli: '7.0.7.0'; Milestone: 50),
  (Cli: '7.0.6.5'; Milestone: 51),
  (Cli: '7.0.6.4'; Milestone: 51),
  (Cli: '7.0.6.3'; Milestone: 52),
  (Cli: '7.0.5.0'; Milestone: 53),
  (Cli: '7.0.4.5'; Milestone: 54),
  (Cli: '7.0.4.4'; Milestone: 55),
  (Cli: '7.0.4.3'; Milestone: 56),
  (Cli: '7.0.4.2'; Milestone: 57),
  (Cli: '7.0.4.1'; Milestone: 58),
  (Cli: '7.0.4.0'; Milestone: 59),
  (Cli: '7.0.3.1'; Milestone: 60),
  (Cli: '7.0.3.0'; Milestone: 60),
  (Cli: '7.0.2.2'; Milestone: 61),
  (Cli: '7.0.2.1'; Milestone: 61),
  (Cli: '7.0.1.1'; Milestone: 62),
  (Cli: '7.0.0.4'; Milestone: 63),
  (Cli: '7.0.0.3'; Milestone: 64),
  (Cli: '7.0.0.2'; Milestone: 65),
  (Cli: '7.0.0.0'; Milestone: 66),
  (Cli: '6.0.14.3'; Milestone: 67),
  (Cli: '6.0.14.2'; Milestone: 67),
  (Cli: '6.0.14.1'; Milestone: 68),
  (Cli: '6.0.13.1'; Milestone: 68),
  (Cli: '6.0.13.0'; Milestone: 68),
  (Cli: '6.0.12.4'; Milestone: 69),
  (Cli: '6.0.12.3'; Milestone: 70),
  (Cli: '6.0.12.0'; Milestone: 71),
  (Cli: '6.0.11.0'; Milestone: 72),
  (Cli: '6.0.10.0'; Milestone: 73),
  (Cli: '6.0.9.2'; Milestone: 73),
  (Cli: '6.0.9.1'; Milestone: 73),
  (Cli: '6.0.9.0'; Milestone: 73),
  (Cli: '6.0.8.0'; Milestone: 73),
  (Cli: '6.0.7.0'; Milestone: 74),
  (Cli: '6.0.6.2'; Milestone: 75),
  (Cli: '6.0.6.1'; Milestone: 76),
  (Cli: '6.0.6.0'; Milestone: 77),
  (Cli: '6.0.5.0'; Milestone: 78),
  (Cli: '6.0.4.0'; Milestone: 79),
  (Cli: '6.0.3.1'; Milestone: 80),
  (Cli: '6.0.3.0'; Milestone: 80),
  (Cli: '6.0.2.2'; Milestone: 81),
  (Cli: '6.0.2.1'; Milestone: 81),
  (Cli: '6.0.2.0'; Milestone: 81),
  (Cli: '6.0.1.10'; Milestone: 81),
  (Cli: '6.0.1.9'; Milestone: 81),
  (Cli: '6.0.1.8'; Milestone: 81),
  (Cli: '6.0.1.7'; Milestone: 81),
  (Cli: '6.0.1.6'; Milestone: 82),
  (Cli: '6.0.1.5'; Milestone: 82),
  (Cli: '6.0.1.4'; Milestone: 83),
  (Cli: '6.0.1.3'; Milestone: 83),
  (Cli: '6.0.1.2'; Milestone: 84),
  (Cli: '6.0.1.1'; Milestone: 85),
  (Cli: '6.0.1.0'; Milestone: 85),
  (Cli: '6.0.0.0'; Milestone: 86),
  (Cli: '5.0.9.1'; Milestone: 87),
  (Cli: '5.0.9.0'; Milestone: 88),
  (Cli: '5.0.8.4'; Milestone: 89),
  (Cli: '5.0.8.3'; Milestone: 89),
  (Cli: '5.0.8.2'; Milestone: 89),
  (Cli: '5.0.8.1'; Milestone: 89),
  (Cli: '5.0.8.0'; Milestone: 90),
  (Cli: '5.0.7.2'; Milestone: 90),
  (Cli: '5.0.7.1'; Milestone: 91),
  (Cli: '5.0.7.0'; Milestone: 92),
  (Cli: '5.0.6.5'; Milestone: 92),
  (Cli: '5.0.6e'; Milestone: 93),
  (Cli: '5.0.6d'; Milestone: 93),
  (Cli: '5.0.6c'; Milestone: 93),
  (Cli: '5.0.6b'; Milestone: 93),
  (Cli: '5.0.6a'; Milestone: 93),
  (Cli: '5.0.5c'; Milestone: 93),
  (Cli: '5.0.5b'; Milestone: 94),
  (Cli: '5.0.5a'; Milestone: 94),
  (Cli: '5.0.4e'; Milestone: 95),
  (Cli: '5.0.4d'; Milestone: 96),
  (Cli: '5.0.4c'; Milestone: 97),
  (Cli: '5.0.4b'; Milestone: 97),
  (Cli: '5.0.4a'; Milestone: 98),
  (Cli: '5.0.3'; Milestone: 99),
  (Cli: '5.0.2g'; Milestone: 100),
  (Cli: '5.0.2f'; Milestone: 100),
  (Cli: '5.0.2d'; Milestone: 101),
  (Cli: '5.0.2c'; Milestone: 101),
  (Cli: '5.0.2b'; Milestone: 102),
  (Cli: '5.0.2a'; Milestone: 103),
  (Cli: '5.0.2'; Milestone: 104),
  (Cli: '5.0.1j'; Milestone: 105),
  (Cli: '5.0.1i'; Milestone: 106),
  (Cli: '5.0.1h'; Milestone: 107),
  (Cli: '5.0.1f'; Milestone: 107),
  (Cli: '5.0.1d'; Milestone: 108),
  (Cli: '5.0.1d1'; Milestone: 109),
  (Cli: '5.0.1c'; Milestone: 110),
  (Cli: '5.0.1a'; Milestone: 110),
  (Cli: '5.0.1a1'; Milestone: 111),
  (Cli: '5.0.0b'; Milestone: 112),
  (Cli: '5.0.0a'; Milestone: 113),
  (Cli: '4.0.11f'; Milestone: 114),
  (Cli: '4.0.11e'; Milestone: 114),
  (Cli: '4.0.11c'; Milestone: 115),
  (Cli: '4.0.11b'; Milestone: 116),
  (Cli: '4.0.11a'; Milestone: 117),
  (Cli: '4.0.10b'; Milestone: 118),
  (Cli: '4.0.10a'; Milestone: 119),
  (Cli: '4.0.9b'; Milestone: 120),
  (Cli: '4.0.9a'; Milestone: 120),
  (Cli: '4.0.8a'; Milestone: 121),
  (Cli: '4.0.7b'; Milestone: 121),
  (Cli: '4.0.7a'; Milestone: 122),
  (Cli: '4.0.6a'; Milestone: 123),
  (Cli: '4.0.5b'; Milestone: 124),
  (Cli: '4.0.5a'; Milestone: 125),
  (Cli: '4.0.4t'; Milestone: 126),
  (Cli: '4.0.4b'; Milestone: 127),
  (Cli: '4.0.4a'; Milestone: 128),
  (Cli: '4.0.3e'; Milestone: 129),
  (Cli: '4.0.3d'; Milestone: 130),
  (Cli: '4.0.3c'; Milestone: 131),
  (Cli: '4.0.3b'; Milestone: 132),
  (Cli: '4.0.3a'; Milestone: 133),
  (Cli: '4.0.2a'; Milestone: 134),
  (Cli: '4.0.1b'; Milestone: 135),
  (Cli: '4.0.0c'; Milestone: 136),
  (Cli: '3.0.0c'; Milestone: 137),
  (Cli: '2.0.3'; Milestone: 138),
  (Cli: '2.0.0'; Milestone: 139)
);


////////////////////////////////////////////////////////////////////////////////
// ^^^ END MILESTONE/DELTA DATA ^^^
////////////////////////////////////////////////////////////////////////////////

// Ports Gemini's FormatCliVer (strip one trailing [a-z] suffix, zero-pad each
// dot-separated numeric segment to 3 digits, rejoin, re-append the suffix), but adds an
// explicit guard (first character must be a digit) rather than silently relying on the
// ASCII-incidental fact that '.' < '0' to make garbage strings fall off
// FloorMilestoneIndex's end -- that's true today, but it's a fragile thing to depend on
// silently. Returns False (NormVer undefined) for anything that doesn't even look like a
// version string -- the caller (Update/CliVerSupported) treats that as "unrecognized."
function TryNormalizeVersion(const CliVer : String; out NormVer : String) : Boolean;
var
  S, Part, Suffix : String;
  P : Integer;
begin
  Result := (CliVer <> '') and (CliVer[1] in ['0'..'9']);
  if not Result then Exit;

  S := LowerCase(CliVer);
  Suffix := '';
  for P := 1 to Length(S) do
    if S[P] in ['a'..'z'] then
    begin
      Suffix := '.' + S[P];
      Delete(S, P, Length(S));
      Break;
    end;

  NormVer := '';
  while S <> '' do
  begin
    P := Pos('.', S + '.');
    Part := Copy(S, 1, P - 1);
    Delete(S, 1, P);
    Part := Copy('000' + Part, Length('000' + Part) - 2, 3);
    NormVer := NormVer + Part + '.';
  end;
  if Length(NormVer) > 0 then
    Delete(NormVer, Length(NormVer), 1);
  NormVer := NormVer + Suffix;
end;

// Pass 1 of Update's two-pass lookup -- exact (case-insensitive) match against one of the
// known version strings in VersionIndex. Guaranteed bit-identical to the old flat table's
// resolution for every one of the 222 originally-verified versions, with ZERO dependence
// on FloorMilestoneIndex's normalized-string comparator (see this file's header comment
// for why that matters: two genuinely irregular strings, '5.0.1d1'/'5.0.1a1', normalize to
// the SAME key as their non-'1'-suffixed neighbors and would be ambiguous under a
// comparator alone -- Pass 1 never needs to adjudicate that, since it matches the exact
// string first).
function ExactMatchMilestoneIndex(const LowerCli : String) : Integer;
var
  Cnt : Integer;
begin
  for Cnt := 0 to High(VersionIndex) do
    if LowerCase(VersionIndex[Cnt].Cli) = LowerCli then
    begin
      Result := VersionIndex[Cnt].Milestone;
      Exit;
    end;
  Result := -1;
end;

// Pass 2 of Update's two-pass lookup -- only ever reached for a version string that is
// NOT one of the known ones. Milestones is ordered newest-first (index 0 = newest), so
// this walks forward while the target is newer than the current candidate, stopping at
// the first (i.e. newest) milestone whose NormVer <= the target -- a floor lookup.
// Returns -1 if the target is older than every known milestone.
function FloorMilestoneIndex(const NormVer : String) : Integer;
var
  Cnt : Integer;
begin
  Cnt := 0;
  while (Cnt <= High(Milestones)) and (Milestones[Cnt].NormVer > NormVer) do
    Inc(Cnt);
  if Cnt > High(Milestones) then Result := -1
  else Result := Cnt;
end;

////////////////////////////////////////////////////////////////////////////////
function CliVerSupported(const CliVer : String) : Boolean;
var
  NormVer : String;
begin
  Result := False;
  if CliVer = '' then Exit;
  if ExactMatchMilestoneIndex(LowerCase(CliVer)) <> -1 then Exit(True);
  if not TryNormalizeVersion(CliVer, NormVer) then Exit;
  Result := FloorMilestoneIndex(NormVer) <> -1;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// DYNAMIC RUNTIME SCANNING -- see this file's header comment for scope. Deliberately a
// small, rigorously-validated starter set (2 entries), not an attempt at broad coverage.
const
  Threshold_6062 = '006.000.006.002';

  ScannerTable_Pre6062  : array[0..0] of TScannerEntry = (
    // No pre-6.0.6.2 patterns yet -- scanning simply finds nothing for these older
    // clients and never overrides their milestone-resolved values. Extending this table
    // is exactly the kind of small, incremental follow-up this redesign is meant to make
    // easy; it needs its own dedicated period-correct client to validate against, which
    // this session did not have.
    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 0; AddOffset2: 0; Expr: LISTEND; Pattern: nil)
  );

  // Originally a small, deliberately-scoped 2-entry starter set (C_BLOCKINFO/C_SYSMSG
  // only); expanded to near-full C_*/E_* coverage after a user asked, for a second real
  // client running a version this file has no milestone for at all (7.0.117.0, alongside
  // a known 7.0.108.0 client), "is there a way for the second client to attempt to auto
  // find memory locations [without] the code [being] changed" -- i.e. use the dynamic
  // scanning mechanism this redesign already built, rather than hand-authoring a new
  // milestone. It wasn't fully wired up to do that yet, so it now is.
  //
  // Every entry below was MECHANICALLY VALIDATED, not hand-transcribed or guessed: all 41
  // scan-string lines in tools\EUOUpdater\"EUO Updtr Strings 6062 and newer.txt" were
  // parsed with that tool's own exact GetAddr algorithm (main.pas) and run live via
  // SearchMem/ReadMem against an actually-running 7.0.108.0 client, then cross-checked
  // field-by-field against milestone 0's already-independently-verified values below --
  // 37 of 41 lines matched bit-exactly (the 4 that didn't: the file's own {SYSMSG}
  // pattern, already known not to apply to this generation per milestone 0's own comment,
  // replaced by the hand-derived entry below instead; and 2 of 3 alternate {SKILLCAPS}/
  // {SKILLLOCK}/{SKILLSPOS} pattern lines the file itself offers as fallbacks, whose
  // OTHER alternate line already matched and is what's used here). Only entries that
  // passed this check were kept. Every one of the 37 was then ALSO run against the live,
  // unknown 7.0.117.0 client and found a match there too (see the version-support
  // decisions record for the full validation transcript) -- concrete evidence the pattern
  // shapes generalize across at least this much of the client generation, which is the
  // entire premise dynamic scanning relies on.
  //
  // Every entry's Joker is $11 (hex), matching this project's own tools\EUOUpdater
  // scan-string convention (main.pas: StrToIntDef('$'+sPar[2],1)) -- NOT the EasyUOGemini
  // reference's mismatched decimal-11 literal (see the git history around this table's
  // introduction for that discrepancy). Mode mapping from the scan-string file's own
  // column: 'X' (direct, no dereference) -> Mode 1; 'C' (dereference only) -> Mode 3;
  // 'CB' (dereference, then treat as a call/jmp relative displacement) -> Mode 2 --
  // confirmed by reading GetAddr's own implementation line-for-line, not inferred.
  //
  // C_TARGETCNT has no entry here (and never has) -- not covered by any scan string in
  // the file at all, and every known version's own milestone data also carries $00000000
  // for it, consistent with it being vestigial (see milestone 0's own comment).
  ScannerTable_Post6062 : array[0..38] of TScannerEntry = (
    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 1; AddOffset2: 0;
     Expr: C_BLOCKINFO; Pattern: 'B820180000E8'),
    // NOT reused from the scan-string file -- that pattern is already known not to match
    // this client generation (see milestone 0's own comment). Instead encodes the shape of
    // the shared "add message" routine milestone 0's own live-disassembly investigation
    // found (python3+capstone against the running 7.0.108.0 client, re-confirmed and
    // extended while wiring up this table): a 50-byte span from the routine's own
    // `mov edx,[ADDR]` read of the C_SYSMSG list-head pointer through to its later
    // `mov [ADDR],ebp` write of the same address, with BOTH embedded ADDR occurrences
    // wildcarded so the pattern generalizes across a build's own address instead of being
    // pinned to 7.0.108.0's specific $008DAC34 (an earlier, narrower version of this entry
    // -- just the 6-byte `mov edx,[$008DAC34]` with the address left as LITERAL match
    // bytes -- worked correctly for 7.0.108.0 but, being address-specific rather than
    // shape-specific, could never match any other build at all, silently leaving whatever
    // OLDER build's address the floor-matched milestone data already had in place instead
    // -- caught and fixed by testing this exact scenario against an unrelated newer client,
    // 7.0.117.0, that has no milestone of its own). AddOffset1=2 skips the fixed `8B 15`
    // opcode/ModRM to land on the first wildcarded 4-byte address; Mode 3 reads it back
    // out. Live-validated: resolves the already-known $008DAC34 on 7.0.108.0 (same
    // instruction, same address, unchanged), and independently corroborated (not just
    // "found a match") on 7.0.117.0 -- resolves $008DD434, a +$2A00 shift from
    // 7.0.108.0's value that exactly matches C_CONTPOS's own +$2A00 shift between these
    // same two builds, consistent with SYSMSG and CONTPOS sitting 0x24 bytes apart in the
    // same data segment, which shifted as one contiguous block.
    (Joker: $11; Unused: (0,0,0); AddOffset1: 2; Mode: 3; AddOffset2: 0;
     Expr: C_SYSMSG;
     Pattern: '8B15111111118BC23BC3C7442414400100008995D8000000899DDC000000740689A8DC000000899DE4000000892D11111111'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 2; Mode: 3; AddOffset2: 0; Expr: C_CLILOGGED; Pattern: '881D11111111891D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: -4; Mode: 3; AddOffset2: 0; Expr: C_CLIXRES; Pattern: '992BC2D1F8C3'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 3; AddOffset2: 0; Expr: C_ENEMYID; Pattern: '8B111100000039111111111175118B'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 5; Mode: 3; AddOffset2: 0; Expr: C_SHARDPOS; Pattern: '08885002B8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 7; Mode: 3; AddOffset2: 0; Expr: C_NEXTCPOS; Pattern: '406A0057518B0D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 3; AddOffset2: 0; Expr: C_CONTPOS; Pattern: '6A01C64673018B0D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: -4; Mode: 3; AddOffset2: 0; Expr: C_ENEMYHITS; Pattern: 'C780BC0000000200'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 7; Mode: 3; AddOffset2: -8; Expr: C_LHANDID; Pattern: '0FB74E3856890D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 1; Mode: 3; AddOffset2: 0; Expr: C_CHARDIR; Pattern: 'B9111111118944241C8379040075'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 6; Mode: 3; AddOffset2: 0; Expr: C_CURSORKIND; Pattern: '8A5424118815'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 11; Mode: 3; AddOffset2: 0; Expr: C_TARGETCURS; Pattern: '20578BF9837F7C007511A1'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 5; Mode: 3; AddOffset2: 0; Expr: C_CLILEFT; Pattern: '00895638A1'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 6; Mode: 3; AddOffset2: 0; Expr: C_CHARPTR; Pattern: '0FBF4E118B151111111103C10FBF4A1183C105'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 7; Mode: 3; AddOffset2: 0; Expr: C_LLIFTEDID; Pattern: '578B7C2408393D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 6; Mode: 3; AddOffset2: 0; Expr: C_LSHARD; Pattern: '0FB714418915'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 9; Mode: 3; AddOffset2: 0; Expr: C_POPUPID; Pattern: '008D4C24086A1351A3'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 2; Mode: 3; AddOffset2: 0; Expr: C_JOURNALPTR; Pattern: '8B15111111118BC28996'),
    // The scan-string file's PRIMARY {SKILLCAPS}/{SKILLLOCK}/{SKILLSPOS} pattern
    // ('33C0B91B000000BF11111111F3AB6A376A0068') did not match this client generation at
    // all; its own ALTERNATE line for each (below) did, and is what's validated/used here.
    (Joker: $11; Unused: (0,0,0); AddOffset1: 11; Mode: 3; AddOffset2: 0; Expr: C_SKILLCAPS; Pattern: '33C06A3A50B91D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 16; Mode: 3; AddOffset2: 0; Expr: C_SKILLLOCK; Pattern: '33C06A3A50B91D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 38; Mode: 3; AddOffset2: 0; Expr: C_SKILLSPOS; Pattern: '33C06A3A50B91D'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 5; Mode: 1; AddOffset2: 0; Expr: E_REDIR; Pattern: '33DB535350E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 6; Mode: 2; AddOffset2: 0; Expr: E_OLDDIR; Pattern: '33DB535350E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 11; Mode: 2; AddOffset2: 0; Expr: E_EXMSGADDR; Pattern: '50506A03506811111111E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 2; Mode: 3; AddOffset2: 0; Expr: E_ITEMPROPID; Pattern: '3B3D1111111175116A01E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 9; Mode: 2; AddOffset2: 0; Expr: E_ITEMNAMEADDR; Pattern: '558D4C2428518BCEE8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 9; Mode: 2; AddOffset2: 0; Expr: E_ITEMPROPADDR; Pattern: '558D542428528BCEE8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 2; AddOffset2: 0; Expr: E_ITEMCHECKADDR; Pattern: '85C074028BE855E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 2; AddOffset2: 0; Expr: E_ITEMREQADDR; Pattern: 'C40484C0740955E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 1; AddOffset2: 0; Expr: E_PATHFINDADDR; Pattern: '0FBF502653'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 3; AddOffset2: 0; Expr: E_SLEEPADDR; Pattern: '24044C000000FF25'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: -4; Mode: 2; AddOffset2: 0; Expr: E_DRAGADDR; Pattern: '83C408899ED4'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 2; AddOffset2: 0; Expr: E_SYSMSGADDR; Pattern: '6A0168B20300'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 8; Mode: 2; AddOffset2: 0; Expr: E_MACROADDR; Pattern: '15111111115152E81111111183C408'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 6; Mode: 2; AddOffset2: 0; Expr: E_SENDPACKET; Pattern: '8D4C243051E8'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 1; AddOffset2: 0; Expr: E_CONTTOP; Pattern: '83EC24578BF98B078B90'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: -30; Mode: 1; AddOffset2: 0; Expr: E_STATBAR; Pattern: '2064A3000000008BF9A1'),
    (Joker: $11; Unused: (0,0,0); AddOffset1: 0; Mode: 0; AddOffset2: 0; Expr: LISTEND; Pattern: nil)
  );

////////////////////////////////////////////////////////////////////////////////
constructor TCstDB.Create;
begin
  inherited Create;
  CS:=TMultiReadExclusiveWriteSynchronizer.Create;
  Update('');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDB.Free;
begin
  CS.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
// Two-pass lookup (see ExactMatchMilestoneIndex/FloorMilestoneIndex above for why two
// passes are needed rather than a single normalized-string floor lookup), then a
// cumulative apply of every milestone from the oldest up through the matched one -- the
// direct replacement for the old flat table's "zero all 87, then copy one version's full
// table in" (now: zero all 87, then apply N small deltas in oldest-to-newest order so
// later/newer deltas overwrite earlier/older ones for the same field, landing on the
// correct cumulative state). PHnd, when nonzero, additionally layers a live dynamic scan
// on top -- see ScanMemory below.
//
// All 4 of the original's behavioral cases are preserved:
//   CliVer=''                                            -> full reset (unchanged)
//   exact match on one of the 222 known strings           -> bit-identical resolution,
//                                                            proven by the unchanged
//                                                            golden-fixture test
//   non-empty, unknown, doesn't parse or floors below the
//     earliest milestone                                  -> Values left UNTOUCHED,
//                                                            reproducing
//                                                            TestUnrecognizedVersionString's
//                                                            hardcoded stale-value
//                                                            expectation exactly
//   non-empty, unknown, floors to a real milestone         -> NEW: resolves against the
//                                                            nearest applicable milestone
//                                                            (a genuinely new future
//                                                            client version) instead of
//                                                            being treated as unrecognized
procedure TCstDB.Update(CliVer : String; PHnd : Cardinal = 0);
var
  Lower   : String;
  MIdx    : Integer;
  NormVer : String;
  Cnt     : Integer;
  Cnt2    : Integer;
  Expr    : TConstantNames;
  Entry   : PSysVarListArray;
begin
  CS.BeginWrite;
  try
    if CliVer = '' then
    begin
      for Expr := Low(TConstantNames) to High(TConstantNames) do
        Values[Expr] := 0;
      Exit;
    end;

    Lower := LowerCase(CliVer);
    MIdx := ExactMatchMilestoneIndex(Lower);
    if MIdx = -1 then
    begin
      if not TryNormalizeVersion(CliVer, NormVer) then Exit;   // not version-shaped -> stale
      MIdx := FloorMilestoneIndex(NormVer);
      if MIdx = -1 then Exit;                                  // older than earliest -> stale
    end;

    for Expr := Low(TConstantNames) to High(TConstantNames) do
      Values[Expr] := 0;

    for Cnt := High(Milestones) downto MIdx do   // cumulative apply, oldest milestone first
    begin
      Entry := Milestones[Cnt].List;
      if Entry = nil then Continue;
      Cnt2 := -1;
      repeat
        Inc(Cnt2);
        if Entry^[Cnt2].Expr = LISTEND then Break;
        Values[Entry^[Cnt2].Expr] := Entry^[Cnt2].Val;
      until False;
    end;

    if PHnd <> 0 then
      ScanMemory(PHnd, Milestones[MIdx].NormVer);
  finally
    CS.EndWrite;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Signature-scans the attached live client's own memory (via common\access.pas's
// SearchMem/ReadMem -- the same primitive uoscanver.pas and tools\EUOUpdater already use)
// for the small set of VARIABLES/EVENTS fields whose absolute address genuinely differs
// per exact build. Results OVERWRITE whatever the milestone deltas already set for that
// field -- this is a refinement layered ON TOP of the milestone-resolved state, not a
// fallback only used when milestone data is missing. Called with the CS write lock
// already held (see Update above) -- deliberately NOT re-entering CS itself.
procedure TCstDB.ScanMemory(PHnd : Cardinal; const NormVer : String);
var
  Table  : ^TScannerEntry;
  HexPat : String;
  BinPat : String;
  P      : Integer;
  FoundPos, TargetVal, TempDWord : Cardinal;
begin
  if PHnd = 0 then Exit;
  if NormVer < Threshold_6062 then Table := @ScannerTable_Pre6062[0]
  else Table := @ScannerTable_Post6062[0];

  while Table^.Expr <> LISTEND do
  begin
    HexPat := String(Table^.Pattern);
    SetLength(BinPat, Length(HexPat) div 2);
    for P := 1 to Length(BinPat) do
      BinPat[P] := Char(StrToIntDef('$' + Copy(HexPat, (P-1)*2+1, 2), 0));

    FoundPos := SearchMem(PHnd, BinPat, Char(Table^.Joker));
    if FoundPos > 0 then
    begin
      TargetVal := FoundPos + Cardinal(Table^.AddOffset1);
      case Table^.Mode of
        2: begin
             TempDWord := 0;
             ReadMem(PHnd, TargetVal, @TempDWord, 4);
             TargetVal := TargetVal + TempDWord + 4;
           end;
        3: begin
             TempDWord := 0;
             ReadMem(PHnd, TargetVal, @TempDWord, 4);
             TargetVal := TempDWord;
           end;
      end;
      // Values is already keyed by TConstantNames -- a direct write IS the dispatch, no
      // case-of-Expr helper needed (unlike Gemini's SetFieldByExpr, which existed only
      // because that reference kept 82 individually-named fields instead of this array).
      Values[Table^.Expr] := TargetVal + Cardinal(Table^.AddOffset2);
    end;
    Inc(Table);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TCstDB.BLOCKINFO : Cardinal; begin CS.BeginRead; try Result:=Values[C_BLOCKINFO]; finally CS.EndRead; end; end;
function TCstDB.CLILOGGED : Cardinal; begin CS.BeginRead; try Result:=Values[C_CLILOGGED]; finally CS.EndRead; end; end;
function TCstDB.CLIXRES : Cardinal; begin CS.BeginRead; try Result:=Values[C_CLIXRES]; finally CS.EndRead; end; end;
function TCstDB.ENEMYID : Cardinal; begin CS.BeginRead; try Result:=Values[C_ENEMYID]; finally CS.EndRead; end; end;
function TCstDB.SHARDPOS : Cardinal; begin CS.BeginRead; try Result:=Values[C_SHARDPOS]; finally CS.EndRead; end; end;
function TCstDB.NEXTCPOS : Cardinal; begin CS.BeginRead; try Result:=Values[C_NEXTCPOS]; finally CS.EndRead; end; end;
function TCstDB.SYSMSG : Cardinal; begin CS.BeginRead; try Result:=Values[C_SYSMSG]; finally CS.EndRead; end; end;
function TCstDB.CONTPOS : Cardinal; begin CS.BeginRead; try Result:=Values[C_CONTPOS]; finally CS.EndRead; end; end;
function TCstDB.ENEMYHITS : Cardinal; begin CS.BeginRead; try Result:=Values[C_ENEMYHITS]; finally CS.EndRead; end; end;
function TCstDB.LHANDID : Cardinal; begin CS.BeginRead; try Result:=Values[C_LHANDID]; finally CS.EndRead; end; end;
function TCstDB.CHARDIR : Cardinal; begin CS.BeginRead; try Result:=Values[C_CHARDIR]; finally CS.EndRead; end; end;
function TCstDB.TARGETCNT : Cardinal; begin CS.BeginRead; try Result:=Values[C_TARGETCNT]; finally CS.EndRead; end; end;
function TCstDB.CURSORKIND : Cardinal; begin CS.BeginRead; try Result:=Values[C_CURSORKIND]; finally CS.EndRead; end; end;
function TCstDB.TARGETCURS : Cardinal; begin CS.BeginRead; try Result:=Values[C_TARGETCURS]; finally CS.EndRead; end; end;
function TCstDB.CLILEFT : Cardinal; begin CS.BeginRead; try Result:=Values[C_CLILEFT]; finally CS.EndRead; end; end;
function TCstDB.CHARPTR : Cardinal; begin CS.BeginRead; try Result:=Values[C_CHARPTR]; finally CS.EndRead; end; end;
function TCstDB.LLIFTEDID : Cardinal; begin CS.BeginRead; try Result:=Values[C_LLIFTEDID]; finally CS.EndRead; end; end;
function TCstDB.LSHARD : Cardinal; begin CS.BeginRead; try Result:=Values[C_LSHARD]; finally CS.EndRead; end; end;
function TCstDB.POPUPID : Cardinal; begin CS.BeginRead; try Result:=Values[C_POPUPID]; finally CS.EndRead; end; end;
function TCstDB.JOURNALPTR : Cardinal; begin CS.BeginRead; try Result:=Values[C_JOURNALPTR]; finally CS.EndRead; end; end;
function TCstDB.SKILLCAPS : Cardinal; begin CS.BeginRead; try Result:=Values[C_SKILLCAPS]; finally CS.EndRead; end; end;
function TCstDB.SKILLLOCK : Cardinal; begin CS.BeginRead; try Result:=Values[C_SKILLLOCK]; finally CS.EndRead; end; end;
function TCstDB.SKILLSPOS : Cardinal; begin CS.BeginRead; try Result:=Values[C_SKILLSPOS]; finally CS.EndRead; end; end;
////////////////////////////////////////////////////////////////////////////////
function TCstDB.BTARGPROC : Cardinal; begin CS.BeginRead; try Result:=Values[B_TARGPROC]; finally CS.EndRead; end; end;
function TCstDB.BCHARSTATUS : Cardinal; begin CS.BeginRead; try Result:=Values[B_CHARSTATUS]; finally CS.EndRead; end; end;
function TCstDB.BITEMID : Cardinal; begin CS.BeginRead; try Result:=Values[B_ITEMID]; finally CS.EndRead; end; end;
function TCstDB.BITEMTYPE : Cardinal; begin CS.BeginRead; try Result:=Values[B_ITEMTYPE]; finally CS.EndRead; end; end;
function TCstDB.BITEMSTACK : Cardinal; begin CS.BeginRead; try Result:=Values[B_ITEMSTACK]; finally CS.EndRead; end; end;
function TCstDB.BSTATNAME : Cardinal; begin CS.BeginRead; try Result:=Values[B_STATNAME]; finally CS.EndRead; end; end;
function TCstDB.BSTATWEIGHT : Cardinal; begin CS.BeginRead; try Result:=Values[B_STATWEIGHT]; finally CS.EndRead; end; end;
function TCstDB.BSTATAR : Cardinal; begin CS.BeginRead; try Result:=Values[B_STATAR]; finally CS.EndRead; end; end;
function TCstDB.BSTATML : Cardinal; begin CS.BeginRead; try Result:=Values[B_STATML]; finally CS.EndRead; end; end;
function TCstDB.BCONTSIZEX : Cardinal; begin CS.BeginRead; try Result:=Values[B_CONTSIZEX]; finally CS.EndRead; end; end;
function TCstDB.BCONTX : Cardinal; begin CS.BeginRead; try Result:=Values[B_CONTX]; finally CS.EndRead; end; end;
function TCstDB.BCONTITEM : Cardinal; begin CS.BeginRead; try Result:=Values[B_CONTITEM]; finally CS.EndRead; end; end;
function TCstDB.BCONTNEXT : Cardinal; begin CS.BeginRead; try Result:=Values[B_CONTNEXT]; finally CS.EndRead; end; end;
function TCstDB.BENEMYHPVAL : Cardinal; begin CS.BeginRead; try Result:=Values[B_ENEMYHPVAL]; finally CS.EndRead; end; end;
function TCstDB.BSHOPCURRENT : Cardinal; begin CS.BeginRead; try Result:=Values[B_SHOPCURRENT]; finally CS.EndRead; end; end;
function TCstDB.BSHOPNEXT : Cardinal; begin CS.BeginRead; try Result:=Values[B_SHOPNEXT]; finally CS.EndRead; end; end;
function TCstDB.BBILLFIRST : Cardinal; begin CS.BeginRead; try Result:=Values[B_BILLFIRST]; finally CS.EndRead; end; end;
function TCstDB.BSKILLDIST : Cardinal; begin CS.BeginRead; try Result:=Values[B_SKILLDIST]; finally CS.EndRead; end; end;
function TCstDB.BSYSMSGSTR : Cardinal; begin CS.BeginRead; try Result:=Values[B_SYSMSGSTR]; finally CS.EndRead; end; end;
function TCstDB.BEVSKILLPAR : Cardinal; begin CS.BeginRead; try Result:=Values[B_EVSKILLPAR]; finally CS.EndRead; end; end;
function TCstDB.BLLIFTEDTYPE : Cardinal; begin CS.BeginRead; try Result:=Values[B_LLIFTEDTYPE]; finally CS.EndRead; end; end;
function TCstDB.BLLIFTEDKIND : Cardinal; begin CS.BeginRead; try Result:=Values[B_LLIFTEDKIND]; finally CS.EndRead; end; end;
function TCstDB.BLANG : Cardinal; begin CS.BeginRead; try Result:=Values[B_LANG]; finally CS.EndRead; end; end;
function TCstDB.BTITHE : Cardinal; begin CS.BeginRead; try Result:=Values[B_TITHE]; finally CS.EndRead; end; end;
function TCstDB.BFINDREP : Cardinal; begin CS.BeginRead; try Result:=Values[B_FINDREP]; finally CS.EndRead; end; end;
function TCstDB.BSHOPPRICE : Cardinal; begin CS.BeginRead; try Result:=Values[B_SHOPPRICE]; finally CS.EndRead; end; end;
function TCstDB.BGUMPPTR : Cardinal; begin CS.BeginRead; try Result:=Values[B_GUMPPTR]; finally CS.EndRead; end; end;
function TCstDB.BITEMSLOT : Cardinal; begin CS.BeginRead; try Result:=Values[B_ITEMSLOT]; finally CS.EndRead; end; end;
function TCstDB.BMEMBASE : Cardinal; begin CS.BeginRead; try Result:=Values[B_MEMBASE]; finally CS.EndRead; end; end;
function TCstDB.BPACKETVER : Cardinal; begin CS.BeginRead; try Result:=Values[B_PACKETVER]; finally CS.EndRead; end; end;
function TCstDB.BLTARGTILE : Cardinal; begin CS.BeginRead; try Result:=Values[B_LTARGTILE]; finally CS.EndRead; end; end;
function TCstDB.BLTARGX : Cardinal; begin CS.BeginRead; try Result:=Values[B_LTARGX]; finally CS.EndRead; end; end;
function TCstDB.BSTAT1 : Cardinal; begin CS.BeginRead; try Result:=Values[B_STAT1]; finally CS.EndRead; end; end;
function TCstDB.BJCOL : Cardinal; begin CS.BeginRead; try Result:=Values[B_JCOL]; finally CS.EndRead; end; end;
function TCstDB.BJKIND : Cardinal; begin CS.BeginRead; try Result:=Values[B_JKIND]; finally CS.EndRead; end; end;
function TCstDB.BJNEXTPTR : Cardinal; begin CS.BeginRead; try Result:=Values[B_JNEXTPTR]; finally CS.EndRead; end; end;
////////////////////////////////////////////////////////////////////////////////
function TCstDB.EREDIR : Cardinal; begin CS.BeginRead; try Result:=Values[E_REDIR]; finally CS.EndRead; end; end;
function TCstDB.EOLDDIR : Cardinal; begin CS.BeginRead; try Result:=Values[E_OLDDIR]; finally CS.EndRead; end; end;
function TCstDB.EEXMSGADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_EXMSGADDR]; finally CS.EndRead; end; end;
function TCstDB.EITEMPROPID : Cardinal; begin CS.BeginRead; try Result:=Values[E_ITEMPROPID]; finally CS.EndRead; end; end;
function TCstDB.EITEMNAMEADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_ITEMNAMEADDR]; finally CS.EndRead; end; end;
function TCstDB.EITEMPROPADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_ITEMPROPADDR]; finally CS.EndRead; end; end;
function TCstDB.EITEMCHECKADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_ITEMCHECKADDR]; finally CS.EndRead; end; end;
function TCstDB.EITEMREQADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_ITEMREQADDR]; finally CS.EndRead; end; end;
function TCstDB.EPATHFINDADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_PATHFINDADDR]; finally CS.EndRead; end; end;
function TCstDB.ESLEEPADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_SLEEPADDR]; finally CS.EndRead; end; end;
function TCstDB.EDRAGADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_DRAGADDR]; finally CS.EndRead; end; end;
function TCstDB.ESYSMSGADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_SYSMSGADDR]; finally CS.EndRead; end; end;
function TCstDB.EMACROADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_MACROADDR]; finally CS.EndRead; end; end;
function TCstDB.ESKILLLOCKADDR : Cardinal; begin CS.BeginRead; try Result:=Values[E_SKILLLOCKADDR]; finally CS.EndRead; end; end;
function TCstDB.ESENDPACKET : Cardinal; begin CS.BeginRead; try Result:=Values[E_SENDPACKET]; finally CS.EndRead; end; end;
function TCstDB.ESENDLEN : Cardinal; begin CS.BeginRead; try Result:=Values[E_SENDLEN]; finally CS.EndRead; end; end;
function TCstDB.ESENDECX : Cardinal; begin CS.BeginRead; try Result:=Values[E_SENDECX]; finally CS.EndRead; end; end;
function TCstDB.ECONTTOP : Cardinal; begin CS.BeginRead; try Result:=Values[E_CONTTOP]; finally CS.EndRead; end; end;
function TCstDB.ESTATBAR : Cardinal; begin CS.BeginRead; try Result:=Values[E_STATBAR]; finally CS.EndRead; end; end;
////////////////////////////////////////////////////////////////////////////////
function TCstDB.FEXTSTAT : Cardinal; begin CS.BeginRead; try Result:=Values[F_EXTSTAT]; finally CS.EndRead; end; end;
function TCstDB.FEVPROPERTY : Cardinal; begin CS.BeginRead; try Result:=Values[F_EVPROPERTY]; finally CS.EndRead; end; end;
function TCstDB.FMACROMAP : Cardinal; begin CS.BeginRead; try Result:=Values[F_MACROMAP]; finally CS.EndRead; end; end;
function TCstDB.FEXCHARSTATC : Cardinal; begin CS.BeginRead; try Result:=Values[F_EXCHARSTATC]; finally CS.EndRead; end; end;
function TCstDB.FPACKETVER : Cardinal; begin CS.BeginRead; try Result:=Values[F_PACKETVER]; finally CS.EndRead; end; end;
function TCstDB.FPATHFINDVER : Cardinal; begin CS.BeginRead; try Result:=Values[F_PATHFINDVER]; finally CS.EndRead; end; end;
function TCstDB.FFLAGS : Cardinal; begin CS.BeginRead; try Result:=Values[F_FLAGS]; finally CS.EndRead; end; end;
function TCstDB.FSYSMSGDIRECT : Cardinal; begin CS.BeginRead; try Result:=Values[F_SYSMSGDIRECT]; finally CS.EndRead; end; end;
function TCstDB.FJOURNALDIRECT : Cardinal; begin CS.BeginRead; try Result:=Values[F_JOURNALDIRECT]; finally CS.EndRead; end; end;

end.
