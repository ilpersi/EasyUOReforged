unit PathPlanTests;

{ FPCUnit tests for uo\pathplan.pas, the pathfinder's A* planner, on synthetic grids
  (WalkGridSource): straight and diagonal paths, a wall with a gap, a goal nobody can reach,
  the budgets and the Stop flag, accuracy, a goal on a tree, climbing stairs to an upper floor,
  the script's rules (blocks, avoid areas, links) and the turn cost. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, walkrules, pathplan, WalkGridSource;

type
  TPathPlanTests = class(TTestCase)
  private
    G : TGridSource;
    P : TPathPlanner;
    function  Find(SX, SY, GX, GY : Integer) : TPathResult;
    function  OnPath(X, Y : Integer) : Boolean;
    function  Turns : Integer;
    procedure AssertConnected;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestStraightLine;
    procedure TestDiagonalCostsAsStraight;
    procedure TestAlreadyThere;
    procedure TestWallWithGap;
    procedure TestEnclosedGoalHasNoPath;
    procedure TestNodeBudget;
    procedure TestStopFlag;
    procedure TestAccuracy;
    procedure TestGoalOnTreeEndsNextToIt;
    procedure TestClimbsStairsToUpperFloor;
    procedure TestBlockIsAvoided;
    procedure TestBlockOnOtherFacetIgnored;
    procedure TestRemoveBlocks;
    procedure TestAvoidArea;
    procedure TestLinkCrossesWall;
    procedure TestTurnCostKeepsPathStraight;
  end;

implementation

const
  WALL  = TDF_IMPASSABLE;
  FLOOR = TDF_SURFACE;
  STAIR = TDF_SURFACE or TDF_BRIDGE;

procedure TPathPlanTests.SetUp;
begin
  G := TGridSource.Create(64, 64);
  P := TPathPlanner.Create;
end;

procedure TPathPlanTests.TearDown;
begin
  P.Free;
  G.Free;
end;

function TPathPlanTests.Find(SX, SY, GX, GY : Integer) : TPathResult;
begin
  Result := P.Find(G, 0, SX, SY, 0, -1, GX, GY, 0, False, nil);
end;

function TPathPlanTests.OnPath(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := False;
  for i := 0 to P.StepCount - 1 do
    if (P.Steps[i].X = X) and (P.Steps[i].Y = Y) then Exit(True);
end;

function TPathPlanTests.Turns : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 1 to P.StepCount - 1 do
    if P.Steps[i].Dir <> P.Steps[i-1].Dir then Inc(Result);
end;

// Every step is one tile in its own direction from the one before (links aside).
procedure TPathPlanTests.AssertConnected;
var
  i, X, Y : Integer;
begin
  for i := 1 to P.StepCount - 1 do
  begin
    if P.Steps[i].Dir = PATH_DIR_LINK then Continue;
    X := P.Steps[i-1].X + DirX[P.Steps[i].Dir];
    Y := P.Steps[i-1].Y + DirY[P.Steps[i].Dir];
    AssertEquals('step ' + IntToStr(i + 1) + ' x', X, P.Steps[i].X);
    AssertEquals('step ' + IntToStr(i + 1) + ' y', Y, P.Steps[i].Y);
  end;
end;

procedure TPathPlanTests.TestStraightLine;
var
  i : Integer;
begin
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  AssertEquals(10, P.StepCount);
  for i := 0 to P.StepCount - 1 do
    AssertEquals('east', 2, P.Steps[i].Dir);
  AssertEquals(15, P.Steps[9].X);
  AssertEquals(10, P.Steps[9].Y);
  AssertEquals(0, P.Steps[9].Z);
end;

procedure TPathPlanTests.TestDiagonalCostsAsStraight;
begin
  AssertTrue(Find(5, 5, 10, 10) = prOk);
  AssertEquals('five diagonal steps, as fast as five straight ones', 5, P.StepCount);
end;

procedure TPathPlanTests.TestAlreadyThere;
begin
  AssertTrue(Find(5, 5, 5, 5) = prOk);
  AssertEquals(0, P.StepCount);
end;

procedure TPathPlanTests.TestWallWithGap;
var
  i : Integer;
begin
  for i := 0 to 63 do
    if i <> 40 then G.AddStatic(20, i, 0, 20, WALL);
  AssertTrue(Find(10, 10, 30, 10) = prOk);
  AssertTrue('through the gap', OnPath(20, 40));
  for i := 0 to 63 do
    if i <> 40 then AssertFalse('never on the wall', OnPath(20, i));
  AssertConnected;
end;

procedure TPathPlanTests.TestEnclosedGoalHasNoPath;
var
  i : Integer;
begin
  for i := 37 to 43 do
  begin
    G.AddStatic(i, 37, 0, 20, WALL);
    G.AddStatic(i, 43, 0, 20, WALL);
    G.AddStatic(37, i, 0, 20, WALL);
    G.AddStatic(43, i, 0, 20, WALL);
  end;
  AssertTrue(Find(5, 5, 40, 40) = prNoPath);
  AssertEquals(0, P.StepCount);
end;

procedure TPathPlanTests.TestNodeBudget;
begin
  P.MaxNodes := 10;
  AssertTrue(Find(5, 5, 60, 60) = prBudget);
end;

procedure TPathPlanTests.TestStopFlag;
var
  Stop : Boolean;
  i    : Integer;
begin
  // An enclosed goal makes the search run through the whole grid, past the first Stop check.
  for i := 37 to 43 do
  begin
    G.AddStatic(i, 37, 0, 20, WALL);
    G.AddStatic(i, 43, 0, 20, WALL);
    G.AddStatic(37, i, 0, 20, WALL);
    G.AddStatic(43, i, 0, 20, WALL);
  end;
  Stop := True;
  AssertTrue(P.Find(G, 0, 5, 5, 0, -1, 40, 40, 0, False, @Stop) = prStopped);
end;

procedure TPathPlanTests.TestAccuracy;
begin
  P.AccuracyXY := 3;
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  AssertEquals(7, P.StepCount);
  AssertEquals(12, P.Steps[6].X);
end;

procedure TPathPlanTests.TestGoalOnTreeEndsNextToIt;
begin
  G.AddStatic(15, 10, 0, 20, WALL);
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  AssertTrue(P.GoalNear);
  AssertEquals(9, P.StepCount);
  AssertEquals(14, P.Steps[8].X);
end;

procedure TPathPlanTests.TestClimbsStairsToUpperFloor;
var
  X : Integer;
begin
  // Stairs going east at x 10..13 (z 0, 5, 10, 15), then an upper floor at 20 over x 14..20.
  for X := 10 to 13 do
    G.AddStatic(X, 10, (X - 10)*5, 5, STAIR);
  G.AddStaticRect(14, 8, 20, 12, 20, 0, FLOOR);

  AssertTrue('to the upper floor',
    P.Find(G, 0, 5, 10, 0, -1, 18, 10, 20, True, nil) = prOk);
  AssertEquals('ends up there', 20, P.Steps[P.StepCount-1].Z);
  AssertTrue('by the stairs', OnPath(13, 10));
  AssertConnected;

  AssertTrue('to the ground under it', P.Find(G, 0, 5, 9, 0, -1, 18, 9, 0, True, nil) = prOk);
  AssertEquals(0, P.Steps[P.StepCount-1].Z);
end;

procedure TPathPlanTests.TestBlockIsAvoided;
var
  i : Integer;
begin
  P.AddBlock(0, 10, 5, 10, 15);
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  for i := 5 to 15 do
    AssertFalse('not through the block', OnPath(10, i));
  AssertTrue(P.StepCount > 10);
  AssertConnected;
end;

procedure TPathPlanTests.TestBlockOnOtherFacetIgnored;
begin
  P.AddBlock(1, 10, 5, 10, 15);
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  AssertEquals(10, P.StepCount);
end;

procedure TPathPlanTests.TestRemoveBlocks;
begin
  P.AddBlock(0, 10, 10, 12, 12);
  P.AddBlock(0, 20, 20, 20, 20);
  P.AddBlock(1, 11, 11, 11, 11);
  AssertEquals('only the block overlapping 11,11 on facet 0', 1, P.RemoveBlocks(0, 11, 11, 11, 11));
  AssertEquals(2, Length(P.Blocks));
end;

procedure TPathPlanTests.TestAvoidArea;
var
  X, Y : Integer;
begin
  P.AddAvoid(0, 8, 6, 12, 14, 1000);   // each step inside costs 10 extra steps
  AssertTrue(Find(5, 10, 15, 10) = prOk);
  for X := 8 to 12 do
    for Y := 6 to 14 do
      AssertFalse('goes around the area', OnPath(X, Y));
end;

procedure TPathPlanTests.TestLinkCrossesWall;
var
  i : Integer;
  Found : Boolean;
begin
  for i := 0 to 63 do G.AddStatic(20, i, 0, 20, WALL);
  AssertTrue('no way across without the link', Find(10, 10, 30, 10) = prNoPath);

  P.AddLink(0, 19, 10, 0, 21, 10, 0, PATH_STEP_COST);
  AssertTrue(Find(10, 10, 30, 10) = prOk);
  Found := False;
  for i := 0 to P.StepCount - 1 do
    if P.Steps[i].Dir = PATH_DIR_LINK then
    begin
      Found := True;
      AssertEquals(21, P.Steps[i].X);
      AssertEquals(19, P.Steps[i-1].X);
    end;
  AssertTrue('a step through the link', Found);
  AssertConnected;
end;

procedure TPathPlanTests.TestTurnCostKeepsPathStraight;
begin
  AssertTrue(Find(5, 5, 15, 8) = prOk);
  AssertEquals('ten steps: three diagonal, seven east', 10, P.StepCount);
  AssertEquals('one change of direction', 1, Turns);
end;

initialization
  RegisterTest(TPathPlanTests);
end.
