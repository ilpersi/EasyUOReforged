unit pathplan;

{
  New addition (not in the original EasyUO): the pathfinder's planner -- an A* search over
  (x, y, z) positions on one facet, with walkrules' step rules, on any TWalkSource. Pure logic:
  no client, no files, so the tests run it on synthetic grids. See docs\pathfinding.md.

  - Costs are in hundredths of a step (PATH_STEP_COST = 100). A diagonal step costs the same as a
    straight one, because in UO it takes the same time. A change of direction adds TurnCost,
    since the client turns before it steps; by default 30, roughly what ClassicUO's walker waits
    for a turn compared to a walking step. Avoid areas add their cost to every step that ends
    inside them, and the source's CellCost (the walker's live overlay: doors) to every step onto
    the cell. Links (teleporters, gates, ladders) are extra edges with their own cost.
  - The heuristic is the Chebyshev distance in steps times Heuristic percent. At the default 100
    the search is exact. Above it is a weighted A*: on Felucca, 120 expanded about half the
    nodes from Britain to Minoc, but the path was ~4% longer with twice the turns.
  - The turn cost looks at the direction of the step that reached a node, and nodes are keyed by
    (x, y, z) only, as in ClassicUO's own pathfinder. That keeps the search small; a path where
    turning early would have saved a turn may be missed.
  - Budgets: MaxNodes expanded nodes, TimeoutMs milliseconds, and a search box around start and
    goal (Margin tiles on every side, widened for links that start inside it). Without them a
    goal that cannot be reached (an island, a closed room) would search the whole facet.
  - The search reads the cell it expands once for all eight directions, and a diagonal reuses the
    two straight steps beside it: the same check walkrules.CanStep makes, done once.
  - If nothing can stand on the goal itself (a tree, a rock, a chest) and AccuracyXY is 0, the
    path ends next to it, as ClassicUO's WalkTo does (GoalNear says so).
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, walkrules;

const
  PATH_STEP_COST = 100;   // one step, in the units every cost here uses
  PATH_DIR_LINK  = 8;     // the direction of a step through a link
  LINK_Z_RANGE   = 5;     // a link starts from a height within this many units of its own

type
  TPathStep = record
    X, Y, Z : Integer;
    Dir     : Integer;    // 0..7 as #CharDir, PATH_DIR_LINK for a link
  end;
  TPathSteps = array of TPathStep;

  TPathRect = record      // a block (Cost unused) or an avoid area
    Facet          : Integer;
    X1, Y1, X2, Y2 : Integer;
    Cost           : Integer;
  end;

  TPathLink = record
    Facet      : Integer;
    X1, Y1, Z1 : Integer;
    X2, Y2, Z2 : Integer;
    Cost       : Integer;
  end;

  TPathResult = (prOk, prNoPath, prBudget, prTimeout, prStopped);

  TPathPlanner = class
  private
    type
      TNode = record
        X, Y   : Integer;
        Z      : SmallInt;
        Dir    : ShortInt;   // the step that reached it, -1 = none
        Closed : Boolean;
        G, H   : Integer;
        Parent : Integer;
      end;
      THeapItem = record
        F, Node : Integer;
      end;
    var
      FNodes     : array of TNode;
      FNodeCount : Integer;
      FHash      : array of Integer;
      FHashMask  : Integer;
      FHeap      : array of THeapItem;
      FHeapCount : Integer;
      // the rules of the facet being searched
      FBlk       : array of TPathRect;
      FAvd       : array of TPathRect;
      FLnk       : array of TPathLink;
      // the search in progress
      FGX, FGY   : Integer;
      FGZ        : Integer;
      FHasGZ     : Boolean;
      FAcc       : Integer;
      FBX1, FBY1 : Integer;
      FBX2, FBY2 : Integer;
    function  HashOf(X, Y, Z : Integer) : Integer;
    procedure Rehash(NewSize : Integer);
    function  FindNode(X, Y, Z : Integer) : Integer;
    function  AddNode(X, Y, Z : Integer) : Integer;
    procedure Push(F, Node : Integer);
    function  Pop(out Node : Integer; out F : Integer) : Boolean;
    function  Heur(X, Y : Integer) : Integer;
    function  AtGoal(const N : TNode) : Boolean;
    function  Blocked(X, Y : Integer) : Boolean;
    function  AvoidCost(X, Y : Integer) : Integer;
    procedure Relax(X, Y, Z, Dir, Parent, Cost : Integer);
    procedure Expand(Src : TWalkSource; Node : Integer);
    procedure Reconstruct(Goal : Integer);
    procedure PrepareRules(Facet, SX, SY : Integer);
  public
    // Options (see ResetOptions for the defaults).
    AccuracyXY : Integer;   // arrive within this many tiles of the goal
    AccuracyZ  : Integer;   // and, when the goal has a height, within this many units of it
    MaxNodes   : Integer;
    TimeoutMs  : Integer;
    Margin     : Integer;
    TurnCost   : Integer;
    Heuristic  : Integer;   // percent
    // Rules, for every facet.
    Blocks     : array of TPathRect;
    Avoids     : array of TPathRect;
    Links      : array of TPathLink;
    // The result of the last Find.
    StartX     : Integer;   // where it started (the walker finds the character on it)
    StartY     : Integer;
    StartZ     : Integer;
    StartFacet : Integer;
    Steps      : TPathSteps;
    StepCount  : Integer;
    Expanded   : Integer;   // nodes the search expanded
    GoalNear   : Boolean;   // the goal could not be stood on: the path ends next to it
    constructor Create;
    procedure ResetOptions;
    procedure AddBlock(Facet, X1, Y1, X2, Y2 : Integer);
    function  RemoveBlocks(Facet, X1, Y1, X2, Y2 : Integer) : Integer;   // those overlapping the area
    procedure AddAvoid(Facet, X1, Y1, X2, Y2, Cost : Integer);
    procedure AddLink(Facet, X1, Y1, Z1, X2, Y2, Z2, Cost : Integer);
    procedure ClearRules(ClearBlocks, ClearAvoids, ClearLinks : Boolean);
    // Plans from SX,SY,SZ (facing SDir, -1 if unknown) to GX,GY (and GZ when HasGZ) on the facet
    // Src answers for; Facet only picks the rules. Stop, when not nil, interrupts the search when
    // it becomes True.
    function  Find(Src : TWalkSource; Facet, SX, SY, SZ, SDir, GX, GY, GZ : Integer;
      HasGZ : Boolean; Stop : PBoolean) : TPathResult;
  end;

// The word #PathState shows for a result.
function PathResultName(R : TPathResult) : String;

implementation

function PathResultName(R : TPathResult) : String;
begin
  case R of
    prOk      : Result := 'ok';
    prNoPath  : Result := 'nopath';
    prBudget  : Result := 'budget';
    prTimeout : Result := 'timeout';
    prStopped : Result := 'stopped';
  else
    Result := '';
  end;
end;

function Inside(const R : TPathRect; X, Y : Integer) : Boolean; inline;
begin
  Result := (X >= R.X1) and (X <= R.X2) and (Y >= R.Y1) and (Y <= R.Y2);
end;

function MakeRect(Facet, X1, Y1, X2, Y2, Cost : Integer) : TPathRect;
begin
  Result.Facet := Facet;
  if X1 <= X2 then begin Result.X1 := X1; Result.X2 := X2; end
  else begin Result.X1 := X2; Result.X2 := X1; end;
  if Y1 <= Y2 then begin Result.Y1 := Y1; Result.Y2 := Y2; end
  else begin Result.Y1 := Y2; Result.Y2 := Y1; end;
  Result.Cost := Cost;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TPathPlanner.Create;
begin
  inherited Create;
  ResetOptions;
end;

procedure TPathPlanner.ResetOptions;
begin
  AccuracyXY := 0;
  AccuracyZ := 5;
  MaxNodes := 1000000;   // as TazUO's long-range pathfinder; Britain to Minoc takes ~450k
  TimeoutMs := 5000;
  Margin := 100;
  TurnCost := 30;
  Heuristic := 100;      // exact; 120 halves the nodes but walks ~4% further with twice the turns
end;

procedure TPathPlanner.AddBlock(Facet, X1, Y1, X2, Y2 : Integer);
begin
  SetLength(Blocks, Length(Blocks) + 1);
  Blocks[High(Blocks)] := MakeRect(Facet, X1, Y1, X2, Y2, 0);
end;

function TPathPlanner.RemoveBlocks(Facet, X1, Y1, X2, Y2 : Integer) : Integer;
var
  R    : TPathRect;
  i, n : Integer;
begin
  R := MakeRect(Facet, X1, Y1, X2, Y2, 0);
  Result := 0;
  n := 0;
  for i := 0 to High(Blocks) do
    if (Blocks[i].Facet = Facet) and (Blocks[i].X1 <= R.X2) and (Blocks[i].X2 >= R.X1) and
      (Blocks[i].Y1 <= R.Y2) and (Blocks[i].Y2 >= R.Y1) then
      Inc(Result)
    else
    begin
      Blocks[n] := Blocks[i];
      Inc(n);
    end;
  SetLength(Blocks, n);
end;

procedure TPathPlanner.AddAvoid(Facet, X1, Y1, X2, Y2, Cost : Integer);
begin
  SetLength(Avoids, Length(Avoids) + 1);
  Avoids[High(Avoids)] := MakeRect(Facet, X1, Y1, X2, Y2, Cost);
end;

procedure TPathPlanner.AddLink(Facet, X1, Y1, Z1, X2, Y2, Z2, Cost : Integer);
begin
  SetLength(Links, Length(Links) + 1);
  Links[High(Links)].Facet := Facet;
  Links[High(Links)].X1 := X1;
  Links[High(Links)].Y1 := Y1;
  Links[High(Links)].Z1 := Z1;
  Links[High(Links)].X2 := X2;
  Links[High(Links)].Y2 := Y2;
  Links[High(Links)].Z2 := Z2;
  Links[High(Links)].Cost := Cost;
end;

procedure TPathPlanner.ClearRules(ClearBlocks, ClearAvoids, ClearLinks : Boolean);
begin
  if ClearBlocks then SetLength(Blocks, 0);
  if ClearAvoids then SetLength(Avoids, 0);
  if ClearLinks then SetLength(Links, 0);
end;

////////////////////////////////////////////////////////////////////////////////
function TPathPlanner.HashOf(X, Y, Z : Integer) : Integer;
begin
  Result := Integer((Cardinal(X)*73856093) xor (Cardinal(Y)*19349663) xor
    (Cardinal(Z + 128)*83492791)) and FHashMask;
end;

procedure TPathPlanner.Rehash(NewSize : Integer);
var
  i, h : Integer;
begin
  SetLength(FHash, 0);
  SetLength(FHash, NewSize);
  FillDWord(FHash[0], NewSize, $FFFFFFFF);
  FHashMask := NewSize - 1;
  for i := 0 to FNodeCount-1 do
  begin
    h := HashOf(FNodes[i].X, FNodes[i].Y, FNodes[i].Z);
    while FHash[h] >= 0 do h := (h + 1) and FHashMask;
    FHash[h] := i;
  end;
end;

function TPathPlanner.FindNode(X, Y, Z : Integer) : Integer;
var
  h : Integer;
begin
  h := HashOf(X, Y, Z);
  repeat
    Result := FHash[h];
    if Result < 0 then Exit;
    if (FNodes[Result].X = X) and (FNodes[Result].Y = Y) and (FNodes[Result].Z = Z) then Exit;
    h := (h + 1) and FHashMask;
  until False;
end;

function TPathPlanner.AddNode(X, Y, Z : Integer) : Integer;
var
  h : Integer;
begin
  if FNodeCount >= Length(FNodes) then SetLength(FNodes, Length(FNodes)*2 + 1024);
  Result := FNodeCount;
  Inc(FNodeCount);
  FNodes[Result].X := X;
  FNodes[Result].Y := Y;
  FNodes[Result].Z := Z;
  FNodes[Result].Closed := False;
  if FNodeCount*2 > Length(FHash) then
    Rehash(Length(FHash)*2)
  else
  begin
    h := HashOf(X, Y, Z);
    while FHash[h] >= 0 do h := (h + 1) and FHashMask;
    FHash[h] := Result;
  end;
end;

procedure TPathPlanner.Push(F, Node : Integer);
var
  i, p : Integer;
  Item : THeapItem;
begin
  if FHeapCount >= Length(FHeap) then SetLength(FHeap, Length(FHeap)*2 + 1024);
  Item.F := F;
  Item.Node := Node;
  i := FHeapCount;
  Inc(FHeapCount);
  while i > 0 do
  begin
    p := (i - 1) shr 1;
    if FHeap[p].F <= F then Break;
    FHeap[i] := FHeap[p];
    i := p;
  end;
  FHeap[i] := Item;
end;

function TPathPlanner.Pop(out Node : Integer; out F : Integer) : Boolean;
var
  i, c : Integer;
  Last : THeapItem;
begin
  Result := FHeapCount > 0;
  if not Result then Exit;
  Node := FHeap[0].Node;
  F := FHeap[0].F;
  Dec(FHeapCount);
  if FHeapCount = 0 then Exit;
  Last := FHeap[FHeapCount];
  i := 0;
  repeat
    c := i*2 + 1;
    if c >= FHeapCount then Break;
    if (c + 1 < FHeapCount) and (FHeap[c+1].F < FHeap[c].F) then Inc(c);
    if FHeap[c].F >= Last.F then Break;
    FHeap[i] := FHeap[c];
    i := c;
  until False;
  FHeap[i] := Last;
end;

////////////////////////////////////////////////////////////////////////////////
function TPathPlanner.Heur(X, Y : Integer) : Integer;
var
  D : Integer;
begin
  D := Abs(X - FGX);
  if Abs(Y - FGY) > D then D := Abs(Y - FGY);
  Dec(D, FAcc);
  if D < 0 then D := 0;
  Result := D*Heuristic;   // D steps of PATH_STEP_COST, times Heuristic percent
end;

function TPathPlanner.AtGoal(const N : TNode) : Boolean;
begin
  Result := (Abs(N.X - FGX) <= FAcc) and (Abs(N.Y - FGY) <= FAcc) and
    (not FHasGZ or (Abs(N.Z - FGZ) <= AccuracyZ));
end;

function TPathPlanner.Blocked(X, Y : Integer) : Boolean;
var
  i : Integer;
begin
  Result := True;
  if (X < FBX1) or (X > FBX2) or (Y < FBY1) or (Y > FBY2) then Exit;
  for i := 0 to High(FBlk) do
    if Inside(FBlk[i], X, Y) then Exit;
  Result := False;
end;

function TPathPlanner.AvoidCost(X, Y : Integer) : Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to High(FAvd) do
    if Inside(FAvd[i], X, Y) then Inc(Result, FAvd[i].Cost);
end;

procedure TPathPlanner.Relax(X, Y, Z, Dir, Parent, Cost : Integer);
var
  i, G : Integer;
begin
  G := FNodes[Parent].G + Cost;
  i := FindNode(X, Y, Z);
  if i < 0 then
  begin
    i := AddNode(X, Y, Z);
    FNodes[i].H := Heur(X, Y);
  end
  else if FNodes[i].Closed or (G >= FNodes[i].G) then
    Exit;
  FNodes[i].G := G;
  FNodes[i].Dir := Dir;
  FNodes[i].Parent := Parent;
  Push(G + FNodes[i].H, i);
end;

procedure TPathPlanner.Expand(Src : TWalkSource; Node : Integer);
const
  Order : array[0..7] of Integer = (0, 2, 4, 6, 1, 3, 5, 7);   // straight steps first
var
  SrcList, DestList : TPathObjList;
  Ok                : array[0..7] of Boolean;
  NewZ              : array[0..7] of Integer;
  X, Y, Z, PDir     : Integer;
  k, d, NX, NY      : Integer;
  MinZ, MaxZ, NZ    : Integer;
  Cost, i           : Integer;
begin
  X := FNodes[Node].X;
  Y := FNodes[Node].Y;
  Z := FNodes[Node].Z;
  PDir := FNodes[Node].Dir;
  if not Src.GetObjects(X, Y, SrcList) then SrcList.Count := 0;

  for k := 0 to 7 do
  begin
    d := Order[k];
    Ok[d] := False;
    NX := X + DirX[d];
    NY := Y + DirY[d];
    if Blocked(NX, NY) then Continue;
    if Odd(d) and not (Ok[(d + 1) and 7] and Ok[(d - 1) and 7]) then Continue;
    if not Src.GetObjects(NX, NY, DestList) then Continue;
    CalcMinMaxZ(SrcList, Z, d, MinZ, MaxZ);
    NZ := Z;
    if not CalcNewZ(DestList, MinZ, MaxZ, NZ) then Continue;
    Ok[d] := True;
    NewZ[d] := NZ;
  end;

  for d := 0 to 7 do
    if Ok[d] then
    begin
      Cost := PATH_STEP_COST + AvoidCost(X + DirX[d], Y + DirY[d]) +
        Src.CellCost(X + DirX[d], Y + DirY[d]);
      if (PDir >= 0) and (PDir <= 7) and (PDir <> d) then Inc(Cost, TurnCost);
      Relax(X + DirX[d], Y + DirY[d], NewZ[d], d, Node, Cost);
    end;

  for i := 0 to High(FLnk) do
    if (FLnk[i].X1 = X) and (FLnk[i].Y1 = Y) and (Abs(Z - FLnk[i].Z1) <= LINK_Z_RANGE) then
      Relax(FLnk[i].X2, FLnk[i].Y2, FLnk[i].Z2, PATH_DIR_LINK, Node, FLnk[i].Cost);
end;

procedure TPathPlanner.Reconstruct(Goal : Integer);
var
  n, i : Integer;
begin
  StepCount := 0;
  n := Goal;
  while FNodes[n].Parent >= 0 do
  begin
    Inc(StepCount);
    n := FNodes[n].Parent;
  end;
  SetLength(Steps, StepCount);
  n := Goal;
  for i := StepCount-1 downto 0 do
  begin
    Steps[i].X := FNodes[n].X;
    Steps[i].Y := FNodes[n].Y;
    Steps[i].Z := FNodes[n].Z;
    Steps[i].Dir := FNodes[n].Dir;
    n := FNodes[n].Parent;
  end;
end;

// The rules of this facet only, and the search box around start and goal, widened for every
// link that starts inside it.
procedure TPathPlanner.PrepareRules(Facet, SX, SY : Integer);
var
  i       : Integer;
  Changed : Boolean;
begin
  SetLength(FBlk, 0);
  SetLength(FAvd, 0);
  SetLength(FLnk, 0);
  for i := 0 to High(Blocks) do
    if Blocks[i].Facet = Facet then
    begin
      SetLength(FBlk, Length(FBlk) + 1);
      FBlk[High(FBlk)] := Blocks[i];
    end;
  for i := 0 to High(Avoids) do
    if Avoids[i].Facet = Facet then
    begin
      SetLength(FAvd, Length(FAvd) + 1);
      FAvd[High(FAvd)] := Avoids[i];
    end;
  for i := 0 to High(Links) do
    if Links[i].Facet = Facet then
    begin
      SetLength(FLnk, Length(FLnk) + 1);
      FLnk[High(FLnk)] := Links[i];
    end;

  FBX1 := SX;
  FBX2 := SX;
  FBY1 := SY;
  FBY2 := SY;
  if FGX < FBX1 then FBX1 := FGX;
  if FGX > FBX2 then FBX2 := FGX;
  if FGY < FBY1 then FBY1 := FGY;
  if FGY > FBY2 then FBY2 := FGY;
  Dec(FBX1, Margin);
  Dec(FBY1, Margin);
  Inc(FBX2, Margin);
  Inc(FBY2, Margin);
  repeat
    Changed := False;
    for i := 0 to High(FLnk) do
      with FLnk[i] do
        if (X1 >= FBX1) and (X1 <= FBX2) and (Y1 >= FBY1) and (Y1 <= FBY2) then
        begin
          if X2 - Margin < FBX1 then begin FBX1 := X2 - Margin; Changed := True; end;
          if X2 + Margin > FBX2 then begin FBX2 := X2 + Margin; Changed := True; end;
          if Y2 - Margin < FBY1 then begin FBY1 := Y2 - Margin; Changed := True; end;
          if Y2 + Margin > FBY2 then begin FBY2 := Y2 + Margin; Changed := True; end;
        end;
  until not Changed;
end;

function TPathPlanner.Find(Src : TWalkSource; Facet, SX, SY, SZ, SDir, GX, GY, GZ : Integer;
  HasGZ : Boolean; Stop : PBoolean) : TPathResult;
var
  Start, Node, F : Integer;
  T0             : QWord;
  TZ             : Integer;
begin
  StepCount := 0;
  SetLength(Steps, 0);
  StartX := SX;
  StartY := SY;
  StartZ := SZ;
  StartFacet := Facet;
  Expanded := 0;
  GoalNear := False;
  FNodeCount := 0;
  FHeapCount := 0;
  if Length(FHash) = 0 then Rehash(1 shl 16)
  else FillDWord(FHash[0], Length(FHash), $FFFFFFFF);

  FGX := GX;
  FGY := GY;
  FGZ := GZ;
  FHasGZ := HasGZ;
  FAcc := AccuracyXY;
  if FAcc < 0 then FAcc := 0;
  PrepareRules(Facet, SX, SY);

  // Nothing to stand on at the goal: arrive next to it instead.
  if FAcc = 0 then
  begin
    if HasGZ then TZ := GZ else TZ := SZ;
    if Blocked(GX, GY) or not StandZ(Src, GX, GY, TZ) then
    begin
      FAcc := 1;
      GoalNear := True;
    end;
  end;

  Start := AddNode(SX, SY, SZ);
  FNodes[Start].G := 0;
  FNodes[Start].H := Heur(SX, SY);
  FNodes[Start].Parent := -1;
  if (SDir >= 0) and (SDir <= 7) then FNodes[Start].Dir := SDir
  else FNodes[Start].Dir := -1;
  Push(FNodes[Start].H, Start);

  T0 := GetTickCount64;
  Result := prNoPath;
  while Pop(Node, F) do
  begin
    if FNodes[Node].Closed or (F <> FNodes[Node].G + FNodes[Node].H) then Continue;   // stale
    FNodes[Node].Closed := True;
    if AtGoal(FNodes[Node]) then
    begin
      Reconstruct(Node);
      Exit(prOk);
    end;

    Inc(Expanded);
    if Expanded > MaxNodes then Exit(prBudget);
    if (Expanded and 1023) = 0 then
    begin
      if (Stop <> nil) and Stop^ then Exit(prStopped);
      if GetTickCount64 - T0 > QWord(TimeoutMs) then Exit(prTimeout);
    end;
    Expand(Src, Node);
  end;
end;

end.
