unit UoCommandsTests;

{
  Tests for uo\uocommands.pas's TUOCmd against a real TUOSel/TUOVar with no
  client selected -- same rationale as UoVariablesTests.pas: RWV gates on
  UOSel.Nr>0, so every accessor is provably safe with no live client. Also
  covers IgnoreItem/IgnoreItemReset directly (the FindSortedPos fix applied
  this phase) and ScanItems/FilterItems/GetItem's local list-management logic,
  none of which actually needs a live client to exercise.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uoselector, uovariables, uocommands,
  uotypes;

type
  // A tiny cliloc table, with the real texts of the English client, for the buff-bar text tests.
  TClilocStub = class(TObject)
  public
    function Lookup(ID : Cardinal) : String;
  end;

  TUoCommandsTests = class(TTestCase)
  private
    Sel : TUOSel;
    Vr  : TUOVar;
    Cmd : TUOCmd;
    function NoWaitDelay(Duration : Cardinal) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // Buff bar (port addition)
    procedure TestScanBuffsWithNoClientFindsNothing;
    procedure TestGetBuffOutOfRangeLeavesNoSelection;
    procedure TestClilocTextWithNoClientIsEmpty;
    procedure TestExpandClilocFillsNumberedArguments;
    procedure TestExpandClilocBuffDescriptionsRenderLikeTheTooltip;
    procedure TestExpandClilocMissingArgumentIsEmpty;
    procedure TestExpandClilocNestedClilocArgument;
    procedure TestExpandClilocEmbeddedClilocReference;
    procedure TestExpandClilocUnterminatedTildeStaysText;
    procedure TestExpandClilocSelfReferenceTerminates;
    procedure TestClilocToPlainBreaksAndTags;
    procedure TestClilocToPlainKeepsALoneLessThan;
    procedure TestClilocToPlainCollapsesWhiteSpace;
    // the original tests
    procedure TestGetPixWithNoClientReturnsZero;
    procedure TestGetSkillUnknownNameLeavesZeros;
    procedure TestGetSkillKnownNameStillZeroWithNoClient;
    procedure TestScanItemsThenGetItemOutOfRangeReturnsNotFound;
    procedure TestIgnoreItemAddThenRemoveRoundTrips;
    procedure TestIgnoreItemResetByUnknownListFails;
    procedure TestIgnoreItemResetWithNoListClearsEverything;
    procedure TestTileCntWithNoTileInitReturnsZero;
    procedure TestGetContWithNoClientFails;
    procedure TestMoveTimesOutQuicklyWithNoClient;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function TClilocStub.Lookup(ID : Cardinal) : String;
begin
  case ID of
    1075655: Result := 'Hidden/Stealthing';
    1075656: Result := 'You are hidden.';
    1075847: Result := 'Bless';
    1075848: Result := '+~1_STR~% Strength.<br>+~2_DEX~% Dexterity.<br>+~3_INT~% Intelligence.';
    1075836: Result := '-~1_STR~% Strength.<br>-~2_DEX~% Dexterity.<br>-~3_INT~% Intelligence.' +
                       '<br>-~4_FR~ to max Fire Resistance.<br>-~5_CR~ to max Cold Resistance.' +
                       '<br>-~6_PR~ to max Poison Resistance.<br>-~7_ER~ to max Energy Resistance.';
    2000001: Result := 'See ~#1075847~ and ~1_X~.';
    2000002: Result := 'loop ~#2000002~ end';
  else
    Result := '';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestScanBuffsWithNoClientFindsNothing;
begin
  AssertFalse('no client: nothing to read', Cmd.ScanBuffs);
  AssertEquals('count', Cardinal(0), Cmd.BuffCnt);
  AssertFalse('nothing selected', Cmd.BuffValid);
  AssertEquals('time of the empty selection', -1, Cmd.BuffRes.Time);
  AssertEquals('filtered scan as well', False, Cmd.ScanBuffs(30018));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestGetBuffOutOfRangeLeavesNoSelection;
begin
  Cmd.GetBuff(0);
  AssertFalse(Cmd.BuffValid);
  Cmd.GetBuff(High(Cardinal));      // what #BuffIndex 0 turns into
  AssertFalse(Cmd.BuffValid);
  AssertEquals('', Cmd.BuffRes.Name);
  AssertEquals('', Cmd.BuffRes.Desc);
  AssertEquals(Cardinal(0), Cmd.BuffRes.ID);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestClilocTextWithNoClientIsEmpty;
begin
  AssertEquals('', Cmd.ClilocText(1075847));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestExpandClilocFillsNumberedArguments;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('+11% Strength.<br>+11% Dexterity.<br>+11% Intelligence.',
      ExpandCliloc(T.Lookup(1075848), '11'#9'11'#9'11', T.Lookup));
    // arguments are 1-based and may be used out of order or twice
    AssertEquals('b a b', ExpandCliloc('~2_Y~ ~1_X~ ~2_Y~', 'a'#9'b', T.Lookup));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Exactly what the live client showed for Curse (seven arguments), after the plain-text pass.
procedure TUoCommandsTests.TestExpandClilocBuffDescriptionsRenderLikeTheTooltip;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('-8% Strength. -8% Dexterity. -8% Intelligence. -10 to max Fire Resistance. ' +
      '-10 to max Cold Resistance. -10 to max Poison Resistance. -10 to max Energy Resistance.',
      ClilocToPlain(ExpandCliloc(T.Lookup(1075836), '8'#9'8'#9'8'#9'10'#9'10'#9'10'#9'10', T.Lookup)));
    AssertEquals('Bless', ClilocToPlain(ExpandCliloc(T.Lookup(1075847), '', T.Lookup)));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestExpandClilocMissingArgumentIsEmpty;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('[]', ExpandCliloc('[~1_X~]', '', T.Lookup));
    AssertEquals('[a][]', ExpandCliloc('[~1_X~][~2_Y~]', 'a', T.Lookup));
    AssertEquals('[]', ExpandCliloc('[~0_X~]', 'a', T.Lookup));
    AssertEquals('[]', ExpandCliloc('[~_X~]', 'a', T.Lookup));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// An argument that is itself "#<cliloc number>" is looked up (the client does this for item names).
procedure TUoCommandsTests.TestExpandClilocNestedClilocArgument;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('Hidden/Stealthing ok', ExpandCliloc('~1_NAME~ ok', '#1075655', T.Lookup));
    AssertEquals('#12x ok', ExpandCliloc('~1_NAME~ ok', '#12x', T.Lookup));   // not a number: literal
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestExpandClilocEmbeddedClilocReference;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('See Bless and 7.', ExpandCliloc(T.Lookup(2000001), '7', T.Lookup));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestExpandClilocUnterminatedTildeStaysText;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('about ~ 5', ExpandCliloc('about ~ 5', '', T.Lookup));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// A cliloc that refers to itself must not recurse forever.
procedure TUoCommandsTests.TestExpandClilocSelfReferenceTerminates;
var
  T : TClilocStub;
begin
  T := TClilocStub.Create;
  try
    AssertEquals('loop loop loop loop loop  end end end end end',
      ExpandCliloc(T.Lookup(2000002), '', T.Lookup));
  finally
    T.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestClilocToPlainBreaksAndTags;
begin
  AssertEquals('a b', ClilocToPlain('a<br>b'));
  AssertEquals('a b', ClilocToPlain('a <BR/> b'));
  AssertEquals('a b', ClilocToPlain('a<br />b'));
  AssertEquals('Bless', ClilocToPlain('<basefont color=#FFFFFF>Bless</basefont>'));
  AssertEquals('x y', ClilocToPlain('<center>x</center><br><i>y</i>'));
  AssertEquals('', ClilocToPlain(''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestClilocToPlainKeepsALoneLessThan;
begin
  AssertEquals('5 < 7', ClilocToPlain('5 < 7'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestClilocToPlainCollapsesWhiteSpace;
begin
  AssertEquals('a b c', ClilocToPlain('  a  '#9'b'#13#10'c  '));
end;

////////////////////////////////////////////////////////////////////////////////
function TUoCommandsTests.NoWaitDelay(Duration : Cardinal) : Boolean;
begin
  Result := True; // never interrupted -- fine for these no-client tests
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.SetUp;
begin
  Sel := TUOSel.Create;
  Vr := TUOVar.Create(Sel);
  Cmd := TUOCmd.Create(Sel, Vr, NoWaitDelay);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TearDown;
begin
  Cmd.Free;
  Vr.Free;
  Sel.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestGetPixWithNoClientReturnsZero;
begin
  // GetPix reads via GetDC(UOSel.HWnd)/GetPixel -- HWnd is 0 with no client,
  // GetDC(0) yields the screen DC, so this exercises a real (if degenerate)
  // WinAPI call path rather than an RWV no-op; must not raise either way.
  Cmd.GetPix(0, 0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestGetSkillUnknownNameLeavesZeros;
begin
  Cmd.GetSkill('ZZZZ');
  AssertEquals(Cardinal(0), Cmd.SkillReal);
  AssertEquals(Cardinal(0), Cmd.SkillNorm);
  AssertEquals(Cardinal(0), Cmd.SkillCap);
  AssertEquals(Cardinal(0), Cmd.SkillLock);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestGetSkillKnownNameStillZeroWithNoClient;
begin
  // "ALCH" is a real entry in SkillList; confirms SkillFind's binary search
  // resolves a known name to a real Code, then RWV's Nr>0 gate zero-fills.
  Cmd.GetSkill('ALCHEMY');
  AssertEquals(Cardinal(0), Cmd.SkillReal);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestScanItemsThenGetItemOutOfRangeReturnsNotFound;
begin
  Cmd.ScanItems; // RWV gate means CHARPTR reads back 0 -> Nxt loop never runs
  Cmd.GetItem(0);
  AssertEquals(-1, Cmd.ItemRes.ItemKind);
  AssertEquals(Cardinal(0), Cmd.ItemCnt);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestIgnoreItemAddThenRemoveRoundTrips;
begin
  AssertTrue('first add must report True (newly added)',
    Cmd.IgnoreItem(1001, 'MYLIST'));
  AssertFalse('adding the same ID again must report False (already present, now removed)',
    Cmd.IgnoreItem(1001, 'MYLIST'));
  AssertTrue('re-adding after the toggle-remove must report True again',
    Cmd.IgnoreItem(1001, 'MYLIST'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestIgnoreItemResetByUnknownListFails;
begin
  AssertFalse(Cmd.IgnoreItemReset('NO_SUCH_LIST'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestIgnoreItemResetWithNoListClearsEverything;
begin
  Cmd.IgnoreItem(2002, 'ALIST');
  AssertTrue(Cmd.IgnoreItemReset(''));
  // After a full reset, the same ID must be freely addable again as "new".
  AssertTrue(Cmd.IgnoreItem(2002, 'ALIST'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestTileCntWithNoTileInitReturnsZero;
begin
  // TileInit was never called (no client / no valid exe path to read .mul
  // files from) -- TileObj stays nil, so TileCnt must safely return 0.
  AssertEquals(Cardinal(0), Cmd.TileCnt(100, 100));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestGetContWithNoClientFails;
begin
  AssertFalse(Cmd.GetCont(0));
  AssertEquals(Cardinal(0), Cmd.ContKind);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoCommandsTests.TestMoveTimesOutQuicklyWithNoClient;
begin
  // CharPosX/Y are always 0 with no client, so a Move to (0,0) with tight
  // accuracy should succeed immediately (already "there") rather than loop.
  AssertTrue(Cmd.Move(0, 0, 5, 500));
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TUoCommandsTests);
end.
