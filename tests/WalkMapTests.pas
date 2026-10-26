unit WalkMapTests;

{ FPCUnit tests for uo\walkmap.pas, the pathfinder's world model, against the synthetic fixture
  set in tests\fixtures\walk (generated independently by tests\tools\GenerateWalkFixtures.ps1,
  whose header lists what is where). Covers the facet size taken from staidx, the new tiledata
  format (64-bit flags), land/static objects as ClassicUO makes them (stairs half way up,
  ignored decorations, water, void, a slope), the map edge, and the dif files.

  Trammel's own files versus Felucca's are checked on small map0/map1 sets the tests write into
  a temporary folder: those only have to differ, not to cross-check the format.

  TestRealInstallRoutes plans a few routes on the installed client's files (EUO_UO_DIR, or the
  EA install from the registry), printing nodes and milliseconds; ignored without an install. }

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Registry, fpcunit, testregistry, walkrules, walkmap, pathplan;

type
  TWalkMapTests = class(TTestCase)
  private
    M : TWalkMap;
    function  Objects(X, Y : Integer; out L : TPathObjList) : Boolean;
    function  Other(const L : TPathObjList) : TPathObj;
    procedure WriteFacet(const Dir : String; Nr, LandZ : Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDimensionsFromStaidx;
    procedure TestMissingFacet;
    procedure TestFlatLand;
    procedure TestWallOnCell;
    procedure TestStairStandsHalfWay;
    procedure TestIgnoredStatic;
    procedure TestWaterLand;
    procedure TestVoidLand;
    procedure TestSlope;
    procedure TestOutsideMap;
    procedure TestDifFiles;
    procedure TestGuessTileDataFormat;
    procedure TestTrammelReadsOwnFiles;
    procedure TestTrammelFallsBackToFelucca;
    procedure TestPlannerAroundWallAndStair;
    procedure TestRealInstallRoutes;
  end;

implementation

function FixtureDir : String;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'walk' + PathDelim;
end;

procedure TWalkMapTests.SetUp;
begin
  M := TWalkMap.Create(FixtureDir, True, False);
end;

procedure TWalkMapTests.TearDown;
begin
  M.Free;
end;

function TWalkMapTests.Objects(X, Y : Integer; out L : TPathObjList) : Boolean;
begin
  AssertTrue('facet 4 opens', M.SelectFacet(4));
  Result := M.GetObjects(X, Y, L);
end;

// The one object of L that is not the land.
function TWalkMapTests.Other(const L : TPathObjList) : TPathObj;
var
  i : Integer;
begin
  for i := 0 to L.Count-1 do
    if not L.Items[i].IsLand then Exit(L.Items[i]);
  Fail('no static on the cell');
end;

procedure TWalkMapTests.TestDimensionsFromStaidx;
begin
  AssertTrue(M.SelectFacet(4));
  AssertEquals('one column of blocks', 8, M.Width);
  AssertEquals(1448, M.Height);
  AssertEquals(4, M.FileNr);
end;

procedure TWalkMapTests.TestMissingFacet;
begin
  AssertFalse(M.SelectFacet(3));
  AssertFalse(M.SelectFacet(1));
  AssertEquals(-1, M.FileNr);
  AssertFalse(M.SelectFacet(6));
end;

procedure TWalkMapTests.TestFlatLand;
var
  L : TPathObjList;
begin
  AssertTrue(Objects(3, 3, L));
  AssertEquals(1, L.Count);
  AssertTrue(L.Items[0].IsLand);
  AssertEquals(POF_IMPASSABLE_OR_SURFACE or POF_SURFACE or POF_BRIDGE, L.Items[0].Flags);
  AssertEquals(0, L.Items[0].Z);
  AssertEquals(0, L.Items[0].AverageZ);
  AssertFalse(L.Items[0].Stretched);
end;

procedure TWalkMapTests.TestWallOnCell;
var
  L : TPathObjList;
  O : TPathObj;
begin
  AssertTrue(Objects(3, 4, L));
  AssertEquals(2, L.Count);
  O := Other(L);
  AssertEquals('impassable, bit 40 of the flags ignored', POF_IMPASSABLE_OR_SURFACE, O.Flags);
  AssertEquals(20, O.Height);
  AssertEquals(20, O.AverageZ);
end;

procedure TWalkMapTests.TestStairStandsHalfWay;
var
  L : TPathObjList;
  O : TPathObj;
begin
  AssertTrue(Objects(4, 4, L));
  O := Other(L);
  AssertEquals(POF_IMPASSABLE_OR_SURFACE or POF_SURFACE or POF_BRIDGE, O.Flags);
  AssertEquals(5, O.Z);
  AssertEquals('5 + 5 div 2', 7, O.AverageZ);
end;

procedure TWalkMapTests.TestIgnoredStatic;
var
  L : TPathObjList;
  O : TPathObj;
begin
  AssertTrue(Objects(1, 10, L));
  AssertEquals('land and floor; the decoration is left out', 2, L.Count);
  O := Other(L);
  AssertEquals(20, O.Z);
  AssertEquals(POF_IMPASSABLE_OR_SURFACE or POF_SURFACE, O.Flags);
end;

procedure TWalkMapTests.TestWaterLand;
var
  L : TPathObjList;
begin
  AssertTrue(Objects(5, 2, L));
  AssertEquals(1, L.Count);
  AssertEquals('water only blocks', POF_IMPASSABLE_OR_SURFACE, L.Items[0].Flags);
  AssertEquals(-5, L.Items[0].Z);
end;

procedure TWalkMapTests.TestVoidLand;
var
  L : TPathObjList;
begin
  AssertTrue('inside the map', Objects(6, 2, L));
  AssertEquals('but nothing there', 0, L.Count);
end;

procedure TWalkMapTests.TestSlope;
var
  L : TPathObjList;
begin
  // z = x*4 in block 2: at 2,18 the corners are 8 (top), 12 (right), 12 (bottom), 8 (left).
  AssertTrue(Objects(2, 18, L));
  AssertEquals(1, L.Count);
  with L.Items[0] do
  begin
    AssertTrue(Stretched);
    AssertEquals('lowest corner', 8, Z);
    AssertEquals('average of top and bottom', 10, AverageZ);
    AssertEquals(2, Height);
    AssertEquals(8, CornerZ[0]);
    AssertEquals(12, CornerZ[1]);
    AssertEquals(12, CornerZ[2]);
    AssertEquals(8, CornerZ[3]);
  end;
end;

procedure TWalkMapTests.TestOutsideMap;
var
  L : TPathObjList;
begin
  AssertFalse(Objects(8, 0, L));
  AssertFalse(Objects(0, 1448, L));
  AssertFalse(Objects(-1, 0, L));
end;

procedure TWalkMapTests.TestDifFiles;
var
  D : TWalkMap;
  L : TPathObjList;
  O : TPathObj;
begin
  D := TWalkMap.Create(FixtureDir, True, True);
  try
    AssertTrue(D.SelectFacet(4));
    AssertTrue(D.GetObjects(3, 3, L));
    AssertEquals('mapdif4 lifts block 0 to 7', 7, L.Items[0].Z);
    AssertTrue(D.GetObjects(1, 10, L));
    AssertEquals(2, L.Count);
    O := Other(L);
    AssertEquals('stadif4 puts a wall there instead of the floor', 20, O.Height);
    AssertEquals(0, O.Z);
  finally
    D.Free;
  end;
end;

procedure TWalkMapTests.TestGuessTileDataFormat;
begin
  AssertTrue('the fixture: new format', GuessNewTileData(494884));
  AssertFalse('a whole old-format file', GuessNewTileData(512*(4 + 32*26) + 3*(4 + 32*37)));
end;

// A facet-N set of one column of 512 blocks (Felucca/Trammel height), flat at LandZ.
procedure TWalkMapTests.WriteFacet(const Dir : String; Nr, LandZ : Integer);
var
  F    : TFileStream;
  Blk  : array[0..195] of Byte;
  Idx  : array[0..11] of Byte;
  i, c : Integer;
begin
  FillChar(Blk, SizeOf(Blk), 0);
  for c := 0 to 63 do
  begin
    Blk[4 + c*3] := 3;                // grass
    Blk[4 + c*3 + 2] := Byte(LandZ);
  end;
  F := TFileStream.Create(Dir + 'map' + IntToStr(Nr) + '.mul', fmCreate);
  try
    for i := 0 to 511 do F.WriteBuffer(Blk, SizeOf(Blk));
  finally
    F.Free;
  end;
  FillChar(Idx, SizeOf(Idx), $FF);
  F := TFileStream.Create(Dir + 'staidx' + IntToStr(Nr) + '.mul', fmCreate);
  try
    for i := 0 to 511 do F.WriteBuffer(Idx, SizeOf(Idx));
  finally
    F.Free;
  end;
  TFileStream.Create(Dir + 'statics' + IntToStr(Nr) + '.mul', fmCreate).Free;
end;

function TempFacetDir(const Name : String) : String;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'euo_walk_' + Name + '_' +
    IntToStr(GetProcessID) + PathDelim;
  ForceDirectories(Result);
end;

procedure CopyFixture(const Name, Dir : String);
var
  S : TMemoryStream;
begin
  S := TMemoryStream.Create;
  try
    S.LoadFromFile(FixtureDir + Name);
    S.SaveToFile(Dir + Name);
  finally
    S.Free;
  end;
end;

procedure TWalkMapTests.TestTrammelReadsOwnFiles;
var
  Dir : String;
  T   : TWalkMap;
  L   : TPathObjList;
begin
  Dir := TempFacetDir('tram');
  CopyFixture('tiledata.mul', Dir);
  WriteFacet(Dir, 0, 1);
  WriteFacet(Dir, 1, 9);
  T := TWalkMap.Create(Dir, True, False);
  try
    AssertTrue(T.SelectFacet(1));
    AssertEquals('map1 and its statics', 1, T.FileNr);
    AssertTrue(T.GetObjects(3, 3, L));
    AssertEquals(9, L.Items[0].Z);
    AssertEquals('one column of 512 blocks', 8, T.Width);
    AssertEquals(4096, T.Height);
  finally
    T.Free;
  end;
end;

procedure TWalkMapTests.TestTrammelFallsBackToFelucca;
var
  Dir : String;
  T   : TWalkMap;
  L   : TPathObjList;
begin
  Dir := TempFacetDir('fel');
  CopyFixture('tiledata.mul', Dir);
  WriteFacet(Dir, 0, 1);
  DeleteFile(Dir + 'map1.mul');
  T := TWalkMap.Create(Dir, True, False);
  try
    AssertTrue(T.SelectFacet(1));
    AssertEquals('an old install: Felucca''s files', 0, T.FileNr);
    AssertTrue(T.GetObjects(3, 3, L));
    AssertEquals(1, L.Items[0].Z);
  finally
    T.Free;
  end;
end;

procedure TWalkMapTests.TestPlannerAroundWallAndStair;
var
  P : TPathPlanner;
  i : Integer;
begin
  // From 2,4 to 5,4 the wall (3,4) and the stair (4,4), whose bottom is too high to step on
  // from the ground, are in the way.
  AssertTrue(M.SelectFacet(4));
  P := TPathPlanner.Create;
  try
    AssertTrue(P.Find(M, 4, 2, 4, 0, -1, 5, 4, 0, True, nil) = prOk);
    for i := 0 to P.StepCount-1 do
    begin
      AssertFalse('not through the wall', (P.Steps[i].X = 3) and (P.Steps[i].Y = 4));
      AssertFalse('not over the stair', (P.Steps[i].X = 4) and (P.Steps[i].Y = 4));
    end;
    AssertEquals(5, P.Steps[P.StepCount-1].X);
    AssertEquals(4, P.Steps[P.StepCount-1].Y);
  finally
    P.Free;
  end;
end;

// The installed client's folder: EUO_UO_DIR, else the EA install recorded in the registry.
function InstallDir : String;
var
  R : TRegistry;
begin
  Result := GetEnvironmentVariable('EUO_UO_DIR');
  if Result <> '' then Exit(IncludeTrailingPathDelimiter(Result));
  R := TRegistry.Create(KEY_READ or KEY_WOW64_32KEY);
  try
    R.RootKey := HKEY_LOCAL_MACHINE;
    if R.OpenKeyReadOnly('SOFTWARE\Electronic Arts\EA Games\Ultima Online Classic') then
      Result := R.ReadString('InstallDir');
  finally
    R.Free;
  end;
  if Result <> '' then Result := IncludeTrailingPathDelimiter(Result);
end;

procedure TWalkMapTests.TestRealInstallRoutes;
const
  // x1 y1 x2 y2 on Felucca: around Britain's bank, Britain to its east side, to Trinsic, to Minoc.
  Routes : array[0..3, 0..3] of Integer = (
    (1434, 1699, 1434, 1640),
    (1434, 1699, 1640, 1690),
    (1434, 1699, 1823, 2821),
    (1434, 1699, 2505, 552));
var
  Dir    : String;
  Real   : TWalkMap;
  P      : TPathPlanner;
  F      : TFileStream;
  NewTD  : Boolean;
  i      : Integer;
  SX, SY : Integer;
  SZ     : Integer;
  R      : TPathResult;
  T0, Ms : QWord;
  Turn   : Integer;
  k      : Integer;

  // The standable cell nearest to X,Y (rings up to 8), its height in Z.
  function Stand(var X, Y : Integer; out Z : Integer) : Boolean;
  var
    Rad, DX, DY : Integer;
  begin
    for Rad := 0 to 8 do
      for DX := -Rad to Rad do
        for DY := -Rad to Rad do
          if (Abs(DX) = Rad) or (Abs(DY) = Rad) then
          begin
            Z := 0;
            if StandZ(Real, X + DX, Y + DY, Z) then
            begin
              Inc(X, DX);
              Inc(Y, DY);
              Exit(True);
            end;
          end;
    Result := False;
  end;

begin
  Dir := InstallDir;
  if (Dir = '') or not FileExists(Dir + 'tiledata.mul') then
    Ignore('No UO client install found (set EUO_UO_DIR to its folder to run this test).');
  F := TFileStream.Create(Dir + 'tiledata.mul', fmOpenRead or fmShareDenyNone);
  try
    NewTD := GuessNewTileData(F.Size);
  finally
    F.Free;
  end;

  Real := TWalkMap.Create(Dir, NewTD, False);
  P := TPathPlanner.Create;
  try
    if not Real.SelectFacet(0) then Ignore('The install at ' + Dir + ' has no Felucca map files.');
    for i := 0 to High(Routes) do
    begin
      SX := Routes[i][0];
      SY := Routes[i][1];
      AssertTrue('a standable start near ' + IntToStr(SX) + ',' + IntToStr(SY), Stand(SX, SY, SZ));
      P.AccuracyXY := 2;            // the default budgets, so this also checks they are enough
      T0 := GetTickCount64;
      R := P.Find(Real, 0, SX, SY, SZ, -1, Routes[i][2], Routes[i][3], 0, False, nil);
      Ms := GetTickCount64 - T0;
      Turn := 0;
      for k := 1 to P.StepCount-1 do if P.Steps[k].Dir <> P.Steps[k-1].Dir then Inc(Turn);
      WriteLn(Format('  route %d,%d -> %d,%d: %s, %d steps, %d turns, %d nodes, %d ms',
        [SX, SY, Routes[i][2], Routes[i][3], PathResultName(R), P.StepCount, Turn, P.Expanded, Ms]));
      if i <= 1 then
        AssertTrue('route ' + IntToStr(i + 1) + ' in Britain is found', R = prOk);
    end;
  finally
    P.Free;
    Real.Free;
  end;
end;

initialization
  RegisterTest(TWalkMapTests);
end.
