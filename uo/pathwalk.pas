unit pathwalk;

{
  New addition (not in the original EasyUO): the pathfinder's walker. It follows a route of the
  planner (pathplan.pas) on the live overlay (walklive.pas) and replans when the world turns out to
  be different. See docs\pathfinding.md, "Walker (phase 2)".

  Two ways to drive the character. Steps mode is the default (wmAuto): walked live on
  client_beta.exe 7.0.117.31, the client's own pathfinder kept ending its walks, taking its own way
  and being corrected by the server, and once left the character's position 3 tiles off until the
  next login, while single steps never went wrong and were only about 20% slower.
  - client mode: the client's own pathfinder (event PathFind) walks to a waypoint taken from our
    route. ClientSearch is that pathfinder as read from the client's code (an A* where every step
    costs 1, a 3D straight-line estimate, 500 positions per try, arrival within 8 of the height),
    run on our own model, so only a waypoint the client should accept is sent. Waypoints stay within
    MaxDist tiles of the character, never pass a door or a link, and come nearer (the lead halves)
    each time the client answers "Can't get there"; when even a near one is refused, the next
    stretch is walked in steps. A waypoint the client takes without a word but never starts walking
    to is no better nearer: that stretch is walked in steps at once (seen on the beta when its own
    position had drifted 3 tiles from the character's). The client's own walk also just ends after
    a handful of steps (on client_beta.exe 7.0.117.31, with or without the walker), ever sooner as
    it nears its target. So a fresh waypoint goes out every KeepAliveSteps steps walked, and before
    the character reaches the last one; a waypoint sent while it walks doesn't make it pause. A
    walk that ends early is not a refusal: the walker sends the next waypoint from there or, within
    EndSteps steps of the waypoint, takes those steps itself (the client also stops next to a tile
    it can't reach, silently), and only a refused step makes a tile a learned block.
  - steps mode: one step at a time (the walk macro). The client takes a step at a time and may drop
    a request that comes while one is under way, so steps go out StepGapMs apart at least, and one
    the character hasn't moved for is sent again after ResendMs (after TurnWaitMs when it only turned
    the character). It counts as refused when the position still hasn't changed after StepWaitMs.

  The walker replans from where the character is when a step is refused, when the refreshed overlay
  no longer allows the next CheckAhead steps, and when the character is off the route. A tile the
  character is put back off twice (back on the tile it just left, within PUT_BACK_MS: the server
  refused a step the client had already shown, as on the beta along a row of player houses)
  becomes a learned block too. When the client's walk ends off the route, the next stretch after
  the replan is walked in steps: there, the client's own way kept being corrected by the server.
  A walk that has got no closer to the goal for ProgressMs ends as failed, whatever it was doing. A replan
  first tries a short search that rejoins the route a little further on, then a full one. A refused
  cell becomes a learned block in the overlay, for BlockLifeMs.

  Doors: the overlay lets the route through a door at a small extra cost; the walker faces it and
  uses the open-door macro, up to twice, before it steps through. Links: the walker stands on the
  link's start and waits LinkWaitMs for the jump (a teleporter); after that it stops with wsLink, so
  the script can use the gate or ladder and walk on.

  Pure logic: everything that touches the client goes through a TWalkClient, which the interpreter
  implements on the real client and the tests on a simulated one. OnLog, when set, gets a line for
  every decision (path set log), with the milliseconds since the walk started.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, Math, StrUtils, walkrules, walklive, pathplan;

const
  CLIENT_SEARCH_POPS = 500;   // positions the client's own search expands per try
  CLIENT_SEARCH_ZACC = 8;     // it arrives within this many units of the goal's height
  CLIENT_SEARCH_CAP  = 5000;  // its hard limit, whatever it is asked for
  PUT_BACK_MS        = 1500;  // back on the tile it left within this: put back by the server

type
  TWalkMode  = (wmAuto, wmClient, wmSteps);   // wmAuto: steps (see above)
  TWalkState = (wsIdle, wsWalking, wsArrived, wsBlocked, wsFailed, wsTimeout, wsStopped, wsLink,
                wsNoClient);

  PPathSteps = ^TPathSteps;
  TWalkLogEvent = procedure(const Line : String) of object;

  // What the walker needs from a client.
  TWalkClient = class
  public
    // The character: position, direction (0..7 as #CharDir) and facet. False without a client.
    function  Position(out X, Y, Z, Dir, Facet : Integer) : Boolean; virtual; abstract;
    procedure PathFind(X, Y, Z : Integer); virtual; abstract;   // the client's own pathfinder
    procedure Step(Dir : Integer); virtual; abstract;          // one step (or a turn) in Dir
    procedure OpenDoor; virtual; abstract;                     // the open-door macro
    // MarkJournal remembers where the journal is; CantGetThere says whether the client has
    // refused a PathFind since.
    procedure MarkJournal; virtual; abstract;
    function  CantGetThere : Boolean; virtual; abstract;
    procedure LiveObjects(X, Y : Integer; var Objs : TLiveObjs); virtual; abstract;
    function  Now : QWord; virtual; abstract;                  // milliseconds
    function  Wait(Ms : Cardinal) : Boolean; virtual; abstract; // False: the script was stopped
    function  CanPathFind : Boolean; virtual;                  // client mode works (True here)
    procedure Busy(On : Boolean); virtual;                     // a search starts / ends (nothing here)
    function  StopFlag : PBoolean; virtual;                    // interrupts a search (nil here)
  end;

  TPathWalker = class
  private
    FP           : TPathPlanner;
    FOv          : TLiveOverlay;
    FC           : TWalkClient;
    FState       : TWalkState;
    // the route
    FSteps       : TPathSteps;
    FIdx         : Integer;    // the step the character was last seen on, -1 = the start
    FOnRoute     : Boolean;    // it is on the route now
    FSX, FSY     : Integer;    // where the route starts
    FSZ          : Integer;
    // the goal
    FGX, FGY     : Integer;
    FGZ          : Integer;
    FHasGZ       : Boolean;
    FAcc         : Integer;
    FFacet       : Integer;
    // the character
    FX, FY, FZ   : Integer;
    FDir         : Integer;
    FNow         : QWord;
    FLastMove    : QWord;
    FLastRefresh : QWord;
    FReplansHere : Integer;    // replans since the character last moved
    FBestLeft    : Integer;    // the fewest steps left to the goal so far
    FBestAt      : QWord;      // when that was
    FBounceX     : Integer;    // the tile the character was last put back off, and how often
    FBounceY     : Integer;
    FBounces     : Integer;
    FPrevX       : Integer;    // the tile the character stood on before this one, and since when
    FPrevY       : Integer;    //   it stands on this one
    FArrived     : QWord;
    FClient      : Boolean;    // client mode for this walk
    // client mode
    FWp          : Integer;    // the waypoint sent, -1 = none
    FWpSent      : QWord;
    FWpMoved     : Boolean;    // the character has moved since
    FWpFrom      : Integer;    // the step it was on when the waypoint was sent
    FPreSent     : Integer;    // the waypoint the next one was already sent ahead of
    FLead        : Integer;    // how many steps along the route a waypoint may be
    FStepsTo     : Integer;    // walk in steps up to this step (after refusals)
    // steps mode
    FStepIdx     : Integer;    // the step sent, -1 = none
    FStepDir     : Integer;
    FStepFirst   : QWord;      // when it was sent first
    FNextStep    : QWord;      // no new step before this
    FStepSent    : QWord;      // when it was sent last
    FStepFacing  : Integer;    // where the character faced when it was sent
    FStepFromX   : Integer;
    FStepFromY   : Integer;
    // a door, a link
    FDoorIdx     : Integer;
    FDoorPhase   : Integer;    // 0 face it, 1 open it, 2 see whether it opened
    FDoorTries   : Integer;
    FDoorSent    : QWord;
    FLinkIdx     : Integer;
    FLinkSince   : QWord;
    FStarted     : QWord;
    procedure Log(const Fmt : String; const Args : array of const);
    function  Finish(S : TWalkState) : TWalkState;
    procedure ResetActions;
    procedure StepPos(i : Integer; out X, Y, Z : Integer);
    function  AtGoal : Boolean;
    procedure Locate(Window : Integer);
    procedure Refresh;
    function  FirstBlockedAhead : Integer;
    procedure TakePlan;
    function  PlanFull : Boolean;
    function  PlanLocal(R : Integer; out Stopped : Boolean) : Boolean;
    function  Replan(Blocked : Integer) : Boolean;
    function  SendWaypoint(From : Integer; Moving : Boolean) : Boolean;
    procedure Refused(const Why : String; ToSteps : Boolean);
    function  ClientTakes(X, Y, Z, j : Integer) : Boolean;
    procedure SendStep(n : Integer);
    procedure NextAction;
    procedure ClientTick;
    procedure StepTick;
    procedure DoorTick;
    procedure LinkTick;
  public
    // Options (ResetOptions gives the defaults).
    Mode        : TWalkMode;
    MaxDist     : Integer;    // waypoints within this many tiles of the character
    StepWaitMs  : Cardinal;   // a step that hasn't moved the character by then was refused
    StepGapMs   : Cardinal;   // steps go out at least this far apart
    ResendMs    : Cardinal;   // a step that hasn't moved the character is sent again after this
    StartWaitMs : Cardinal;   // the client must start walking toward a waypoint by then
    StopWaitMs  : Cardinal;   // the character stood still this long: the client's walk has ended
    KeepAliveSteps : Integer; // a fresh waypoint after this many steps walked
    EndSteps    : Integer;    // the client's walk ended this close to the waypoint: steps the rest
    TurnWaitMs  : Cardinal;
    DoorWaitMs  : Cardinal;
    LinkWaitMs  : Cardinal;
    RefreshMs   : Cardinal;   // how often the overlay is read again
    BlockLifeMs : Cardinal;   // how long a learned block lasts
    StallMs     : Cardinal;   // no movement for this long: the walk fails
    ProgressMs  : Cardinal;   // no closer to the goal for this long: the walk fails
    CheckAhead  : Integer;    // steps checked against the overlay after each refresh
    TickMs      : Cardinal;   // Run's pause between two ticks
    // Results.
    PlanResult  : TPathResult;   // of the last search
    Replans     : Integer;       // of this walk
    OnLog       : TWalkLogEvent;
    constructor Create(Planner : TPathPlanner; Overlay : TLiveOverlay);
    procedure ResetOptions;
    // Starts a walk to GX,GY (and GZ when HasGZ), arriving within Acc tiles: on the planner's last
    // route when UsePlan and it was made on the character's facet, else on a new plan from the
    // character. False when there is no route (PlanResult says why) or no client; State says which.
    function  Start(C : TWalkClient; GX, GY, GZ : Integer; HasGZ : Boolean; Acc : Integer;
      UsePlan : Boolean) : Boolean;
    // One round: looks where the character is and sends what comes next. Never waits.
    function  Tick(C : TWalkClient) : TWalkState;
    // Ticks until the walk ends, TimeoutMs (0 = none) runs out, or the script is stopped.
    function  Run(C : TWalkClient; TimeoutMs : Cardinal) : TWalkState;
    procedure Stop;
    procedure Reset;
    property  State : TWalkState read FState;
    property  Steps : TPathSteps read FSteps;
    property  Index : Integer read FIdx;
    property  Lead : Integer read FLead;
    property  Waypoint : Integer read FWp;
    property  ClientMode : Boolean read FClient;
  end;

// The client's own pathfinder on Src, from SX,SY,SZ to within Acc tiles of TX,TY and 8 units of
// TZ, expanding at most MaxPops positions (and never more than the client's 5000). Path, when not
// nil, gets the steps it found.
function ClientSearch(Src : TWalkSource; SX, SY, SZ, TX, TY, TZ, MaxPops, Acc : Integer;
  Path : PPathSteps) : Boolean;

// The farthest step after From that a waypoint may be: at most Lead steps along Steps, every
// step up to it within MaxDist tiles of CX,CY, and before any link step or door cell (Doors, when
// not nil, says where the doors are). From when even the next step doesn't qualify.
function WaypointCandidate(const Steps : TPathSteps; From, CX, CY, Lead, MaxDist : Integer;
  Doors : TLiveOverlay) : Integer;

// The direction from X,Y to the neighbouring cell TX,TY, -1 when it isn't a neighbour.
function DirTo(X, Y, TX, TY : Integer) : Integer;

// The word #PathState shows for a walk state.
function WalkStateName(S : TWalkState) : String;

implementation

function WalkStateName(S : TWalkState) : String;
begin
  case S of
    wsWalking  : Result := 'walking';
    wsArrived  : Result := 'arrived';
    wsBlocked  : Result := 'blocked';
    wsFailed   : Result := 'failed';
    wsTimeout  : Result := 'timeout';
    wsStopped  : Result := 'stopped';
    wsLink     : Result := 'link';
    wsNoClient : Result := 'noclient';
  else
    Result := 'N/A';
  end;
end;

function DirTo(X, Y, TX, TY : Integer) : Integer;
var
  d : Integer;
begin
  for d := 0 to 7 do
    if (X + DirX[d] = TX) and (Y + DirY[d] = TY) then Exit(d);
  Result := -1;
end;

function Cheb(X, Y, X2, Y2 : Integer) : Integer; inline;
begin
  Result := Max(Abs(X - X2), Abs(Y - Y2));
end;

////////////////////////////////////////////////////////////////////////////////
function TWalkClient.CanPathFind : Boolean;
begin
  Result := True;
end;

procedure TWalkClient.Busy(On : Boolean);
begin
end;

function TWalkClient.StopFlag : PBoolean;
begin
  Result := nil;
end;

////////////////////////////////////////////////////////////////////////////////
// The client's search, as read from its code and first emulated in the investigation that found
// it (docs\pathfinding.md, "The client's own pathfinder"): the open list is kept sorted by F, a new
// node going before the first one whose F is not below its own; a node reached again more cheaply
// gets its new cost but keeps its place in the list, and a closed one is not opened again.
function ClientSearch(Src : TWalkSource; SX, SY, SZ, TX, TY, TZ, MaxPops, Acc : Integer;
  Path : PPathSteps) : Boolean;
type
  TCNode = record
    X, Y, Z : Integer;
    G       : Integer;
    H, F    : Single;
    Parent  : Integer;
    Next    : Integer;
  end;
var
  Nodes    : array of TCNode;
  Cnt      : Integer;
  Hash     : array of Integer;
  Mask     : Integer;
  OpenHead : Integer;
  Pops     : Integer;
  N, D, i  : Integer;
  NZ, Z2   : Integer;
  Ok       : Boolean;

  function Heur(X, Y, Z : Integer) : Single;
  begin
    Result := Sqrt(1.0*(Sqr(X - TX) + Sqr(Y - TY) + Sqr(Z - TZ)));
  end;

  function HashOf(X, Y, Z : Integer) : Integer;
  begin
    Result := Integer((Cardinal(X)*73856093) xor (Cardinal(Y)*19349663) xor
      (Cardinal(Z + 128)*83492791)) and Mask;
  end;

  procedure InsertOpen(i : Integer);
  var
    P, c : Integer;
  begin
    P := -1;
    c := OpenHead;
    while (c >= 0) and not (Nodes[i].F <= Nodes[c].F) do
    begin
      P := c;
      c := Nodes[c].Next;
    end;
    Nodes[i].Next := c;
    if P < 0 then OpenHead := i
    else Nodes[P].Next := i;
  end;

  procedure Add(Par, X, Y, Z : Integer);
  var
    G, h, i : Integer;
  begin
    G := Nodes[Par].G + 1;
    h := HashOf(X, Y, Z);
    while Hash[h] >= 0 do
    begin
      i := Hash[h];
      if (Nodes[i].X = X) and (Nodes[i].Y = Y) and (Nodes[i].Z = Z) then
      begin
        if Nodes[i].G > G then
        begin
          Nodes[i].G := G;
          Nodes[i].F := Nodes[i].H + G;
          Nodes[i].Parent := Par;
        end;
        Exit;
      end;
      h := (h + 1) and Mask;
    end;
    if Cnt >= Length(Nodes) then Exit;
    i := Cnt;
    Inc(Cnt);
    Nodes[i].X := X;
    Nodes[i].Y := Y;
    Nodes[i].Z := Z;
    Nodes[i].G := G;
    Nodes[i].H := Heur(X, Y, Z);
    Nodes[i].F := Nodes[i].H + G;
    Nodes[i].Parent := Par;
    Hash[h] := i;
    InsertOpen(i);
  end;

  function CanGo(X, Y, Z, Dir : Integer; out NewZ : Integer) : Boolean;
  begin
    NewZ := Z;
    Result := CalculateNewZ(Src, X + DirX[Dir], Y + DirY[Dir], NewZ, Dir);
  end;

  procedure BuildPath(Goal : Integer);
  var
    n, k : Integer;
  begin
    n := 0;
    k := Goal;
    while Nodes[k].Parent >= 0 do
    begin
      Inc(n);
      k := Nodes[k].Parent;
    end;
    SetLength(Path^, n);
    k := Goal;
    while n > 0 do
    begin
      Dec(n);
      Path^[n].X := Nodes[k].X;
      Path^[n].Y := Nodes[k].Y;
      Path^[n].Z := Nodes[k].Z;
      Path^[n].Dir := DirTo(Nodes[Nodes[k].Parent].X, Nodes[Nodes[k].Parent].Y, Nodes[k].X, Nodes[k].Y);
      k := Nodes[k].Parent;
    end;
  end;

begin
  Result := False;
  if MaxPops > CLIENT_SEARCH_CAP then MaxPops := CLIENT_SEARCH_CAP;
  if Path <> nil then SetLength(Path^, 0);
  SetLength(Nodes, (MaxPops + 1)*8 + 1);
  i := 64;
  while i < 2*Length(Nodes) do i := i*2;
  SetLength(Hash, i);
  FillDWord(Hash[0], i, $FFFFFFFF);
  Mask := i - 1;

  Nodes[0].X := SX;
  Nodes[0].Y := SY;
  Nodes[0].Z := SZ;
  Nodes[0].G := 0;
  Nodes[0].H := Heur(SX, SY, SZ);
  Nodes[0].F := Nodes[0].H;
  Nodes[0].Parent := -1;
  Nodes[0].Next := -1;
  Hash[HashOf(SX, SY, SZ)] := 0;
  Cnt := 1;
  OpenHead := 0;
  Pops := 0;
  while OpenHead >= 0 do
  begin
    N := OpenHead;
    OpenHead := Nodes[N].Next;
    Inc(Pops);
    if Pops > MaxPops then Exit;
    if (Abs(Nodes[N].X - TX) <= Acc) and (Abs(Nodes[N].Y - TY) <= Acc) and
      (Abs(Nodes[N].Z - TZ) <= CLIENT_SEARCH_ZACC) then
    begin
      if Path <> nil then BuildPath(N);
      Exit(True);
    end;
    for D := 0 to 7 do
    begin
      Ok := CanGo(Nodes[N].X, Nodes[N].Y, Nodes[N].Z, D, NZ);
      if Ok and Odd(D) then
        Ok := CanGo(Nodes[N].X, Nodes[N].Y, Nodes[N].Z, D - 1, Z2) and
          CanGo(Nodes[N].X, Nodes[N].Y, Nodes[N].Z, (D + 1) and 7, Z2);
      if Ok then Add(N, Nodes[N].X + DirX[D], Nodes[N].Y + DirY[D], NZ);
    end;
  end;
end;

function WaypointCandidate(const Steps : TPathSteps; From, CX, CY, Lead, MaxDist : Integer;
  Doors : TLiveOverlay) : Integer;
var
  j : Integer;
begin
  Result := From;
  for j := From + 1 to Min(High(Steps), From + Lead) do
  begin
    if Steps[j].Dir = PATH_DIR_LINK then Exit;
    if Cheb(Steps[j].X, Steps[j].Y, CX, CY) > MaxDist then Exit;
    if (Doors <> nil) and Doors.DoorAt(Steps[j].X, Steps[j].Y) then Exit;
    Result := j;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TPathWalker.Create(Planner : TPathPlanner; Overlay : TLiveOverlay);
begin
  inherited Create;
  FP := Planner;
  FOv := Overlay;
  ResetOptions;
  Reset;
end;

procedure TPathWalker.ResetOptions;
begin
  Mode := wmAuto;
  MaxDist := 18;
  StepWaitMs := 1500;
  StepGapMs := 200;   // the beta moved the character about 220 ms after each step
  ResendMs := 500;
  StartWaitMs := 1000;
  StopWaitMs := 500;
  KeepAliveSteps := 3;
  EndSteps := 4;
  TurnWaitMs := 300;
  DoorWaitMs := 800;
  LinkWaitMs := 3000;
  RefreshMs := 1000;
  BlockLifeMs := 60000;
  StallMs := 15000;
  ProgressMs := 30000;
  CheckAhead := 16;
  TickMs := 50;
end;

procedure TPathWalker.Reset;
begin
  FState := wsIdle;
  SetLength(FSteps, 0);
  FIdx := -1;
  FOnRoute := False;
  Replans := 0;
  ResetActions;
end;

procedure TPathWalker.Stop;
begin
  if FState = wsWalking then FState := wsStopped;
end;

procedure TPathWalker.Log(const Fmt : String; const Args : array of const);
begin
  if Assigned(OnLog) then
    OnLog(Format('%6d  ', [FNow - FStarted]) + Format(Fmt, Args));
end;

function TPathWalker.Finish(S : TWalkState) : TWalkState;
begin
  if (S <> FState) and (S <> wsWalking) then
    Log('end: %s at %d,%d,%d', [WalkStateName(S), FX, FY, FZ]);
  FState := S;
  Result := S;
end;

procedure TPathWalker.ResetActions;
begin
  FWp := -1;
  FPreSent := -1;
  FStepsTo := -1;
  FStepIdx := -1;
  FDoorIdx := -1;
  FLinkIdx := -1;
end;

procedure TPathWalker.StepPos(i : Integer; out X, Y, Z : Integer);
begin
  if i < 0 then
  begin
    X := FSX;
    Y := FSY;
    Z := FSZ;
  end
  else
  begin
    X := FSteps[i].X;
    Y := FSteps[i].Y;
    Z := FSteps[i].Z;
  end;
end;

function TPathWalker.AtGoal : Boolean;
var
  X, Y, Z : Integer;
begin
  Result := (Abs(FX - FGX) <= FAcc) and (Abs(FY - FGY) <= FAcc) and
    (not FHasGZ or (Abs(FZ - FGZ) <= FP.AccuracyZ));
  if Result then Exit;
  // The route's end is the goal, or next to it when nothing stands on the goal; a route of no
  // steps ends where it starts.
  StepPos(High(FSteps), X, Y, Z);
  Result := (FX = X) and (FY = Y) and (Abs(FZ - Z) <= CLIENT_SEARCH_ZACC);
end;

// Where on the route is the character? Looks Window steps either side of the last place.
procedure TPathWalker.Locate(Window : Integer);
var
  i, X, Y, Z : Integer;
begin
  FOnRoute := False;
  for i := Max(-1, FIdx - Window) to Min(High(FSteps), FIdx + Window) do
  begin
    StepPos(i, X, Y, Z);
    if (X = FX) and (Y = FY) and (Abs(Z - FZ) <= CLIENT_SEARCH_ZACC) then
    begin
      FIdx := i;
      FOnRoute := True;
      Exit;
    end;
  end;
end;

procedure TPathWalker.Refresh;
var
  Objs : TLiveObjs;
begin
  FC.LiveObjects(FX, FY, Objs);
  FOv.SetObjects(Objs);
  FLastRefresh := FNow;
end;

// The first of the next CheckAhead steps the overlay no longer allows, -1 = none.
function TPathWalker.FirstBlockedAhead : Integer;
var
  i, X, Y, Z, NZ : Integer;
begin
  Result := -1;
  StepPos(FIdx, X, Y, Z);
  for i := FIdx + 1 to Min(High(FSteps), FIdx + CheckAhead) do
  begin
    if (FSteps[i].Dir <> PATH_DIR_LINK) and not CanStep(FOv, X, Y, Z, FSteps[i].Dir, NZ) then
      Exit(i);
    X := FSteps[i].X;
    Y := FSteps[i].Y;
    Z := FSteps[i].Z;
  end;
end;

// The planner's route becomes the walk's, from where the character is.
procedure TPathWalker.TakePlan;
begin
  FSteps := Copy(FP.Steps, 0, FP.StepCount);
  FSX := FX;
  FSY := FY;
  FSZ := FZ;
  FIdx := -1;
  FOnRoute := True;
end;

function TPathWalker.PlanFull : Boolean;
var
  OldAcc : Integer;
begin
  OldAcc := FP.AccuracyXY;
  FP.AccuracyXY := FAcc;
  FC.Busy(True);
  try
    // Planned without the facing, as path find is: else a first step the way the character
    // faces saves a turn, and an equally long V wins over a straight line.
    PlanResult := FP.Find(FOv, FFacet, FX, FY, FZ, -1, FGX, FGY, FGZ, FHasGZ, FC.StopFlag);
  finally
    FC.Busy(False);
    FP.AccuracyXY := OldAcc;
  end;
  Result := PlanResult = prOk;
  if Result then TakePlan;
  Log('full plan from %d,%d,%d: %s, %d steps', [FX, FY, FZ, PathResultName(PlanResult), FP.StepCount]);
end;

// A short search from the character back to step R of the route, spliced in front of the rest.
function TPathWalker.PlanLocal(R : Integer; out Stopped : Boolean) : Boolean;
var
  OAcc, OAccZ, OMargin, ONodes : Integer;
  Res                          : TPathResult;
  Tmp                          : TPathSteps;
  i                            : Integer;
begin
  Result := False;
  Stopped := False;
  if (R <= FIdx) or (R >= High(FSteps)) then Exit;   // rejoining at the end is a full plan
  OAcc := FP.AccuracyXY;
  OAccZ := FP.AccuracyZ;
  OMargin := FP.Margin;
  ONodes := FP.MaxNodes;
  FP.AccuracyXY := 0;
  FP.AccuracyZ := 2;
  FP.Margin := 2*MaxDist;
  FP.MaxNodes := 30000;
  FC.Busy(True);
  try
    Res := FP.Find(FOv, FFacet, FX, FY, FZ, -1, FSteps[R].X, FSteps[R].Y, FSteps[R].Z, True,
      FC.StopFlag);
  finally
    FC.Busy(False);
    FP.AccuracyXY := OAcc;
    FP.AccuracyZ := OAccZ;
    FP.Margin := OMargin;
    FP.MaxNodes := ONodes;
  end;
  Stopped := Res = prStopped;
  if (Res <> prOk) or FP.GoalNear then
  begin
    Log('short plan back to step %d: %s', [R + 1, PathResultName(Res)]);
    Exit;
  end;
  Log('short plan back to step %d: %d steps', [R + 1, FP.StepCount]);

  SetLength(Tmp, FP.StepCount + High(FSteps) - R);
  for i := 0 to FP.StepCount-1 do Tmp[i] := FP.Steps[i];
  for i := R + 1 to High(FSteps) do Tmp[FP.StepCount + i - R - 1] := FSteps[i];
  FP.Steps := Tmp;            // path get shows the route being walked
  FP.StepCount := Length(Tmp);
  TakePlan;
  Result := True;
end;

function TPathWalker.Replan(Blocked : Integer) : Boolean;
var
  Stopped : Boolean;
begin
  Result := False;
  ResetActions;
  Inc(Replans);
  Inc(FReplansHere);
  if FReplansHere > 8 then
  begin
    Finish(wsFailed);
    Exit;
  end;
  if Blocked <= FIdx then Blocked := FIdx + 1;
  Log('replan at %d,%d,%d, trouble at step %d', [FX, FY, FZ, Blocked + 1]);
  if PlanLocal(Blocked + 12, Stopped) then Exit(True);
  if not Stopped then
  begin
    if PlanFull then Exit(True);
    Stopped := PlanResult = prStopped;
  end;
  if Stopped then Finish(wsStopped)
  else Finish(wsBlocked);
end;

// Would the client walk from X,Y,Z to step j, by a way that doesn't cross a learned block? The
// client doesn't know those blocks, so its search is run without them: a learned tile on its way
// means it would walk into the very thing the walker learned to go round.
function TPathWalker.ClientTakes(X, Y, Z, j : Integer) : Boolean;
var
  Path : TPathSteps;
  i    : Integer;
begin
  FOv.IgnoreLearned := True;
  try
    Result := ClientSearch(FOv, X, Y, Z, FSteps[j].X, FSteps[j].Y, FSteps[j].Z, CLIENT_SEARCH_POPS, 0, @Path);
  finally
    FOv.IgnoreLearned := False;
  end;
  if Result and (FOv.LearnedCount > 0) then
    for i := 0 to High(Path) do
      if FOv.IsLearned(FFacet, Path[i].X, Path[i].Y) then Exit(False);
end;

// Sends the client to the farthest waypoint after From it should accept. Moving: the character
// is still walking toward From, which the client then plans from.
function TPathWalker.SendWaypoint(From : Integer; Moving : Boolean) : Boolean;
var
  j, c, X, Y, Z : Integer;
  Doors      : TLiveOverlay;
begin
  Doors := nil;
  if FOv.OpenDoors then Doors := FOv;
  j := WaypointCandidate(FSteps, From, FX, FY, FLead, MaxDist, Doors);
  c := j;
  StepPos(From, X, Y, Z);
  while (j > From) and not ClientTakes(X, Y, Z, j) do
    j := From + ((j - From)*3) div 4;
  Result := j > From;
  if not Result then
  begin
    Log('no waypoint after step %d (farthest allowed: step %d, lead %d)', [From + 1, c + 1, FLead]);
    Exit;
  end;
  Log('waypoint step %d = %d,%d,%d (farthest allowed: step %d, lead %d)%s',
    [j + 1, FSteps[j].X, FSteps[j].Y, FSteps[j].Z, c + 1, FLead, IfThen(Moving, ', sent ahead', '')]);
  FC.MarkJournal;
  FC.PathFind(FSteps[j].X, FSteps[j].Y, FSteps[j].Z);
  FWp := j;
  FWpFrom := FIdx;
  FWpSent := FNow;
  FWpMoved := Moving;
end;

// The client refused a waypoint: the next one comes nearer, and after a few, a stretch in steps.
procedure TPathWalker.Refused(const Why : String; ToSteps : Boolean);
begin
  FWp := -1;
  if not ToSteps then FLead := FLead div 2;
  if ToSteps or (FLead < 3) then
  begin
    FStepsTo := Min(High(FSteps), FIdx + MaxDist);
    if FLead < 3 then FLead := MaxDist;
    Log('refused (%s): steps up to step %d', [Why, FStepsTo + 1]);
  end
  else Log('refused (%s): lead %d', [Why, FLead]);
end;

procedure TPathWalker.SendStep(n : Integer);
var
  d : Integer;
begin
  d := DirTo(FX, FY, FSteps[n].X, FSteps[n].Y);
  if d < 0 then
  begin
    Replan(n);
    Exit;
  end;
  if FNow < FNextStep then Exit;                     // the client takes one step at a time
  FNextStep := FNow + StepGapMs;
  Log('step %d: dir %d to %d,%d', [n + 1, d, FSteps[n].X, FSteps[n].Y]);
  FC.Step(d);
  FStepIdx := n;
  FStepDir := d;
  FStepFacing := FDir;
  FStepFirst := FNow;
  FStepSent := FNow;
  FStepFromX := FX;
  FStepFromY := FY;
end;

// Nothing under way: what comes next on the route.
procedure TPathWalker.NextAction;
var
  n : Integer;
begin
  if not FOnRoute then
  begin
    Replan(FIdx + 1);
    Exit;
  end;
  n := FIdx + 1;
  if n > High(FSteps) then Exit;
  if FSteps[n].Dir = PATH_DIR_LINK then LinkTick
  else if FOv.OpenDoors and FOv.DoorAt(FSteps[n].X, FSteps[n].Y) then DoorTick
  else if not FClient or (FIdx < FStepsTo) or not SendWaypoint(FIdx, False) then SendStep(n);
end;

procedure TPathWalker.ClientTick;
var
  W : Integer;
begin
  if FWp >= 0 then
  begin
    if FOnRoute and (FIdx >= FWp) then
    begin
      Log('reached waypoint step %d', [FWp + 1]);
      FWp := -1;                                   // there: the lead grows back
      if FLead < 2*MaxDist then FLead := Min(2*MaxDist, FLead + 4);
    end
    else if FC.CantGetThere then
    begin
      Refused('"can''t get there"', False);
      Exit;
    end
    else if not FWpMoved then
    begin
      if FNow - FWpSent >= StartWaitMs then Refused('it didn''t start', True);
      Exit;
    end
    else if FNow - FLastMove >= StopWaitMs then
    begin
      W := FWp;                                    // it walked, and stopped short
      FWp := -1;
      if FOnRoute and (W - FIdx <= EndSteps) then
      begin
        // Nearly there: the rest with the walk macro. If the waypoint can't be reached (the client
        // stops next to such a tile, silently), the refused step makes it a learned block.
        Log('the client''s walk ended %d steps short: steps to the waypoint', [W - FIdx]);
        FStepsTo := W;
        SendStep(FIdx + 1);
        Exit;
      end;
      if not FOnRoute then
      begin
        // Off the route: the client's own way, which here the server kept correcting. Steps.
        Log('the client''s walk ended off the route', []);
        if Replan(FIdx + 1) then
        begin
          FStepsTo := Min(High(FSteps), FIdx + MaxDist);
          Log('steps up to step %d', [FStepsTo + 1]);
        end;
        Exit;
      end;
      Log('the client''s walk ended at step %d', [FIdx + 1]);
    end
    else
    begin
      // Still walking. Every few steps, and when nearly there, the next waypoint goes out now:
      // the client's walk ends after a handful of steps, and so it doesn't stop at the waypoint.
      if FOnRoute and (FIdx - FWpFrom >= KeepAliveSteps) and (FWp - FIdx >= 2) and
        (FWp >= FStepsTo) then
      begin
        W := FWp;
        if not SendWaypoint(FIdx, True) then
        begin
          FWp := W;                                  // none: the one out stays, and no retry until
          FWpFrom := FIdx;                           // a few more steps
        end;
      end
      else if FOnRoute and (FWp - FIdx <= 3) and (FPreSent <> FWp) and (FWp < High(FSteps)) and
        (FWp >= FStepsTo) and (FSteps[FWp + 1].Dir <> PATH_DIR_LINK) and
        not (FOv.OpenDoors and FOv.DoorAt(FSteps[FWp + 1].X, FSteps[FWp + 1].Y)) then
      begin
        FPreSent := FWp;
        SendWaypoint(FWp, True);
      end;
      Exit;
    end;
  end;
  NextAction;
end;

procedure TPathWalker.StepTick;
var
  n : Integer;
begin
  if FStepIdx >= 0 then
  begin
    if (FX <> FStepFromX) or (FY <> FStepFromY) then
      FStepIdx := -1                                 // it moved; Locate has placed it
    else if FNow - FStepFirst >= StepWaitMs then
    begin
      n := FStepIdx;                                 // refused
      FStepIdx := -1;
      Log('step %d refused: learned %d,%d', [n + 1, FSteps[n].X, FSteps[n].Y]);
      FOv.Learn(FFacet, FSteps[n].X, FSteps[n].Y, FNow, BlockLifeMs);
      Replan(n);
      Exit;
    end
    else
    begin
      // Not taken yet: it only turned the character, or came while a step was under way.
      if (FNow - FStepSent >= ResendMs) or
        ((FDir = FStepDir) and (FStepFacing <> FStepDir) and (FNow - FStepSent >= TurnWaitMs)) then
      begin
        Log('step %d again (facing %d)', [FStepIdx + 1, FDir]);
        FStepFacing := FDir;
        FC.Step(FStepDir);
        FStepSent := FNow;
      end;
      Exit;
    end;
  end;
  if FClient and (FIdx >= FStepsTo) then ClientTick
  else NextAction;
end;

procedure TPathWalker.DoorTick;
var
  n, d : Integer;
begin
  n := FIdx + 1;
  if FDoorIdx <> n then
  begin
    FDoorIdx := -1;
    if not FOnRoute or (n > High(FSteps)) or not FOv.DoorAt(FSteps[n].X, FSteps[n].Y) then Exit;
    FDoorIdx := n;
    FDoorPhase := 0;
    FDoorTries := 0;
    Log('door at %d,%d (step %d)', [FSteps[n].X, FSteps[n].Y, n + 1]);
  end;
  d := DirTo(FX, FY, FSteps[n].X, FSteps[n].Y);
  if d < 0 then
  begin
    FDoorIdx := -1;
    Replan(n);
    Exit;
  end;
  case FDoorPhase of
    0: begin                                         // face it: a step toward a shut door turns
         FDoorPhase := 1;
         FDoorSent := 0;
         if FDir <> d then
         begin
           FC.Step(d);
           FDoorSent := FNow;
         end;
       end;
    1: if (FDoorSent = 0) or (FNow - FDoorSent >= TurnWaitMs) then
       begin
         Log('open door, try %d', [FDoorTries + 1]);
         FC.OpenDoor;
         Inc(FDoorTries);
         FDoorSent := FNow;
         FDoorPhase := 2;
       end;
    2: if FNow - FDoorSent >= DoorWaitMs then
       begin
         Refresh;
         if not FOv.DoorAt(FSteps[n].X, FSteps[n].Y) then
         begin
           FDoorIdx := -1;                           // open: through it
           SendStep(n);
         end
         else if FDoorTries < 2 then
           FDoorPhase := 1
         else
         begin
           FDoorIdx := -1;
           Log('door still shut: learned %d,%d', [FSteps[n].X, FSteps[n].Y]);
           FOv.Learn(FFacet, FSteps[n].X, FSteps[n].Y, FNow, BlockLifeMs);
           Replan(n);
         end;
       end;
  end;
end;

procedure TPathWalker.LinkTick;
var
  n : Integer;
begin
  n := FIdx + 1;
  if not FOnRoute or (n > High(FSteps)) or (FSteps[n].Dir <> PATH_DIR_LINK) then
  begin
    FLinkIdx := -1;                                  // it jumped (or left): on as usual
    Exit;
  end;
  if FLinkIdx <> n then
  begin
    FLinkIdx := n;
    FLinkSince := FNow;
    Log('on the start of link step %d: waiting for the jump', [n + 1]);
  end;
  if FNow - FLinkSince >= LinkWaitMs then Finish(wsLink);
end;

function TPathWalker.Start(C : TWalkClient; GX, GY, GZ : Integer; HasGZ : Boolean; Acc : Integer;
  UsePlan : Boolean) : Boolean;
var
  F : Integer;
begin
  Result := False;
  FC := C;
  Reset;
  FGX := GX;
  FGY := GY;
  FGZ := GZ;
  FHasGZ := HasGZ;
  FAcc := Max(0, Acc);
  PlanResult := prOk;
  if not C.Position(FX, FY, FZ, FDir, F) then
  begin
    FState := wsNoClient;
    Exit;
  end;
  FFacet := F;
  FNow := C.Now;
  FStarted := FNow;
  FLastMove := FNow;
  FReplansHere := 0;
  FClient := (Mode = wmClient) and C.CanPathFind;
  FLead := 2*MaxDist;
  FNextStep := 0;
  FOv.Expire(FNow);
  FOv.Unlearn(F, FX, FY);
  FBestLeft := MaxInt;
  FBestAt := FNow;
  FBounces := 0;
  FPrevX := -1;
  FPrevY := -1;
  FArrived := FNow;
  Refresh;

  if UsePlan and (FP.StepCount > 0) and (FP.StartFacet = F) then
  begin
    FSteps := Copy(FP.Steps, 0, FP.StepCount);
    FSX := FP.StartX;
    FSY := FP.StartY;
    FSZ := FP.StartZ;
    FIdx := -1;
    Locate(Length(FSteps) + 1);   // anywhere on it
    if not FOnRoute then FIdx := -1;
  end
  else if not PlanFull then
  begin
    if PlanResult = prStopped then FState := wsStopped
    else FState := wsBlocked;
    Exit;
  end;
  Log('start at %d,%d,%d to %d,%d (acc %d), %s mode, %d live objects, route of %d steps, on step %d',
    [FX, FY, FZ, FGX, FGY, FAcc, IfThen(FClient, 'client', 'steps'), FOv.ObjectCount, Length(FSteps),
     FIdx + 1]);
  FState := wsWalking;
  Result := True;
end;

function TPathWalker.Tick(C : TWalkClient) : TWalkState;
var
  X, Y, Z, Dir, F, k : Integer;
  OldX, OldY         : Integer;
  Moved, PutBack     : Boolean;
begin
  Result := FState;
  if FState <> wsWalking then Exit;
  FC := C;
  FNow := C.Now;
  if not C.Position(X, Y, Z, Dir, F) then Exit(Finish(wsNoClient));
  if F <> FFacet then Exit(Finish(wsFailed));        // a gate to another facet: not followed yet
  Moved := (X <> FX) or (Y <> FY) or (Z <> FZ);
  OldX := FX;
  OldY := FY;
  if Moved then
  begin
    FLastMove := FNow;
    FWpMoved := True;
    FReplansHere := 0;
  end;
  FX := X;
  FY := Y;
  FZ := Z;
  FDir := Dir;
  if Moved then
  begin
    Locate(2*MaxDist + 4);
    if FOnRoute then Log('at %d,%d,%d: step %d', [X, Y, Z, FIdx + 1])
    else Log('at %d,%d,%d: off the route (last on step %d)', [X, Y, Z, FIdx + 1]);
    // Back on the tile it just left: the server refused the step the client had already shown.
    // Twice off the same tile, and it is a learned block.
    PutBack := (X = FPrevX) and (Y = FPrevY) and (FNow - FArrived < PUT_BACK_MS);
    if PutBack then
    begin
      if (OldX = FBounceX) and (OldY = FBounceY) then Inc(FBounces)
      else
      begin
        FBounceX := OldX;
        FBounceY := OldY;
        FBounces := 1;
      end;
      Log('put back off %d,%d (%d)', [FBounceX, FBounceY, FBounces]);
      if FBounces >= 2 then
      begin
        FBounces := 0;
        if FOv.IsLearned(FFacet, FBounceX, FBounceY) then
        begin
          // Learned already, and the client walked onto it anyway: steps from here.
          FWp := -1;
          FStepsTo := Min(High(FSteps), FIdx + MaxDist);
          Log('put back off a learned tile: steps up to step %d', [FStepsTo + 1]);
        end
        else
        begin
          Log('learned %d,%d', [FBounceX, FBounceY]);
          FOv.Learn(FFacet, FBounceX, FBounceY, FNow, BlockLifeMs);
          if not Replan(FIdx + 1) then Exit(FState);
        end;
      end;
    end;
    if PutBack then
    begin
      FPrevX := -1;                       // so the client's next try onto that tile isn't taken
      FPrevY := -1;                       // for a put back off this one
    end
    else
    begin
      FPrevX := OldX;
      FPrevY := OldY;
    end;
    FArrived := FNow;
  end;
  FOv.Expire(FNow);
  FOv.Unlearn(FFacet, X, Y);
  if AtGoal then Exit(Finish(wsArrived));
  if FNow - FLastMove >= StallMs then Exit(Finish(wsFailed));
  Locate(2*MaxDist + 4);
  if FOnRoute and (High(FSteps) - FIdx < FBestLeft) then
  begin
    FBestLeft := High(FSteps) - FIdx;
    FBestAt := FNow;
  end
  else if FNow - FBestAt >= ProgressMs then
  begin
    Log('no closer to the goal for %d s', [ProgressMs div 1000]);
    Exit(Finish(wsFailed));
  end;

  if FNow - FLastRefresh >= RefreshMs then
  begin
    Refresh;
    k := FirstBlockedAhead;
    if k >= 0 then
    begin
      Log('step %d (%d,%d) now blocked: %d live objects', [k + 1, FSteps[k].X, FSteps[k].Y, FOv.ObjectCount]);
      if not Replan(k) then Exit(FState);
    end;
  end;

  if FStepIdx >= 0 then StepTick
  else if FDoorIdx >= 0 then DoorTick
  else if FLinkIdx >= 0 then LinkTick
  else if FClient then ClientTick
  else StepTick;
  Result := FState;
end;

function TPathWalker.Run(C : TWalkClient; TimeoutMs : Cardinal) : TWalkState;
var
  T0 : QWord;
begin
  T0 := C.Now;
  while Tick(C) = wsWalking do
  begin
    if (TimeoutMs > 0) and (C.Now - T0 >= TimeoutMs) then Exit(Finish(wsTimeout));
    if not C.Wait(TickMs) then Exit(Finish(wsStopped));
  end;
  Result := FState;
end;

end.
