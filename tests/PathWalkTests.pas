unit PathWalkTests;

{ FPCUnit tests for uo\pathwalk.pas, the pathfinder's walker, without a game client:
  - ClientSearch, the client's own pathfinder as read from its code (budget, height, one tile off);
  - WaypointCandidate, how far ahead a waypoint may be (distance, lead, links, doors);
  - whole walks against TSimClient, a simulated client on a synthetic grid (WalkGridSource). The
    simulation keeps the true world (Truth: the grid plus every object, doors shut) apart from what
    it shows the walker (Visible), so a test can hide a wall, refuse far waypoints, open a door,
    move a creature into the way or teleport. Its PathFind runs ClientSearch on the true world, as
    the real client does on what it has loaded, then walks the result one step every StepMs. Its
    CheckSteps (CheckOn) answers the client's step check from the true world, as the client's own
    CalculateNewZ does.
    Time is simulated: Wait advances it, so a walk of minutes takes milliseconds. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fpcunit, testregistry, walkrules, walklive, pathplan, pathwalk,
  WalkGridSource;

const
  W_WALL = 100;   // the made-up tiledata, as in WalkLiveTests
  W_DOOR = 102;
  W_RAMP = 103;   // stairs the walker can't see: a bridge 8 high, stood on half way up

type
  TSimClient = class(TWalkClient)
  private
    procedure MoveTo(NX, NY, NZ, D : Integer);
    procedure Advance;
  public
    Truth        : TLiveOverlay;
    Visible      : TLiveObjs;
    Hidden       : TLiveObjs;
    X, Y, Z, Dir : Integer;
    T            : QWord;
    StepMs       : Cardinal;
    Queue        : TPathSteps;
    QPos         : Integer;
    NextAt       : QWord;
    Refused      : Boolean;
    PendingDir   : Integer;    // a walk-macro step waiting for the one before to end, -1 = none
    StepFree     : QWord;      // when the character can step again
    AcceptDist   : Integer;    // a PathFind farther than this is refused (0 = any)
    StallAfter   : Integer;    // a PathFind walk ends after this many steps (0 = never), as on the beta
    Deaf         : Boolean;    // PathFind is taken without a word, and nothing happens
    BounceX      : Integer;    // a step onto this tile is shown, then the server puts the
    BounceY      : Integer;    //   character back (-1 = none)
    BackAt       : QWord;      // when it is put back, 0 = not pending
    BackX, BackY : Integer;
    TrapX        : Integer;    // any tile in this column sends the character back to its start
    StartX       : Integer;
    StartY       : Integer;
    StopAfter    : Integer;    // Wait says "stopped" on this call (0 = never)
    Waits        : Integer;
    PathFinds    : Integer;
    StepsSent    : Integer;
    BlockedSteps : Integer;    // steps the true world refused
    DoorsOpened  : Integer;
    Refusals     : Integer;
    MaxWpDist    : Integer;    // the farthest PathFind target from the character
    TeleX, TeleY : Integer;    // a teleporter: stepping on it lands on TeleX2,TeleY2 (-1 = none)
    TeleX2       : Integer;
    TeleY2       : Integer;
    SpawnAt      : QWord;      // at this time Spawn appears (0 = never)
    Spawn        : TLiveObj;
    Visits       : TStringList;
    CheckOn      : Boolean;    // CheckSteps answers (else it can't be asked)
    CheckBlind   : Boolean;    // ... and refuses everything, the character's own tile included
    Checks       : Integer;    // CheckSteps calls
    MaxCheckDist : Integer;    // the farthest tile asked about from the character
    Asked        : TStringList;   // every tile asked about, as x,y
    constructor Create(Grid : TWalkSource; Info : TTileInfoFunc; SX, SY : Integer);
    destructor  Destroy; override;
    procedure Rebuild;
    procedure AddVisible(const O : TLiveObj);
    procedure AddHidden(const O : TLiveObj);
    function  Visited(VX, VY : Integer) : Boolean;
    function  Position(out PX, PY, PZ, PDir, Facet : Integer) : Boolean; override;
    procedure PathFind(TX, TY, TZ : Integer); override;
    procedure Step(D : Integer); override;
    procedure OpenDoor; override;
    procedure MarkJournal; override;
    function  CantGetThere : Boolean; override;
    procedure LiveObjects(LX, LY : Integer; var Objs : TLiveObjs); override;
    function  CheckSteps(var Q : TStepChecks) : Boolean; override;
    function  Now : QWord; override;
    function  Wait(Ms : Cardinal) : Boolean; override;
  end;

  TPathWalkTests = class(TTestCase)
  private
    G  : TGridSource;
    Ov : TLiveOverlay;
    P  : TPathPlanner;
    W  : TPathWalker;
    C  : TSimClient;
    Lines : TStringList;
    procedure Collect(const Line : String);
    function  Info(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
    function  Item(X, Y, Graphic : Integer; Kind : TLiveKind = lkItem) : TLiveObj;
    procedure Sim(SX, SY : Integer);
    function  Walk(GX, GY : Integer; Mode : TWalkMode; TimeoutMs : Cardinal = 600000) : TWalkState;
    function  Straight(N : Integer) : TPathSteps;
    function  Logged(const S : String) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestClientSearchFindsStraightPath;
    procedure TestClientSearchRunsOutOfBudget;
    procedure TestClientSearchHeightTolerance;
    procedure TestClientSearchOneTileOff;
    procedure TestWaypointWithinMaxDist;
    procedure TestWaypointWithinLead;
    procedure TestWaypointStopsBeforeLinkAndDoor;
    procedure TestWaypointNoneWhenTooFar;
    procedure TestAlreadyThereArrives;
    procedure TestStepsModeWalksThere;
    procedure TestClientModeWalksThere;
    procedure TestClientRefusalsBringWaypointsNearer;
    procedure TestRefusedStepBecomesLearnedBlock;
    procedure TestClientStopsOneShortOfHiddenBlock;
    procedure TestReplansWhenSomethingAppearsAhead;
    procedure TestOpensDoor;
    procedure TestOpensDoorInClientMode;
    procedure TestTeleporterLink;
    procedure TestGateLinkStopsWithLink;
    procedure TestTimeout;
    procedure TestStopFromWait;
    procedure TestBoxedInEnds;
    procedure TestWalkOnPlanFindsCharacterOnRoute;
    procedure TestLogSaysWhatHappened;
    procedure TestClientWalkEndingEarlyIsNotARefusal;
    procedure TestStoppedNextToWaypointStepsOntoIt;
    procedure TestClientThatNeverStartsGetsSteps;
    procedure TestTilePutBackOffIsLearned;
    procedure TestNoProgressEndsTheWalk;
    procedure TestAutoModeWalksInSteps;
    procedure TestFacingDoesNotBendTheRoute;
    // the client check (phase 3)
    procedure TestClientCheckLearnsHiddenWallBeforeStepping;
    procedure TestClientCheckLearnsAHiddenHouseInFewReplans;
    procedure TestClientCheckRefusesADiagonalByItsFlank;
    procedure TestClientCheckLeavesADoorToOpen;
    procedure TestClientCheckLeavesAMobile;
    procedure TestClientCheckDroppedWhenOwnTileRefused;
    procedure TestClientCheckWithoutAnswerChangesNothing;
    procedure TestClientCheckStaysWithinCheckDist;
    procedure TestClientCheckNeverAsksAcrossALink;
    procedure TestClientCheckTakesTheClientsHeight;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TSimClient.Create(Grid : TWalkSource; Info : TTileInfoFunc; SX, SY : Integer);
begin
  inherited Create;
  Truth := TLiveOverlay.Create;
  Truth.Base := Grid;
  Truth.TileInfo := Info;
  Truth.SelfID := 1;
  Truth.OpenDoors := False;   // a shut door is shut
  X := SX;
  Y := SY;
  StepMs := 200;
  PendingDir := -1;
  TeleX := -1;
  BounceX := -1;
  TrapX := -1;
  StartX := SX;
  StartY := SY;
  Visits := TStringList.Create;
  Visits.Sorted := True;
  Visits.Duplicates := dupIgnore;
  Asked := TStringList.Create;
  Asked.Sorted := True;
  Asked.Duplicates := dupIgnore;
end;

destructor TSimClient.Destroy;
begin
  Visits.Free;
  Asked.Free;
  Truth.Free;
  inherited Destroy;
end;

procedure TSimClient.Rebuild;
var
  All : TLiveObjs;
  i   : Integer;
begin
  SetLength(All, Length(Visible) + Length(Hidden));
  for i := 0 to High(Visible) do All[i] := Visible[i];
  for i := 0 to High(Hidden) do All[Length(Visible) + i] := Hidden[i];
  Truth.SetObjects(All);
end;

procedure TSimClient.AddVisible(const O : TLiveObj);
begin
  SetLength(Visible, Length(Visible) + 1);
  Visible[High(Visible)] := O;
  Rebuild;
end;

procedure TSimClient.AddHidden(const O : TLiveObj);
begin
  SetLength(Hidden, Length(Hidden) + 1);
  Hidden[High(Hidden)] := O;
  Rebuild;
end;

function TSimClient.Visited(VX, VY : Integer) : Boolean;
begin
  Result := Visits.IndexOf(Format('%d,%d', [VX, VY])) >= 0;
end;

procedure TSimClient.MoveTo(NX, NY, NZ, D : Integer);
begin
  if (NX = BounceX) and (NY = BounceY) then
  begin
    BackX := X;
    BackY := Y;
    BackAt := T + StepMs;
  end;
  if NX = TrapX then
  begin
    NX := StartX;
    NY := StartY;
    SetLength(Queue, 0);
  end;
  X := NX;
  Y := NY;
  Z := NZ;
  Dir := D;
  Visits.Add(Format('%d,%d', [X, Y]));
  if (X = TeleX) and (Y = TeleY) then
  begin
    X := TeleX2;
    Y := TeleY2;
    SetLength(Queue, 0);
  end;
end;

procedure TSimClient.Advance;
var
  NZ, D : Integer;
begin
  if (SpawnAt > 0) and (T >= SpawnAt) then
  begin
    SpawnAt := 0;
    AddVisible(Spawn);
  end;
  if (BackAt > 0) and (T >= BackAt) then
  begin
    BackAt := 0;
    X := BackX;
    Y := BackY;
    SetLength(Queue, 0);
    PendingDir := -1;
  end;
  // A walk-macro step: a new direction only turns the character, as in the client.
  if (PendingDir >= 0) and (T >= StepFree) then
  begin
    D := PendingDir;
    PendingDir := -1;
    if D <> Dir then
    begin
      Dir := D;
      StepFree := T + StepMs div 2;
    end
    else if CanStep(Truth, X, Y, Z, D, NZ) then
    begin
      MoveTo(X + DirX[D], Y + DirY[D], NZ, D);
      StepFree := T + StepMs;
    end
    else Inc(BlockedSteps);
  end;
  while (QPos < Length(Queue)) and (T >= NextAt) do
  begin
    if CanStep(Truth, X, Y, Z, Queue[QPos].Dir, NZ) then
    begin
      MoveTo(Queue[QPos].X, Queue[QPos].Y, NZ, Queue[QPos].Dir);
      Inc(QPos);
    end
    else SetLength(Queue, 0);
    NextAt := NextAt + StepMs;
  end;
end;

function TSimClient.Position(out PX, PY, PZ, PDir, Facet : Integer) : Boolean;
begin
  PX := X;
  PY := Y;
  PZ := Z;
  PDir := Dir;
  Facet := 0;
  Result := True;
end;

procedure TSimClient.PathFind(TX, TY, TZ : Integer);
var
  D : Integer;
begin
  Inc(PathFinds);
  D := Max(Abs(TX - X), Abs(TY - Y));
  if D > MaxWpDist then MaxWpDist := D;
  SetLength(Queue, 0);
  QPos := 0;
  if Deaf then Exit;
  if ((AcceptDist = 0) or (D <= AcceptDist)) and
    (ClientSearch(Truth, X, Y, Z, TX, TY, TZ, CLIENT_SEARCH_POPS, 0, @Queue) or
     ClientSearch(Truth, X, Y, Z, TX, TY, TZ, CLIENT_SEARCH_POPS, 1, @Queue)) then
  begin
    NextAt := T + StepMs;
    if (StallAfter > 0) and (Length(Queue) > StallAfter) then SetLength(Queue, StallAfter);
  end
  else
  begin
    Refused := True;
    Inc(Refusals);
  end;
end;

// Taken at once when the character is free, else when the step under way ends (Advance).
procedure TSimClient.Step(D : Integer);
begin
  Inc(StepsSent);
  SetLength(Queue, 0);
  PendingDir := D;
  Advance;
end;

// The door in front of the character opens: it is gone from the doorway.
procedure TSimClient.OpenDoor;
var
  i, n, FX, FY : Integer;
begin
  Inc(DoorsOpened);
  FX := X + DirX[Dir];
  FY := Y + DirY[Dir];
  n := 0;
  for i := 0 to High(Visible) do
    if not ((Visible[i].X = FX) and (Visible[i].Y = FY) and (Visible[i].Graphic = W_DOOR)) then
    begin
      Visible[n] := Visible[i];
      Inc(n);
    end;
  SetLength(Visible, n);
  Rebuild;
end;

procedure TSimClient.MarkJournal;
begin
  Refused := False;
end;

function TSimClient.CantGetThere : Boolean;
begin
  Result := Refused;
  Refused := False;
end;

procedure TSimClient.LiveObjects(LX, LY : Integer; var Objs : TLiveObjs);
begin
  Objs := Copy(Visible, 0, Length(Visible));
end;

function TSimClient.CheckSteps(var Q : TStepChecks) : Boolean;
var
  i, NZ : Integer;
begin
  Inc(Checks);
  Result := CheckOn;
  if not Result then Exit;
  for i := 0 to High(Q) do
  begin
    MaxCheckDist := Max(MaxCheckDist, Max(Abs(Q[i].X - X), Abs(Q[i].Y - Y)));
    Asked.Add(Format('%d,%d', [Q[i].X, Q[i].Y]));
    NZ := Q[i].Z;
    if CheckBlind or not CalculateNewZ(Truth, Q[i].X, Q[i].Y, NZ, Q[i].Dir) then NZ := -128;
    Q[i].NewZ := NZ;
  end;
end;

function TSimClient.Now : QWord;
begin
  Result := T;
end;

function TSimClient.Wait(Ms : Cardinal) : Boolean;
begin
  Inc(Waits);
  if (StopAfter > 0) and (Waits >= StopAfter) then Exit(False);
  Inc(T, Ms);
  Advance;
  Result := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPathWalkTests.SetUp;
begin
  G := TGridSource.Create(64, 64);
  Ov := TLiveOverlay.Create;
  Ov.Base := G;
  Ov.TileInfo := @Info;
  Ov.SelfID := 1;
  P := TPathPlanner.Create;
  W := TPathWalker.Create(P, Ov);
  C := nil;
  Lines := TStringList.Create;
end;

procedure TPathWalkTests.TearDown;
begin
  Lines.Free;
  C.Free;
  W.Free;
  P.Free;
  Ov.Free;
  G.Free;
end;

procedure TPathWalkTests.Collect(const Line : String);
begin
  Lines.Add(Line);
end;

function TPathWalkTests.Info(Graphic : Integer; out Flags : Cardinal; out Height : Integer) : Boolean;
begin
  Result := True;
  Height := 20;
  case Graphic of
    W_WALL : Flags := TDF_IMPASSABLE;
    W_DOOR : Flags := TDF_IMPASSABLE or TDF_DOOR;
    W_RAMP : begin
               Flags := TDF_SURFACE or TDF_BRIDGE;
               Height := 8;
             end;
  else
    Flags := 0;
    Height := 0;
    Result := False;
  end;
end;

function TPathWalkTests.Item(X, Y, Graphic : Integer; Kind : TLiveKind) : TLiveObj;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := 0;
  Result.Graphic := Graphic;
  Result.Kind := Kind;
  Result.ID := $40000000 + Cardinal(Y*64 + X);
  if Kind = lkMobile then Result.ID := 1000 + Cardinal(Y*64 + X);
end;

procedure TPathWalkTests.Sim(SX, SY : Integer);
begin
  C := TSimClient.Create(G, @Info, SX, SY);
end;

function TPathWalkTests.Walk(GX, GY : Integer; Mode : TWalkMode; TimeoutMs : Cardinal) : TWalkState;
begin
  W.Mode := Mode;
  if not W.Start(C, GX, GY, 0, False, 0, False) then Exit(W.State);
  Result := W.Run(C, TimeoutMs);
end;

// A route due east from 0,10, N steps long.
function TPathWalkTests.Straight(N : Integer) : TPathSteps;
var
  i : Integer;
begin
  SetLength(Result, N);
  for i := 0 to N-1 do
  begin
    Result[i].X := i + 1;
    Result[i].Y := 10;
    Result[i].Z := 0;
    Result[i].Dir := 2;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPathWalkTests.TestClientSearchFindsStraightPath;
var
  Path : TPathSteps;
begin
  AssertTrue(ClientSearch(G, 5, 5, 0, 15, 5, 0, CLIENT_SEARCH_POPS, 0, @Path));
  AssertEquals(10, Length(Path));
  AssertEquals(15, Path[9].X);
  AssertEquals(5, Path[9].Y);
  AssertEquals(2, Path[0].Dir);
end;

// A long wall between start and goal: the straight line leads into a pocket, and finding the way
// round takes more than the client's 500 positions, though not more than its hard 5000.
procedure TPathWalkTests.TestClientSearchRunsOutOfBudget;
begin
  G.AddStaticRect(20, 0, 20, 58, 0, 20, TDF_IMPASSABLE);
  AssertFalse('"Can''t get there"', ClientSearch(G, 10, 30, 0, 30, 30, 0, CLIENT_SEARCH_POPS, 0, nil));
  AssertTrue('a bigger budget finds it', ClientSearch(G, 10, 30, 0, 30, 30, 0, CLIENT_SEARCH_CAP, 0, nil));
end;

procedure TPathWalkTests.TestClientSearchHeightTolerance;
begin
  AssertTrue('8 off is close enough', ClientSearch(G, 5, 5, 0, 10, 5, 8, CLIENT_SEARCH_POPS, 0, nil));
  AssertFalse('9 is not', ClientSearch(G, 5, 5, 0, 10, 5, 9, CLIENT_SEARCH_POPS, 0, nil));
end;

procedure TPathWalkTests.TestClientSearchOneTileOff;
var
  Path : TPathSteps;
begin
  G.AddStatic(10, 5, 0, 20, TDF_IMPASSABLE);
  AssertFalse(ClientSearch(G, 5, 5, 0, 10, 5, 0, CLIENT_SEARCH_POPS, 0, nil));
  AssertTrue(ClientSearch(G, 5, 5, 0, 10, 5, 0, CLIENT_SEARCH_POPS, 1, @Path));
  AssertEquals('it stops next to the tile', 1,
    Max(Abs(Path[High(Path)].X - 10), Abs(Path[High(Path)].Y - 5)));
end;

procedure TPathWalkTests.TestWaypointWithinMaxDist;
begin
  // from the start (0,10), step i is i+1 tiles away
  AssertEquals('step 18 is 18 tiles away, step 19 too far', 17,
    WaypointCandidate(Straight(40), -1, 0, 10, 36, 18, nil));
  AssertEquals('from step 9, with the character there', 27,
    WaypointCandidate(Straight(40), 9, 10, 10, 36, 18, nil));
  AssertEquals('the end of a short route', 4, WaypointCandidate(Straight(5), -1, 0, 10, 36, 18, nil));
end;

procedure TPathWalkTests.TestWaypointWithinLead;
begin
  AssertEquals(4, WaypointCandidate(Straight(40), -1, 0, 10, 5, 18, nil));
  AssertEquals(12, WaypointCandidate(Straight(40), 10, 11, 10, 2, 18, nil));
end;

procedure TPathWalkTests.TestWaypointStopsBeforeLinkAndDoor;
var
  S : TPathSteps;
  L : TLiveObjs;
begin
  S := Straight(40);
  S[6].Dir := PATH_DIR_LINK;
  AssertEquals('stand on the link''s start', 5, WaypointCandidate(S, -1, 0, 10, 36, 18, nil));
  S := Straight(40);
  SetLength(L, 1);
  L[0] := Item(9, 10, W_DOOR);
  Ov.SetObjects(L);
  AssertEquals('stop before the door', 7, WaypointCandidate(S, -1, 0, 10, 36, 18, Ov));
  AssertEquals('none: the door is next', 7, WaypointCandidate(S, 7, 8, 10, 36, 18, Ov));
end;

procedure TPathWalkTests.TestWaypointNoneWhenTooFar;
begin
  AssertEquals(3, WaypointCandidate(Straight(40), 3, 30, 40, 36, 18, nil));
end;

procedure TPathWalkTests.TestAlreadyThereArrives;
begin
  Sim(10, 10);
  AssertTrue(Walk(10, 10, wmSteps) = wsArrived);
  AssertEquals(0, C.StepsSent);
end;

procedure TPathWalkTests.TestStepsModeWalksThere;
begin
  Sim(5, 5);
  AssertTrue(Walk(20, 9, wmSteps) = wsArrived);
  AssertEquals(20, C.X);
  AssertEquals(9, C.Y);
  AssertEquals(0, C.PathFinds);
  AssertEquals(0, C.BlockedSteps);
end;

procedure TPathWalkTests.TestClientModeWalksThere;
begin
  G.AddStaticRect(10, 0, 10, 50, 0, 20, TDF_IMPASSABLE);
  G.AddStaticRect(30, 13, 30, 63, 0, 20, TDF_IMPASSABLE);
  Sim(2, 2);
  AssertTrue(Walk(60, 60, wmClient) = wsArrived);
  AssertEquals(60, C.X);
  AssertEquals(60, C.Y);
  AssertTrue('several waypoints', C.PathFinds >= 4);
  AssertTrue('each within 18 tiles', C.MaxWpDist <= 18);
  AssertEquals('the client took every one', 0, C.Refusals);
  AssertTrue(W.ClientMode);
end;

// A client that refuses anything farther than 6 tiles: the waypoints come nearer until it takes them.
procedure TPathWalkTests.TestClientRefusalsBringWaypointsNearer;
begin
  Sim(5, 30);
  C.AcceptDist := 6;
  AssertTrue(Walk(55, 30, wmClient) = wsArrived);
  AssertEquals(55, C.X);
  AssertTrue('refused at first', C.Refusals >= 3);
  AssertTrue('the lead came down', W.Lead < 36);
end;

// A wall the walker can't see: the step into it is refused, its cell learned, the route replanned.
procedure TPathWalkTests.TestRefusedStepBecomesLearnedBlock;
begin
  Sim(5, 5);
  C.AddHidden(Item(12, 5, W_WALL));
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertEquals(20, C.X);
  AssertTrue(Ov.IsLearned(0, 12, 5));
  AssertTrue(W.Replans >= 1);
  AssertFalse(C.Visited(12, 5));
end;

// The client walks to the tile next to a waypoint it can't reach, silently: the walker learns
// the waypoint's cell. Here that is the goal, so the walk ends next to it.
procedure TPathWalkTests.TestClientStopsOneShortOfHiddenBlock;
begin
  Sim(5, 5);
  C.AddHidden(Item(12, 5, W_WALL));
  AssertTrue(Walk(12, 5, wmClient) = wsArrived);
  AssertTrue(Ov.IsLearned(0, 12, 5));
  AssertEquals('next to the goal', 1, Max(Abs(C.X - 12), Abs(C.Y - 5)));
end;

// A creature steps onto the route ahead: the next refresh sees it and the walker goes round it,
// without ever being refused.
procedure TPathWalkTests.TestReplansWhenSomethingAppearsAhead;
begin
  Sim(5, 30);
  C.Spawn := Item(28, 30, 0, lkMobile);
  C.SpawnAt := 2000;
  AssertEquals('arrived', 'arrived', WalkStateName(Walk(45, 30, wmSteps)));
  AssertEquals(45, C.X);
  AssertTrue('replanned', W.Replans >= 1);
  AssertEquals('it never walked into it', 0, C.BlockedSteps);
  AssertFalse(C.Visited(28, 30));
end;

procedure TPathWalkTests.TestOpensDoor;
begin
  G.AddStaticRect(15, 0, 15, 4, 0, 20, TDF_IMPASSABLE);
  G.AddStaticRect(15, 6, 15, 63, 0, 20, TDF_IMPASSABLE);
  Sim(10, 5);
  C.AddVisible(Item(15, 5, W_DOOR));
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertEquals(20, C.X);
  AssertEquals(1, C.DoorsOpened);
end;

procedure TPathWalkTests.TestOpensDoorInClientMode;
begin
  G.AddStaticRect(15, 0, 15, 4, 0, 20, TDF_IMPASSABLE);
  G.AddStaticRect(15, 6, 15, 63, 0, 20, TDF_IMPASSABLE);
  Sim(5, 5);
  C.AddVisible(Item(15, 5, W_DOOR));
  AssertTrue(Walk(30, 5, wmClient) = wsArrived);
  AssertEquals(30, C.X);
  AssertEquals(1, C.DoorsOpened);
  AssertEquals('no waypoint past the shut door', 0, C.Refusals);
end;

procedure TPathWalkTests.TestTeleporterLink;
begin
  G.AddStaticRect(20, 0, 20, 63, 0, 20, TDF_IMPASSABLE);
  P.AddLink(0, 18, 5, 0, 22, 5, 0, PATH_STEP_COST);
  Sim(10, 5);
  C.TeleX := 18;
  C.TeleY := 5;
  C.TeleX2 := 22;
  C.TeleY2 := 5;
  AssertTrue(Walk(30, 5, wmSteps) = wsArrived);
  AssertEquals(30, C.X);
end;

// A gate or a ladder the walker can't use: it stops on the link's start; the script uses it and
// walks on.
procedure TPathWalkTests.TestGateLinkStopsWithLink;
begin
  G.AddStaticRect(20, 0, 20, 63, 0, 20, TDF_IMPASSABLE);
  P.AddLink(0, 18, 5, 0, 22, 5, 0, PATH_STEP_COST);
  Sim(10, 5);
  AssertTrue(Walk(30, 5, wmClient) = wsLink);
  AssertEquals(18, C.X);
  AssertEquals(5, C.Y);
  C.X := 22;                         // the script used the gate
  AssertTrue(W.Start(C, 30, 5, 0, False, 0, True));
  AssertTrue(W.Run(C, 600000) = wsArrived);
  AssertEquals(30, C.X);
end;

procedure TPathWalkTests.TestTimeout;
begin
  Sim(2, 2);
  AssertTrue(Walk(60, 60, wmSteps, 500) = wsTimeout);
end;

procedure TPathWalkTests.TestStopFromWait;
begin
  Sim(2, 2);
  C.StopAfter := 5;
  AssertTrue(Walk(60, 60, wmSteps) = wsStopped);
end;

// Walls the walker can't see on every side: it learns them one by one, then has no route.
procedure TPathWalkTests.TestBoxedInEnds;
var
  d : Integer;
begin
  Sim(30, 30);
  for d := 0 to 7 do C.AddHidden(Item(30 + DirX[d], 30 + DirY[d], W_WALL));
  AssertTrue(Walk(40, 30, wmSteps) in [wsBlocked, wsFailed]);
  AssertTrue(Ov.LearnedCount >= 4);
end;

procedure TPathWalkTests.TestWalkOnPlanFindsCharacterOnRoute;
begin
  AssertTrue(P.Find(Ov, 0, 5, 5, 0, -1, 40, 5, 0, False, nil) = prOk);
  Sim(15, 5);
  AssertTrue(W.Start(C, 40, 5, 0, False, 0, True));
  AssertEquals('x 15 is step 10', 9, W.Index);
  AssertTrue(W.Run(C, 600000) = wsArrived);
  AssertEquals(40, C.X);
end;

// path set log: a line for each decision, with the time since the walk started.
procedure TPathWalkTests.TestLogSaysWhatHappened;

  function Has(const S : String) : Boolean;
  var
    i : Integer;
  begin
    Result := False;
    for i := 0 to Lines.Count-1 do
      if Pos(S, Lines[i]) > 0 then Exit(True);
  end;

begin
  Sim(5, 5);
  C.AddHidden(Item(12, 5, W_WALL));
  W.OnLog := @Collect;
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  if GetEnvironmentVariable('PATHWALK_LOG') <> '' then WriteLn(Lines.Text);
  AssertTrue(Lines[0], Has('start at 5,5,0 to 20,5 (acc 0), steps mode'));
  AssertTrue('the refused step', Has('step 7 refused: learned 12,5'));
  AssertTrue('the replan', Has('full plan from 11,5,0: ok'));
  AssertTrue('the end', Has('end: arrived at 20,5,0'));
  AssertEquals('the time first, in ms', '     0  full plan from 5,5,0: ok, 15 steps', Lines[0]);
end;

// The beta's own walk ends after a handful of steps: fresh waypoints keep it going, and an early end
// neither shrinks the lead nor makes a learned block.
procedure TPathWalkTests.TestClientWalkEndingEarlyIsNotARefusal;
begin
  Sim(5, 30);
  C.StallAfter := 5;
  AssertTrue(Walk(55, 30, wmClient) = wsArrived);
  AssertEquals(55, C.X);
  AssertEquals(30, C.Y);
  AssertEquals('no refusals', 0, C.Refusals);
  AssertEquals('no learned blocks', 0, Ov.LearnedCount);
  AssertEquals('the lead never shrank', 36, W.Lead);
  AssertTrue('a waypoint every few steps', C.PathFinds >= 10);
  AssertTrue('50 steps of 200 ms, without stopping: ' + IntToStr(C.T) + ' ms', C.T < 11500);
end;

// The walk ends one tile before the waypoint, here the goal: the walker takes that step itself.
// (EndSteps 1 here: stopping next to the waypoint is the case that matters.)
procedure TPathWalkTests.TestStoppedNextToWaypointStepsOntoIt;
begin
  Sim(5, 30);
  C.StallAfter := 5;
  W.KeepAliveSteps := 1000;
  W.EndSteps := 1;
  AssertTrue(Walk(11, 30, wmClient) = wsArrived);
  AssertEquals('on the goal itself', 11, C.X);
  AssertEquals(0, Ov.LearnedCount);
  AssertTrue('one step with the walk macro', C.StepsSent >= 1);
end;

// A client that takes every PathFind and never walks: after one wait, the walker steps.
procedure TPathWalkTests.TestClientThatNeverStartsGetsSteps;
begin
  Sim(5, 30);
  C.Deaf := True;
  AssertTrue(Walk(15, 30, wmClient) = wsArrived);
  AssertEquals(15, C.X);
  AssertEquals('one waypoint, then steps', 1, C.PathFinds);
  AssertTrue('without trying nearer ones first: ' + IntToStr(C.T) + ' ms', C.T < 5000);
end;

// The server refuses a step the client has already shown and puts the character back: after the
// second time, the tile is a learned block and the walk goes round it. As walked live near a house.
procedure TPathWalkTests.TestTilePutBackOffIsLearned;
var
  S : TWalkState;
begin
  Sim(5, 30);
  C.BounceX := 15;
  C.BounceY := 30;
  W.OnLog := @Collect;
  S := Walk(25, 30, wmClient);
  if GetEnvironmentVariable('PATHWALK_LOG') <> '' then WriteLn(Lines.Text);
  AssertEquals('arrived', 'arrived', WalkStateName(S));
  AssertEquals(25, C.X);
  AssertTrue(Ov.IsLearned(0, 15, 30));
end;

// A column that sends the character back to its start whenever it gets there: the walk keeps
// moving, but never gets closer than that column, so it ends.
procedure TPathWalkTests.TestNoProgressEndsTheWalk;
begin
  Sim(5, 30);
  C.TrapX := 15;
  AssertTrue(Walk(25, 30, wmSteps) in [wsFailed, wsBlocked]);
  AssertTrue('in reasonable time: ' + IntToStr(C.T) + ' ms', C.T < 120000);
end;

// The default: single steps, even where the client's pathfinder is known.
procedure TPathWalkTests.TestAutoModeWalksInSteps;
begin
  Sim(5, 30);
  AssertTrue(Walk(15, 30, wmAuto) = wsArrived);
  AssertFalse(W.ClientMode);
  AssertEquals(0, C.PathFinds);
  AssertEquals(15, C.X);
end;

// Facing south-east, 22 tiles due east: a straight line, not 11 + 11 diagonal steps (as walked live
// before the facing was left out of the plan).
procedure TPathWalkTests.TestFacingDoesNotBendTheRoute;
var
  i : Integer;
begin
  Sim(5, 30);
  C.Dir := 3;
  W.Mode := wmSteps;
  AssertTrue(W.Start(C, 27, 30, 0, False, 0, False));
  AssertEquals(22, Length(W.Steps));
  for i := 0 to High(W.Steps) do
    AssertEquals('step ' + IntToStr(i + 1) + ' east', 2, W.Steps[i].Dir);
end;

////////////////////////////////////////////////////////////////////////////////
// The client check (phase 3).

function TPathWalkTests.Logged(const S : String) : Boolean;
var
  i : Integer;
begin
  Result := False;
  for i := 0 to Lines.Count-1 do
    if Pos(S, Lines[i]) > 0 then Exit(True);
end;

// A wall the overlay can't see but the client can: the check learns it before the character gets
// there, so no step is ever refused.
procedure TPathWalkTests.TestClientCheckLearnsHiddenWallBeforeStepping;
begin
  Sim(5, 5);
  C.CheckOn := True;
  C.AddHidden(Item(12, 5, W_WALL));
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertEquals(20, C.X);
  AssertTrue('learned', Ov.IsLearned(0, 12, 5));
  AssertEquals('never walked into it', 0, C.BlockedSteps);
  AssertFalse(C.Visited(12, 5));
  AssertTrue(C.Checks >= 1);
end;

// A house the overlay lacks, 8 by 11, across the route: the probe round the first refused tile
// learns a block of it at once, so the walk gets round it in a few replans, never refused.
procedure TPathWalkTests.TestClientCheckLearnsAHiddenHouseInFewReplans;
var
  X, Y : Integer;
begin
  Sim(5, 7);
  C.CheckOn := True;
  for Y := 2 to 12 do
    for X := 15 to 22 do
      C.AddHidden(Item(X, Y, W_WALL));
  W.OnLog := @Collect;
  AssertTrue(Walk(35, 7, wmSteps) = wsArrived);
  if GetEnvironmentVariable('PATHWALK_LOG') <> '' then WriteLn(Lines.Text);
  AssertEquals(35, C.X);
  AssertEquals('never walked into it', 0, C.BlockedSteps);
  AssertTrue('learned a block of it: ' + IntToStr(Ov.LearnedCount), Ov.LearnedCount >= 30);
  AssertTrue('in few replans: ' + IntToStr(W.Replans), W.Replans <= 6);
  AssertTrue(Logged('client check round '));
end;

// The diagonal from 7,7 to 8,8 needs both 8,7 and 7,8 free; the client refuses 8,7, so that flank is
// learned and the route goes another way.
procedure TPathWalkTests.TestClientCheckRefusesADiagonalByItsFlank;
begin
  Sim(5, 5);
  C.CheckOn := True;
  C.AddHidden(Item(8, 7, W_WALL));
  W.OnLog := @Collect;
  AssertTrue(Walk(15, 15, wmSteps) = wsArrived);
  AssertTrue('the flank learned', Ov.IsLearned(0, 8, 7));
  AssertTrue(Logged('refused at 8,7'));
  AssertEquals(0, C.BlockedSteps);
end;

// A shut door the walker opens: the client refuses it, as any shut door, but it is not learned.
procedure TPathWalkTests.TestClientCheckLeavesADoorToOpen;
begin
  G.AddStaticRect(15, 0, 15, 4, 0, 20, TDF_IMPASSABLE);
  G.AddStaticRect(15, 6, 15, 63, 0, 20, TDF_IMPASSABLE);
  Sim(10, 5);
  C.CheckOn := True;
  C.AddVisible(Item(15, 5, W_DOOR));
  W.OnLog := @Collect;
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertEquals(20, C.X);
  AssertEquals(1, C.DoorsOpened);
  AssertTrue(Logged('15,5 refused, a door to open'));
end;

// A creature on the route with mobiles ignored: the client refuses its tile, but the check leaves
// it to the overlay rather than learning it for a minute.
procedure TPathWalkTests.TestClientCheckLeavesAMobile;
begin
  Sim(5, 30);
  C.CheckOn := True;
  Ov.IgnoreMobiles := True;
  C.AddVisible(Item(12, 30, 0, lkMobile));
  W.OnLog := @Collect;
  W.Mode := wmSteps;
  AssertTrue(W.Start(C, 20, 30, 0, False, 0, False));
  W.Tick(C);
  AssertTrue(Logged('12,30 refused, a mobile there'));
  AssertFalse(Ov.IsLearned(0, 12, 30));
end;

// A client that refuses even the character's own tile hasn't loaded the area: its answer is
// dropped, and the hidden wall is found the old way, by a refused step.
procedure TPathWalkTests.TestClientCheckDroppedWhenOwnTileRefused;
begin
  Sim(5, 5);
  C.CheckOn := True;
  C.CheckBlind := True;
  C.AddHidden(Item(12, 5, W_WALL));
  W.OnLog := @Collect;
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertTrue(Logged('own tile refused, answer dropped'));
  AssertEquals('only the refused step learned', 1, Ov.LearnedCount);
  AssertTrue(C.BlockedSteps >= 1);
end;

procedure TPathWalkTests.TestClientCheckWithoutAnswerChangesNothing;
begin
  Sim(5, 5);
  C.AddHidden(Item(12, 5, W_WALL));
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertTrue('asked', C.Checks >= 1);
  AssertEquals('found by a refused step', 1, Ov.LearnedCount);
  AssertTrue(C.BlockedSteps >= 1);
end;

// Nothing farther than CheckDist from the character is asked about (the character may be a step
// ahead of what the walker last saw); 0 asks nothing.
procedure TPathWalkTests.TestClientCheckStaysWithinCheckDist;
begin
  Sim(5, 30);
  C.CheckOn := True;
  AssertTrue(Walk(50, 30, wmSteps) = wsArrived);
  AssertTrue('looked ahead: ' + IntToStr(C.MaxCheckDist), C.MaxCheckDist >= W.CheckDist - 1);
  AssertTrue('no farther: ' + IntToStr(C.MaxCheckDist), C.MaxCheckDist <= W.CheckDist + 1);
  FreeAndNil(C);
  Sim(5, 30);
  C.CheckOn := True;
  W.CheckDist := 0;
  AssertTrue(Walk(50, 30, wmSteps) = wsArrived);
  AssertEquals(0, C.Checks);
end;

// The route jumps from 18,5 to 22,5: the tiles between are never asked about.
procedure TPathWalkTests.TestClientCheckNeverAsksAcrossALink;
begin
  G.AddStaticRect(20, 0, 20, 63, 0, 20, TDF_IMPASSABLE);
  P.AddLink(0, 18, 5, 0, 22, 5, 0, PATH_STEP_COST);
  Sim(10, 5);
  C.CheckOn := True;
  C.TeleX := 18;
  C.TeleY := 5;
  C.TeleX2 := 22;
  C.TeleY2 := 5;
  AssertTrue(Walk(30, 5, wmSteps) = wsArrived);
  AssertEquals(30, C.X);
  AssertTrue(C.Checks >= 2);
  AssertTrue(C.Asked.IndexOf('19,5') < 0);
  AssertTrue(C.Asked.IndexOf('20,5') < 0);
  AssertTrue(C.Asked.IndexOf('21,5') < 0);
end;

// Stairs the overlay can't see: the client lands the character 4 up, and the route takes that
// height rather than its own.
procedure TPathWalkTests.TestClientCheckTakesTheClientsHeight;
var
  X : Integer;
begin
  Sim(5, 5);
  C.CheckOn := True;
  for X := 10 to 13 do
    C.AddHidden(Item(X, 5, W_RAMP));
  W.OnLog := @Collect;
  AssertTrue(Walk(20, 5, wmSteps) = wsArrived);
  AssertTrue(Logged('step 5 (10,5) lands at 4, planned 0'));
  AssertEquals(0, C.BlockedSteps);
  AssertEquals(0, Ov.LearnedCount);
end;

initialization
  RegisterTest(TPathWalkTests);
end.
