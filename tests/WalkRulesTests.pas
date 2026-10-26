unit WalkRulesTests;

{ FPCUnit tests for uo\walkrules.pas, the pathfinder's step rules ported from ClassicUO's
  Pathfinder.cs, on synthetic grids (WalkGridSource). Each case is a small map whose expected
  answer follows from the rules by hand: walls, the diagonal corner rule, the 2-unit climb
  limit, stairs (bridges: stand half way up), head room, a bridge over water, a floor above the
  ground, void land, and the sloped-land heights CalcMinMaxZ takes from the corners. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, walkrules, WalkGridSource;

type
  TWalkRulesTests = class(TTestCase)
  private
    G : TGridSource;
    function Step(X, Y, Z, Dir : Integer; out NewZ : Integer) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFlatGroundAllDirections;
    procedure TestWallBlocks;
    procedure TestDiagonalNeedsBothSides;
    procedure TestSmallStepUp;
    procedure TestHighStepBlocked;
    procedure TestStepDown;
    procedure TestStairsClimb;
    procedure TestLowCeilingBlocks;
    procedure TestHighCeilingAllows;
    procedure TestWaterBlocks;
    procedure TestBridgeOverWater;
    procedure TestFloorAboveGround;
    procedure TestVoidLandBlocks;
    procedure TestOutsideMapBlocks;
    procedure TestStandZ;
    procedure TestStretchedLandMinMaxZ;
    procedure TestStaticPathObjFlags;
  end;

implementation

const
  WALL  = TDF_IMPASSABLE;
  FLOOR = TDF_SURFACE;
  STAIR = TDF_SURFACE or TDF_BRIDGE;
  WATER = TDF_IMPASSABLE or TDF_WET;

procedure TWalkRulesTests.SetUp;
begin
  G := TGridSource.Create(20, 20);
end;

procedure TWalkRulesTests.TearDown;
begin
  G.Free;
end;

function TWalkRulesTests.Step(X, Y, Z, Dir : Integer; out NewZ : Integer) : Boolean;
begin
  Result := CanStep(G, X, Y, Z, Dir, NewZ);
end;

procedure TWalkRulesTests.TestFlatGroundAllDirections;
var
  d, NZ : Integer;
begin
  for d := 0 to 7 do
  begin
    AssertTrue('direction ' + IntToStr(d), Step(5, 5, 0, d, NZ));
    AssertEquals('direction ' + IntToStr(d), 0, NZ);
  end;
end;

procedure TWalkRulesTests.TestWallBlocks;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 0, 20, WALL);
  AssertFalse('east into the wall', Step(5, 5, 0, 2, NZ));
  AssertTrue('north is open', Step(5, 5, 0, 0, NZ));
end;

procedure TWalkRulesTests.TestDiagonalNeedsBothSides;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 0, 20, WALL);   // east of 5,5
  AssertFalse('north-east: the east side is a wall', Step(5, 5, 0, 1, NZ));
  AssertFalse('south-east: the east side is a wall', Step(5, 5, 0, 3, NZ));
  AssertTrue('north-west is clear', Step(5, 5, 0, 7, NZ));
end;

procedure TWalkRulesTests.TestSmallStepUp;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 0, 2, FLOOR);   // a surface 2 high: within the climb limit
  AssertTrue(Step(5, 5, 0, 2, NZ));
  AssertEquals(2, NZ);
end;

procedure TWalkRulesTests.TestHighStepBlocked;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 0, 5, FLOOR);   // a surface 5 high: too high to step onto
  AssertFalse(Step(5, 5, 0, 2, NZ));
end;

procedure TWalkRulesTests.TestStepDown;
var
  NZ : Integer;
begin
  G.AddStatic(5, 5, 0, 10, FLOOR);   // standing on a 10-high platform at 5,5
  AssertTrue('stepping off a platform', Step(5, 5, 10, 2, NZ));
  AssertEquals(0, NZ);
end;

procedure TWalkRulesTests.TestStairsClimb;
var
  X, Z, NZ : Integer;
begin
  // A staircase going east: stairs 5 high at z 0, 5, 10, 15. On a bridge a character stands
  // half way up, and may climb onto the next one from there.
  for X := 6 to 9 do
    G.AddStatic(X, 5, (X - 6)*5, 5, STAIR);
  Z := 0;
  for X := 5 to 8 do
  begin
    AssertTrue('onto stair ' + IntToStr(X + 1), Step(X, 5, Z, 2, NZ));
    AssertEquals('stair ' + IntToStr(X + 1), (X - 5)*5 + 2, NZ);
    Z := NZ;
  end;
end;

procedure TWalkRulesTests.TestLowCeilingBlocks;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 10, 5, WALL);   // a beam 10 above the ground: less head room than 16
  AssertFalse(Step(5, 5, 0, 2, NZ));
end;

procedure TWalkRulesTests.TestHighCeilingAllows;
var
  NZ : Integer;
begin
  G.AddStatic(6, 5, 16, 5, WALL);   // exactly 16 of head room
  AssertTrue(Step(5, 5, 0, 2, NZ));
  AssertEquals(0, NZ);
end;

procedure TWalkRulesTests.TestWaterBlocks;
var
  NZ : Integer;
begin
  G.SetLand(6, 5, -5, WATER);
  AssertFalse(Step(5, 5, 0, 2, NZ));
end;

procedure TWalkRulesTests.TestBridgeOverWater;
var
  X, Z, NZ : Integer;
begin
  for X := 6 to 8 do
  begin
    G.SetLand(X, 5, -5, WATER);
    G.AddStatic(X, 5, 0, 0, FLOOR);   // the planks
  end;
  Z := 0;
  for X := 5 to 8 do
  begin
    AssertTrue('across the bridge at ' + IntToStr(X + 1), Step(X, 5, Z, 2, NZ));
    AssertEquals(0, NZ);
    Z := NZ;
  end;
end;

procedure TWalkRulesTests.TestFloorAboveGround;
var
  NZ : Integer;
begin
  // An upper floor at 20 over 5,5 and 6,5: from the ground the character walks under it, from
  // the floor it stays on it.
  G.AddStatic(5, 5, 20, 0, FLOOR);
  G.AddStatic(6, 5, 20, 0, FLOOR);
  AssertTrue('under the floor', Step(5, 5, 0, 2, NZ));
  AssertEquals('under the floor', 0, NZ);
  AssertTrue('on the floor', Step(5, 5, 20, 2, NZ));
  AssertEquals('on the floor', 20, NZ);
end;

procedure TWalkRulesTests.TestVoidLandBlocks;
var
  NZ : Integer;
begin
  G.SetLand(6, 5, 0, 0, VOID);
  AssertFalse(Step(5, 5, 0, 2, NZ));
end;

procedure TWalkRulesTests.TestOutsideMapBlocks;
var
  NZ : Integer;
begin
  AssertFalse('west of x 0', Step(0, 5, 0, 6, NZ));
  AssertFalse('south of the last row', Step(5, 19, 0, 4, NZ));
end;

procedure TWalkRulesTests.TestStandZ;
var
  Z : Integer;
begin
  G.AddStatic(3, 3, 0, 20, WALL);   // a tree
  Z := 0;
  AssertFalse('nothing stands on a tree', StandZ(G, 3, 3, Z));
  Z := 0;
  AssertTrue('open ground', StandZ(G, 4, 4, Z));
  AssertEquals(0, Z);

  G.AddStatic(8, 8, 20, 0, FLOOR);
  Z := 18;
  AssertTrue(StandZ(G, 8, 8, Z));
  AssertEquals('the floor is nearest to 18', 20, Z);
  Z := 3;
  AssertTrue(StandZ(G, 8, 8, Z));
  AssertEquals('the ground is nearest to 3', 0, Z);
end;

procedure TWalkRulesTests.TestStretchedLandMinMaxZ;
var
  L          : TPathObjList;
  MinZ, MaxZ : Integer;
begin
  // A sloped land tile, corners top 0, right 10, bottom 10, left 0, standing height 5. Leaving
  // it, ClassicUO's CalculateCurrentAverageZ takes the height of the edge walked over.
  L.Count := 0;
  with L.Items[0] do
  begin
    FillChar(L.Items[0], SizeOf(L.Items[0]), 0);
    Flags := POF_IMPASSABLE_OR_SURFACE or POF_SURFACE or POF_BRIDGE;
    IsLand := True;
    Stretched := True;
    Z := 0;
    AverageZ := 5;
    Height := 5;
    CornerZ[0] := 0;
    CornerZ[1] := 10;
    CornerZ[2] := 10;
    CornerZ[3] := 0;
  end;
  L.Count := 1;

  CalcMinMaxZ(L, 5, 2, MinZ, MaxZ);         // east: the right and bottom corners
  AssertEquals('east min', 10, MinZ);
  AssertEquals('east max', 12, MaxZ);
  CalcMinMaxZ(L, 5, 0, MinZ, MaxZ);         // north: right and top, averaged
  AssertEquals('north min', 5, MinZ);
  AssertEquals('north max', 7, MaxZ);
  CalcMinMaxZ(L, 5, 1, MinZ, MaxZ);         // north-east: the right corner alone
  AssertEquals('north-east min', 10, MinZ);
  AssertEquals('north-east max', 12, MaxZ);
end;

procedure TWalkRulesTests.TestStaticPathObjFlags;
var
  O : TPathObj;
begin
  AssertFalse('a static that neither blocks nor carries is left out', StaticPathObj(0, 5, 0, O));
  AssertTrue(StaticPathObj(WALL or TDF_BRIDGE, 10, 3, O));
  AssertEquals('impassable: no surface or bridge bits', POF_IMPASSABLE_OR_SURFACE, O.Flags);
  AssertEquals('a bridge stands half way up even when impassable', 3 + 5, O.AverageZ);
  AssertTrue(StaticPathObj(STAIR, 5, 0, O));
  AssertEquals(POF_IMPASSABLE_OR_SURFACE or POF_SURFACE or POF_BRIDGE, O.Flags);
  AssertEquals(2, O.AverageZ);
  AssertEquals(5, O.Height);
end;

initialization
  RegisterTest(TWalkRulesTests);
end.
