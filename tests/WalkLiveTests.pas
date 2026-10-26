unit WalkLiveTests;

{ FPCUnit tests for uo\walklive.pas, the walker's live overlay, on a synthetic grid
  (WalkGridSource) with a made-up tiledata (TileInfo below): items, house pieces and mobiles on
  top of the map, doors left out at a cost, the character never in its own way, learned blocks
  and their expiry, and a refresh replacing what was there. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, walkrules, walklive, pathplan, WalkGridSource;

const
  G_WALL  = 100;   // the graphics of the made-up tiledata
  G_TABLE = 101;
  G_DOOR  = 102;
  G_PLANT = 103;   // neither blocks nor can be stood on
  G_SLAB  = 104;   // a floor piece of a house: a surface 1 high

type
  TWalkLiveTests = class(TTestCase)
  private
    G  : TGridSource;
    Ov : TLiveOverlay;
    P  : TPathPlanner;
    function  Info(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
    function  Obj(X, Y, Z, Graphic : Integer; Kind : TLiveKind = lkItem; ID : Cardinal = $40000001) : TLiveObj;
    procedure Put(const Objs : array of TLiveObj);
    function  Stand(X, Y : Integer; out Z : Integer) : Boolean;
    function  OnPath(X, Y : Integer) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNoObjectsAnswersAsTheMap;
    procedure TestItemBlocks;
    procedure TestTableRaisesTheFloor;
    procedure TestUnknownOrHarmlessGraphicsChangeNothing;
    procedure TestHousePiecesCountAsStatics;
    procedure TestMobileBlocksUnlessIgnored;
    procedure TestCharacterIsNeverInItsOwnWay;
    procedure TestDoorIsOpenAtACost;
    procedure TestDoorShutWhenDoorsOff;
    procedure TestHouseDoorStaysShut;
    procedure TestPlannerGoesAroundLiveWall;
    procedure TestSetObjectsReplaces;
    procedure TestManyObjects;
    procedure TestLearnedBlockAndExpiry;
    procedure TestLearnedBlockIsPerFacet;
    procedure TestLearnRenewsAndUnlearnRemoves;
  end;

implementation

procedure TWalkLiveTests.SetUp;
begin
  G := TGridSource.Create(64, 64);
  Ov := TLiveOverlay.Create;
  Ov.Base := G;
  Ov.TileInfo := @Info;
  Ov.SelfID := 1;
  P := TPathPlanner.Create;
end;

procedure TWalkLiveTests.TearDown;
begin
  P.Free;
  Ov.Free;
  G.Free;
end;

function TWalkLiveTests.Info(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
begin
  Result := True;
  case Graphic of
    G_WALL  : begin Flags := TDF_IMPASSABLE; Height := 20; end;
    G_TABLE : begin Flags := TDF_SURFACE; Height := 5; end;
    G_DOOR  : begin Flags := TDF_IMPASSABLE or TDF_DOOR; Height := 20; end;
    G_PLANT : begin Flags := 0; Height := 3; end;
    G_SLAB  : begin Flags := TDF_SURFACE; Height := 1; end;
  else
    Flags := 0;
    Height := 0;
    Result := False;
  end;
end;

function TWalkLiveTests.Obj(X, Y, Z, Graphic : Integer; Kind : TLiveKind; ID : Cardinal) : TLiveObj;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
  Result.Graphic := Graphic;
  Result.Kind := Kind;
  Result.ID := ID;
end;

procedure TWalkLiveTests.Put(const Objs : array of TLiveObj);
var
  L : TLiveObjs;
  i : Integer;
begin
  SetLength(L, Length(Objs));
  for i := 0 to High(Objs) do L[i] := Objs[i];
  Ov.SetObjects(L);
end;

function TWalkLiveTests.Stand(X, Y : Integer; out Z : Integer) : Boolean;
begin
  Z := 0;
  Result := StandZ(Ov, X, Y, Z);
end;

function TWalkLiveTests.OnPath(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := False;
  for i := 0 to P.StepCount - 1 do
    if (P.Steps[i].X = X) and (P.Steps[i].Y = Y) then Exit(True);
end;

procedure TWalkLiveTests.TestNoObjectsAnswersAsTheMap;
var
  A, B : TPathObjList;
  Z, NZ : Integer;
begin
  AssertEquals(0, Ov.ObjectCount);
  AssertTrue(Ov.GetObjects(10, 10, A));
  AssertTrue(G.GetObjects(10, 10, B));
  AssertEquals(B.Count, A.Count);
  AssertFalse('outside the map, as the map', Ov.GetObjects(-1, 10, A));
  AssertTrue(Stand(10, 10, Z));
  AssertEquals(0, Z);
  AssertTrue(CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertEquals(0, Ov.CellCost(10, 10));
end;

procedure TWalkLiveTests.TestItemBlocks;
var
  Z, NZ : Integer;
begin
  Put([Obj(11, 10, 0, G_WALL)]);
  AssertFalse('nobody stands in the crate', Stand(11, 10, Z));
  AssertFalse(CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertTrue('the map itself is unchanged', StandZ(G, 11, 10, Z));
  AssertTrue('the cell beside it is free', Stand(12, 10, Z));
end;

procedure TWalkLiveTests.TestTableRaisesTheFloor;
var
  Z : Integer;
begin
  Put([Obj(20, 20, 0, G_TABLE)]);
  Z := 10;
  AssertTrue(StandZ(Ov, 20, 20, Z));
  AssertEquals('on top of the table', 5, Z);
end;

procedure TWalkLiveTests.TestUnknownOrHarmlessGraphicsChangeNothing;
var
  Z, NZ : Integer;
begin
  Put([Obj(11, 10, 0, 999), Obj(12, 10, 0, G_PLANT)]);
  AssertEquals(2, Ov.ObjectCount);
  AssertTrue(CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertTrue(CanStep(Ov, 11, 10, 0, 2, NZ));
  AssertTrue(Stand(12, 10, Z));
  AssertEquals(0, Z);
end;

procedure TWalkLiveTests.TestHousePiecesCountAsStatics;
var
  Z : Integer;
begin
  // a wall piece and, inside, a floor raised to 7
  Put([Obj(30, 30, 0, G_WALL, lkMulti, 0), Obj(31, 30, 6, G_SLAB, lkMulti, 0)]);
  AssertFalse(Stand(30, 30, Z));
  Z := 7;
  AssertTrue(StandZ(Ov, 31, 30, Z));
  AssertEquals(7, Z);
end;

procedure TWalkLiveTests.TestMobileBlocksUnlessIgnored;
var
  NZ : Integer;
begin
  Put([Obj(11, 10, 0, $190, lkMobile, $123)]);
  AssertFalse('a creature is in the way', CanStep(Ov, 10, 10, 0, 2, NZ));
  Ov.IgnoreMobiles := True;
  AssertTrue('walk through it', CanStep(Ov, 10, 10, 0, 2, NZ));
end;

procedure TWalkLiveTests.TestCharacterIsNeverInItsOwnWay;
var
  NZ : Integer;
begin
  Put([Obj(10, 10, 0, $190, lkMobile, 1)]);
  AssertTrue('the character can step off its own cell', CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertTrue('and back onto it', CanStep(Ov, 11, 10, 0, 6, NZ));
end;

procedure TWalkLiveTests.TestDoorIsOpenAtACost;
var
  NZ : Integer;
begin
  Put([Obj(11, 10, 0, G_DOOR)]);
  AssertTrue(Ov.DoorAt(11, 10));
  AssertFalse(Ov.DoorAt(12, 10));
  AssertTrue('the walker opens it', CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertEquals(50, Ov.CellCost(11, 10));
  AssertEquals(0, Ov.CellCost(12, 10));
  Ov.DoorCost := 120;
  AssertEquals(120, Ov.CellCost(11, 10));
end;

procedure TWalkLiveTests.TestDoorShutWhenDoorsOff;
var
  NZ : Integer;
begin
  Put([Obj(11, 10, 0, G_DOOR)]);
  Ov.OpenDoors := False;
  AssertFalse(CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertEquals(0, Ov.CellCost(11, 10));
  AssertTrue('still a door', Ov.DoorAt(11, 10));
end;

// A door on a cell with a house piece is a player house's: a wall, unless OpenHouseDoors.
procedure TWalkLiveTests.TestHouseDoorStaysShut;
var
  NZ : Integer;
begin
  Put([Obj(11, 10, 0, G_DOOR), Obj(11, 10, 0, G_SLAB, lkMulti, 0), Obj(11, 20, 0, G_DOOR)]);
  AssertFalse('the house door', CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertFalse(Ov.DoorAt(11, 10));
  AssertEquals(0, Ov.CellCost(11, 10));
  AssertTrue('a door elsewhere still opens', CanStep(Ov, 10, 20, 0, 2, NZ));
  AssertTrue(Ov.DoorAt(11, 20));
  Ov.OpenHouseDoors := True;
  AssertTrue('doors all', CanStep(Ov, 10, 10, 0, 2, NZ));
  AssertTrue(Ov.DoorAt(11, 10));
end;

procedure TWalkLiveTests.TestPlannerGoesAroundLiveWall;
var
  L : TLiveObjs;
  y : Integer;
begin
  // a live wall across x=20, y 0..40: the map alone would go straight through
  SetLength(L, 41);
  for y := 0 to 40 do L[y] := Obj(20, y, 0, G_WALL);
  Ov.SetObjects(L);
  AssertTrue(P.Find(G, 0, 10, 10, 0, -1, 30, 10, 0, False, nil) = prOk);
  AssertEquals('the map alone: straight', 20, P.StepCount);
  AssertTrue(P.Find(Ov, 0, 10, 10, 0, -1, 30, 10, 0, False, nil) = prOk);
  AssertTrue('round the end of the wall', OnPath(20, 41));
  for y := 0 to 40 do AssertFalse(OnPath(20, y));
end;

procedure TWalkLiveTests.TestSetObjectsReplaces;
var
  Z : Integer;
begin
  Put([Obj(11, 10, 0, G_WALL)]);
  AssertFalse(Stand(11, 10, Z));
  Put([Obj(12, 10, 0, G_WALL)]);
  AssertTrue('the crate was moved', Stand(11, 10, Z));
  AssertFalse(Stand(12, 10, Z));
  Ov.ClearObjects;
  AssertTrue(Stand(12, 10, Z));
  AssertEquals(0, Ov.ObjectCount);
end;

// Thousands of objects, several on a cell, as a house gives: every cell finds its own.
procedure TWalkLiveTests.TestManyObjects;
var
  L          : TLiveObjs;
  X, Y, n, Z : Integer;
begin
  SetLength(L, 40*40*2);
  n := 0;
  for Y := 10 to 49 do
    for X := 10 to 49 do
    begin
      L[n] := Obj(X, Y, 0, G_SLAB, lkMulti, 0);
      Inc(n);
      if (X + Y) mod 3 = 0 then L[n] := Obj(X, Y, 1, G_WALL, lkMulti, 0)
      else L[n] := Obj(X, Y, 1, G_PLANT, lkMulti, 0);
      Inc(n);
    end;
  Ov.SetObjects(L);
  AssertEquals(n, Ov.ObjectCount);
  for Y := 10 to 49 do
    for X := 10 to 49 do
      AssertEquals(Format('%d,%d', [X, Y]), (X + Y) mod 3 <> 0, Stand(X, Y, Z));
  AssertTrue('outside the house', Stand(5, 5, Z));
end;

procedure TWalkLiveTests.TestLearnedBlockAndExpiry;
var
  Z : Integer;
begin
  Ov.Learn(0, 15, 15, 1000, 500);
  AssertEquals(1, Ov.LearnedCount);
  AssertTrue(Ov.IsLearned(0, 15, 15));
  AssertFalse('nothing stands on a learned block', Stand(15, 15, Z));
  Ov.Expire(1499);
  AssertFalse('it lasts 500 ms', Stand(15, 15, Z));
  Ov.Expire(1500);
  AssertEquals(0, Ov.LearnedCount);
  AssertTrue('then it is gone', Stand(15, 15, Z));
end;

procedure TWalkLiveTests.TestLearnedBlockIsPerFacet;
var
  Z : Integer;
begin
  Ov.Facet := 0;
  Ov.Learn(1, 15, 15, 0, 60000);
  AssertTrue('learned on Trammel, walking Felucca', Stand(15, 15, Z));
  Ov.Facet := 1;
  AssertFalse(Stand(15, 15, Z));
end;

procedure TWalkLiveTests.TestLearnRenewsAndUnlearnRemoves;
var
  Z : Integer;
begin
  Ov.Learn(0, 15, 15, 1000, 500);
  Ov.Learn(0, 15, 15, 2000, 500);
  AssertEquals('one block, renewed', 1, Ov.LearnedCount);
  Ov.Expire(2400);
  AssertFalse(Stand(15, 15, Z));
  Ov.Learn(0, 16, 15, 2000, 500);
  Ov.Unlearn(0, 15, 15);
  AssertEquals(1, Ov.LearnedCount);
  AssertTrue(Stand(15, 15, Z));
  AssertFalse(Stand(16, 15, Z));
  Ov.ClearLearned;
  AssertTrue(Stand(16, 15, Z));
end;

initialization
  RegisterTest(TWalkLiveTests);
end.
