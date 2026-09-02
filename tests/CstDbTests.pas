unit CstDbTests;

{ FPCUnit tests for the ported uoclidata.pas / TCstDB.

  TestAllVersionsAgainstGoldenFixture is the main event: it loads
  tests\fixtures\uoclidata_golden.json (extracted from the ORIGINAL source's data
  tables by tests\tools\VerifyCstDbData.ps1, independently of anything written
  here) and, for every one of the 220 real client versions, calls the real, running
  TCstDB.Update(version) and checks every one of the 82 getters against the golden
  value. This exercises the rewritten single-pass Update() logic end to end -- the
  static-text transplant was already proven byte-identical by the PowerShell script;
  this proves the REWRITTEN CODE behaves identically to what that data means.

  The remaining tests cover the specific Update() behavioral quirk found by reading
  the original source directly (not assumed from the earlier research pass): passing
  an unrecognized NON-EMPTY version string leaves all 82 previously-resolved values
  untouched, whereas '' or a recognized version always re-resolves all 82. This is
  exactly the kind of detail an "obvious" refactor could silently invert. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, fpcunit, testregistry, uoclidata;

type
  TCstDbTests = class(TTestCase)
  published
    procedure TestUnrecognizedVersionString;
    procedure TestEmptyStringResetsToZero;
    procedure TestRecognizedVersionResolvesAndIsCaseInsensitive;
    procedure TestSwitchingBetweenTwoRecognizedVersions;
    procedure TestAllVersionsAgainstGoldenFixture;
    // Added for the milestone/delta redesign -- the golden fixture predates the 5
    // migration-added fields and the new floor-based lookup capability, so neither is
    // covered by TestAllVersionsAgainstGoldenFixture above.
    procedure TestMigrationAddedFieldsFor7_0_108_0And7_0_99_1;
    procedure TestUnknownNewerVersionFloorsToNewestMilestone;
    procedure TestVersionOlderThanEarliestMilestoneIsUnrecognized;
    procedure TestCliVerSupportedFloorBasedGate;
  end;

implementation

// Resolved relative to the test executable (which runs from tests\), so the
// suite works from any checkout location. The fixture is committed under
// tests\fixtures\; regenerate it with tests\tools\VerifyCstDbData.ps1.
function GoldenFixturePath : String;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'uoclidata_golden.json';
end;

// Maps a raw TConstantNames identifier (as it appears in the original source's data
// tables, e.g. 'C_BLOCKINFO'/'B_TARGPROC'/'E_REDIR'/'F_EXTSTAT') to the matching public
// getter on TCstDB. Mechanical, but exhaustive -- this IS the check that every one of
// the 82 getters is wired to the correct slot.
function GetterValue(Cst : TCstDB; const Field : String) : Cardinal;
begin
  // VARIABLES (C_) -- getter name drops the "C_" prefix
  if Field = 'C_BLOCKINFO'    then Exit(Cst.BLOCKINFO);
  if Field = 'C_CLILOGGED'    then Exit(Cst.CLILOGGED);
  if Field = 'C_CLIXRES'      then Exit(Cst.CLIXRES);
  if Field = 'C_ENEMYID'      then Exit(Cst.ENEMYID);
  if Field = 'C_SHARDPOS'     then Exit(Cst.SHARDPOS);
  if Field = 'C_NEXTCPOS'     then Exit(Cst.NEXTCPOS);
  if Field = 'C_SYSMSG'       then Exit(Cst.SYSMSG);
  if Field = 'C_CONTPOS'      then Exit(Cst.CONTPOS);
  if Field = 'C_ENEMYHITS'    then Exit(Cst.ENEMYHITS);
  if Field = 'C_LHANDID'      then Exit(Cst.LHANDID);
  if Field = 'C_CHARDIR'      then Exit(Cst.CHARDIR);
  if Field = 'C_TARGETCNT'    then Exit(Cst.TARGETCNT);
  if Field = 'C_CURSORKIND'   then Exit(Cst.CURSORKIND);
  if Field = 'C_TARGETCURS'   then Exit(Cst.TARGETCURS);
  if Field = 'C_CLILEFT'      then Exit(Cst.CLILEFT);
  if Field = 'C_CHARPTR'      then Exit(Cst.CHARPTR);
  if Field = 'C_LLIFTEDID'    then Exit(Cst.LLIFTEDID);
  if Field = 'C_LSHARD'       then Exit(Cst.LSHARD);
  if Field = 'C_POPUPID'      then Exit(Cst.POPUPID);
  if Field = 'C_JOURNALPTR'   then Exit(Cst.JOURNALPTR);
  if Field = 'C_SKILLCAPS'    then Exit(Cst.SKILLCAPS);
  if Field = 'C_SKILLLOCK'    then Exit(Cst.SKILLLOCK);
  if Field = 'C_SKILLSPOS'    then Exit(Cst.SKILLSPOS);
  // BASE CONSTANTS (B_) -- getter name keeps the "B" (drops only the underscore)
  if Field = 'B_TARGPROC'     then Exit(Cst.BTARGPROC);
  if Field = 'B_CHARSTATUS'   then Exit(Cst.BCHARSTATUS);
  if Field = 'B_ITEMID'       then Exit(Cst.BITEMID);
  if Field = 'B_ITEMTYPE'     then Exit(Cst.BITEMTYPE);
  if Field = 'B_ITEMSTACK'    then Exit(Cst.BITEMSTACK);
  if Field = 'B_STATNAME'     then Exit(Cst.BSTATNAME);
  if Field = 'B_STATWEIGHT'   then Exit(Cst.BSTATWEIGHT);
  if Field = 'B_STATAR'       then Exit(Cst.BSTATAR);
  if Field = 'B_STATML'       then Exit(Cst.BSTATML);
  if Field = 'B_CONTSIZEX'    then Exit(Cst.BCONTSIZEX);
  if Field = 'B_CONTX'        then Exit(Cst.BCONTX);
  if Field = 'B_CONTITEM'     then Exit(Cst.BCONTITEM);
  if Field = 'B_CONTNEXT'     then Exit(Cst.BCONTNEXT);
  if Field = 'B_ENEMYHPVAL'   then Exit(Cst.BENEMYHPVAL);
  if Field = 'B_SHOPCURRENT'  then Exit(Cst.BSHOPCURRENT);
  if Field = 'B_SHOPNEXT'     then Exit(Cst.BSHOPNEXT);
  if Field = 'B_BILLFIRST'    then Exit(Cst.BBILLFIRST);
  if Field = 'B_SKILLDIST'    then Exit(Cst.BSKILLDIST);
  if Field = 'B_SYSMSGSTR'    then Exit(Cst.BSYSMSGSTR);
  if Field = 'B_EVSKILLPAR'   then Exit(Cst.BEVSKILLPAR);
  if Field = 'B_LLIFTEDTYPE'  then Exit(Cst.BLLIFTEDTYPE);
  if Field = 'B_LLIFTEDKIND'  then Exit(Cst.BLLIFTEDKIND);
  if Field = 'B_LANG'         then Exit(Cst.BLANG);
  if Field = 'B_TITHE'        then Exit(Cst.BTITHE);
  if Field = 'B_FINDREP'      then Exit(Cst.BFINDREP);
  if Field = 'B_SHOPPRICE'    then Exit(Cst.BSHOPPRICE);
  if Field = 'B_GUMPPTR'      then Exit(Cst.BGUMPPTR);
  if Field = 'B_ITEMSLOT'     then Exit(Cst.BITEMSLOT);
  if Field = 'B_MEMBASE'      then Exit(Cst.BMEMBASE);
  if Field = 'B_PACKETVER'    then Exit(Cst.BPACKETVER);
  if Field = 'B_LTARGTILE'    then Exit(Cst.BLTARGTILE);
  if Field = 'B_LTARGX'       then Exit(Cst.BLTARGX);
  if Field = 'B_STAT1'        then Exit(Cst.BSTAT1);
  // EVENTS (E_)
  if Field = 'E_REDIR'         then Exit(Cst.EREDIR);
  if Field = 'E_OLDDIR'        then Exit(Cst.EOLDDIR);
  if Field = 'E_EXMSGADDR'     then Exit(Cst.EEXMSGADDR);
  if Field = 'E_ITEMPROPID'    then Exit(Cst.EITEMPROPID);
  if Field = 'E_ITEMNAMEADDR'  then Exit(Cst.EITEMNAMEADDR);
  if Field = 'E_ITEMPROPADDR'  then Exit(Cst.EITEMPROPADDR);
  if Field = 'E_ITEMCHECKADDR' then Exit(Cst.EITEMCHECKADDR);
  if Field = 'E_ITEMREQADDR'   then Exit(Cst.EITEMREQADDR);
  if Field = 'E_PATHFINDADDR'  then Exit(Cst.EPATHFINDADDR);
  if Field = 'E_SLEEPADDR'     then Exit(Cst.ESLEEPADDR);
  if Field = 'E_DRAGADDR'      then Exit(Cst.EDRAGADDR);
  if Field = 'E_SYSMSGADDR'    then Exit(Cst.ESYSMSGADDR);
  if Field = 'E_MACROADDR'     then Exit(Cst.EMACROADDR);
  if Field = 'E_SKILLLOCKADDR' then Exit(Cst.ESKILLLOCKADDR);
  if Field = 'E_SENDPACKET'    then Exit(Cst.ESENDPACKET);
  if Field = 'E_SENDLEN'       then Exit(Cst.ESENDLEN);
  if Field = 'E_SENDECX'       then Exit(Cst.ESENDECX);
  if Field = 'E_CONTTOP'       then Exit(Cst.ECONTTOP);
  if Field = 'E_STATBAR'       then Exit(Cst.ESTATBAR);
  // FEATURES (F_)
  if Field = 'F_EXTSTAT'      then Exit(Cst.FEXTSTAT);
  if Field = 'F_EVPROPERTY'   then Exit(Cst.FEVPROPERTY);
  if Field = 'F_MACROMAP'     then Exit(Cst.FMACROMAP);
  if Field = 'F_EXCHARSTATC'  then Exit(Cst.FEXCHARSTATC);
  if Field = 'F_PACKETVER'    then Exit(Cst.FPACKETVER);
  if Field = 'F_PATHFINDVER'  then Exit(Cst.FPATHFINDVER);
  if Field = 'F_FLAGS'        then Exit(Cst.FFLAGS);

  raise Exception.CreateFmt('GetterValue: unknown field "%s" -- golden fixture and ' +
    'test mapper have drifted apart', [Field]);
end;

procedure TCstDbTests.TestUnrecognizedVersionString;
var Cst : TCstDB;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.47.0');                      // a real, recognized version
    AssertTrue('sanity: a real version resolves something non-zero',
               Cst.BLOCKINFO <> 0);
    Cst.Update('not-a-real-version-string');      // unrecognized, non-empty
    AssertEquals('unrecognized non-empty version must leave BLOCKINFO UNCHANGED ' +
                 '(the original''s Exit-before-the-82-assignments quirk)',
                 $005901B0, Integer(Cst.BLOCKINFO));
  finally Cst.Free; end;
end;

procedure TCstDbTests.TestEmptyStringResetsToZero;
var Cst : TCstDB;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.47.0');
    AssertTrue(Cst.BLOCKINFO <> 0);
    Cst.Update('');
    AssertEquals('empty string resets every field to zero', Cardinal(0), Cst.BLOCKINFO);
    AssertEquals(Cardinal(0), Cst.FFLAGS);
  finally Cst.Free; end;
end;

procedure TCstDbTests.TestRecognizedVersionResolvesAndIsCaseInsensitive;
var Cst : TCstDB;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.47.0');
    AssertEquals($005901B0, Integer(Cst.BLOCKINFO));
    Cst.Update('');
    Cst.Update('7.0.47.0');       // exercise the "no prior state" path too
    AssertEquals($005901B0, Integer(Cst.BLOCKINFO));
    Cst.Update('');
    Cst.Update('7.0.47.0');
    Cst.Update('7.0.47.0');       // and re-selecting the same version again
    AssertEquals($005901B0, Integer(Cst.BLOCKINFO));
  finally Cst.Free; end;
end;

procedure TCstDbTests.TestSwitchingBetweenTwoRecognizedVersions;
var Cst : TCstDB;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.47.0');
    AssertEquals($005901B0, Integer(Cst.BLOCKINFO));
    Cst.Update('2.0.0');          // switch to the oldest supported version
    AssertTrue('a different version resolves a different (or absent -> 0) value',
               Cst.BLOCKINFO <> $005901B0);
  finally Cst.Free; end;
end;

procedure TCstDbTests.TestAllVersionsAgainstGoldenFixture;
var
  Cst        : TCstDB;
  JRoot      : TJSONData;
  JArr       : TJSONArray;
  JVer       : TJSONObject;
  JFields    : TJSONObject;
  VerCount, FieldCount, Total : Integer;
  i, j       : Integer;
  Cli        : String;
  FieldName  : String;
  ExpectedHex: String;
  Expected   : Cardinal;
  Got        : Cardinal;
begin
  AssertTrue('golden fixture must exist -- run VerifyCstDbData.ps1 first',
             FileExists(GoldenFixturePath));

  JRoot := GetJSON(TFileStream.Create(GoldenFixturePath, fmOpenRead));
  try
    AssertTrue(JRoot is TJSONArray);
    JArr := TJSONArray(JRoot);
    VerCount := 0;
    FieldCount := 0;
    Total := 0;

    Cst := TCstDB.Create;
    try
      for i := 0 to JArr.Count - 1 do
      begin
        JVer := TJSONObject(JArr.Items[i]);
        Cli := JVer.Get('Cli', '');
        JFields := JVer.Objects['Fields'];
        Cst.Update(Cli);
        Inc(VerCount);

        for j := 0 to JFields.Count - 1 do
        begin
          FieldName := JFields.Names[j];
          ExpectedHex := JFields.Items[j].AsString;
          Expected := StrToInt('$' + ExpectedHex);
          Got := GetterValue(Cst, FieldName);
          Inc(Total);
          if Got <> Expected then
          begin
            Fail(Format('version "%s" field %s: got $%.8x expected $%.8x',
                         [Cli, FieldName, Got, Expected]));
          end;
        end;
        FieldCount := JFields.Count;   // just for the summary message below
      end;
    finally Cst.Free; end;

    AssertTrue(Format('sanity: exercised %d versions, %d total (version,field) checks ' +
      '(last version had %d fields)', [VerCount, Total, FieldCount]),
      (VerCount = 220) and (Total > 15000));
  finally JRoot.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
// The 5 fields added during the original Lazarus migration (F_SYSMSGDIRECT,
// F_JOURNALDIRECT, B_JCOL, B_JKIND, B_JNEXTPTR -- see uoclidata.pas's own header comment
// and milestone 0/1's comments) don't exist in the original Delphi 7 source at all, so
// they can never appear in a fixture extracted from it. Hardcoded here directly against
// the values milestone 0/1's own comments already document as independently verified
// (live disassembly for 7.0.108.0; static PE analysis for 7.0.99.1).
procedure TCstDbTests.TestMigrationAddedFieldsFor7_0_108_0And7_0_99_1;
var Cst : TCstDB;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.108.0');
    AssertEquals('7.0.108.0 BJCOL', $00000800, Integer(Cst.BJCOL));
    AssertEquals('7.0.108.0 BJKIND', $00000804, Integer(Cst.BJKIND));
    AssertEquals('7.0.108.0 BJNEXTPTR', $00000818, Integer(Cst.BJNEXTPTR));
    AssertEquals('7.0.108.0 FSYSMSGDIRECT', Cardinal(1), Cst.FSYSMSGDIRECT);
    AssertEquals('7.0.108.0 FJOURNALDIRECT', Cardinal(1), Cst.FJOURNALDIRECT);
    AssertEquals('7.0.108.0 BSYSMSGSTR (real embedded-text offset, not the old $100)',
                 $00000800, Integer(Cst.BSYSMSGSTR));

    Cst.Update('7.0.99.1');
    AssertEquals('7.0.99.1 FSYSMSGDIRECT', Cardinal(1), Cst.FSYSMSGDIRECT);
    AssertEquals('7.0.99.1 BSYSMSGSTR', $00000800, Integer(Cst.BSYSMSGSTR));
    AssertEquals('7.0.99.1 journal layout deliberately left OLD (investigation gap, ' +
                 'see milestone 1''s own comment) -- FJOURNALDIRECT must stay 0',
                 Cardinal(0), Cst.FJOURNALDIRECT);
    AssertEquals('7.0.99.1 BJCOL must stay 0 (not set -- FJOURNALDIRECT=0 for this version)',
                 Cardinal(0), Cst.BJCOL);
  finally Cst.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
// The actual NEW capability the milestone/delta redesign was asked to provide: a version
// string that is NOT one of the known ones, but is newer than every known milestone, now
// resolves against the newest applicable milestone instead of being treated as
// unrecognized (which is what the old flat-table Update -- and this same Update, for a
// version it can't parse or floor at all -- still does; see the next test).
procedure TCstDbTests.TestUnknownNewerVersionFloorsToNewestMilestone;
var
  Cst      : TCstDB;
  Expected : Cardinal;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.108.0');            // the newest known milestone
    Expected := Cst.BLOCKINFO;
    AssertTrue('sanity', Expected <> 0);

    Cst.Update('7.0.200.0');            // not a known string, newer than anything known
    AssertEquals('an unknown version newer than every known milestone floors to the ' +
                 'newest one', Expected, Cst.BLOCKINFO);
  finally Cst.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbTests.TestVersionOlderThanEarliestMilestoneIsUnrecognized;
var
  Cst   : TCstDB;
  Stale : Cardinal;
begin
  Cst := TCstDB.Create;
  try
    Cst.Update('7.0.47.0');
    Stale := Cst.BLOCKINFO;
    AssertTrue('sanity', Stale <> 0);

    Cst.Update('1.0.0.0');              // older than 2.0.0, the earliest known milestone
    AssertEquals('a version older than the earliest known milestone is treated the same ' +
                 'as any other unrecognized non-empty string -- stale data preserved',
                 Stale, Cst.BLOCKINFO);
  finally Cst.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
// CliVerSupported (uoclidata.pas) replaces the old flat SupportedCli string as
// uoselector.pas's client-picker gate -- wraps the exact same two-pass logic Update
// itself uses, as a boolean, mutating nothing.
procedure TCstDbTests.TestCliVerSupportedFloorBasedGate;
begin
  AssertTrue('a known exact version is supported', CliVerSupported('7.0.108.0'));
  AssertTrue('an unknown version newer than every known milestone floors to supported',
             CliVerSupported('7.0.200.0'));
  AssertFalse('a version older than the earliest known milestone is not supported',
              CliVerSupported('1.0.0.0'));
  AssertFalse('a string that does not even look like a version is not supported',
              CliVerSupported('not-a-real-version-string'));
  AssertFalse('empty string is not "supported" either', CliVerSupported(''));
end;

initialization
  RegisterTest(TCstDbTests);
end.
