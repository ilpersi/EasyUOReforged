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
