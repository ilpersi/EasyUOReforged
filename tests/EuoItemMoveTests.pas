unit EuoItemMoveTests;

{
  EuoItemMove (MOVEITEM): the stages against a fake shard instead of a client. TFakeShard plays what
  ModernUO does, as docs\modernuo-reference.md 3.3 records it and tests\tools\MoveItemProbe.euo saw it
  live: an accepted lift takes the item out of view after LiftDelay ms (part of a stack: the lifted part
  keeps the ID, the rest gets a new ID), a refused one leaves it; a drop moves what is held, whatever
  ID it names, and shows after DropDelay ms: into the destination (joining a pile there without a
  position), or bounced back where it was lifted from, or to the feet, or used up. Containers in Hidden
  show nothing of what they hold, as a chest the player never opened. The clock moves only through
  Wait. The fake has no journal: nothing the mover decides can come from a text.

  Every test also checks the two safety rules: a drop never names another destination, a lift never
  another item.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoItemMove;

const
  ME       = $00000001;
  PACK     = $40000010;
  BAG      = $40000020;
  CHEST    = $40000030;   // shown only when not in Hidden
  DAGGER   = $40000040;
  LOGS     = $40000100;
  PILE     = $40000200;   // logs already in BAG
  LOGT     = $1BDD;
  BAGT     = $0E76;
  DAGT     = $0F52;

type
  TLiftPolicy = (lpAccept, lpRefuse);
  TDropPolicy = (dpAccept, dpBounceOrigin, dpBounceFeet, dpUseUp);
  TEvKind     = (evLift, evDrop);

  TEv = record
    Due    : QWord;
    Kind   : TEvKind;
    ID     : Cardinal;
    Amount : Cardinal;
    Dest   : Cardinal;
    X, Y   : Integer;
  end;

  TCall = record
    T      : QWord;
    ID     : Cardinal;
    Amount : Cardinal;
    Dest   : Cardinal;
    X, Y   : Integer;
  end;

  TFakeShard = class(TMoveClient)
  public
    World        : TMoveObjs;
    Hidden       : array of Cardinal;
    Evs          : array of TEv;
    Lifts        : array of TCall;
    Drops        : array of TCall;
    FNow         : QWord;
    Waits        : Integer;
    StopAtWait   : Integer;      // the Wait call (1-based) that reports a Stop; 0 = never
    PauseAtWait  : Integer;      // that Wait passes no time on Now (held by Pause); 0 = never
    Cursor       : Boolean;      // something hangs on the client's cursor
    LiftDelay    : Cardinal;
    DropDelay    : Cardinal;
    RefuseLifts  : Integer;      // the next n lifts are refused
    LiftsNotSent : Integer;      // the next n Lift calls send nothing (the client can't)
    DropPlan     : array of TDropPolicy;   // one per drop; past the end: dpAccept
    OldIDLifted  : Boolean;      // True: ModernUO (the lifted part keeps the ID); False: the rest keeps it
    ShardHolds   : Boolean;      // the shard holds Held (lifted, not dropped)
    Held         : TMoveObj;
    HeldFrom     : TMoveObj;
    NextID       : Cardinal;
    WantID       : Cardinal;
    WantDest     : Cardinal;
    Breach       : String;       // a safety rule broken, '' = none
    constructor Create;
    procedure Add(ID, Typ : Cardinal; Kind : Integer; Cont, Stack : Cardinal);
    function  Find(ID : Cardinal) : Integer;
    function  Seen(ID : Cardinal) : Boolean;
    function  IsHidden(Cont : Cardinal) : Boolean;
    procedure Remove(i : Integer);
    procedure Due;
    procedure DoLift(const E : TEv);
    procedure DoDrop(const E : TEv);
    // TMoveClient
    function  Snapshot(var Objs : TMoveObjs) : Boolean; override;
    function  CharID : Cardinal; override;
    function  Lift(ID, Amount : Cardinal) : Boolean; override;
    procedure Drop(ID, Dest : Cardinal; X, Y : Integer); override;
    function  Now : QWord; override;
    function  Wait(Ms : Cardinal) : Boolean; override;
    function  Holding : Boolean; override;
  end;

  TEuoItemMoveTests = class(TTestCase)
  private
    S : TFakeShard;
    function  Move(ID, Dest, Amount : Cardinal; X : Integer = -1; Y : Integer = -1) : TMoveRes;
    procedure Expect(Want : TMoveRes; Got : TMoveRes);
    function  StackOf(ID : Cardinal) : Integer;
    function  ContOf(ID : Cardinal) : Cardinal;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWholeStackIntoABag;
    procedure TestPartOfAStackKeepsTheIDOnTheLiftedPart;
    procedure TestJoiningAPileInTheDestinationIsOk;
    procedure TestDropOntoAPileIsOk;
    procedure TestAPositionNeverJoinsAPile;
    procedure TestShardThatGivesTheLiftedPartANewID;
    procedure TestAmountOverTheStackTakesTheStack;
    procedure TestUnknownItemSendsNothing;
    procedure TestUnknownDestinationSendsNothing;
    procedure TestSomethingOnTheCursorSendsNothing;
    procedure TestItemIntoItselfIsAnError;
    procedure TestRefusedLiftIsTriedAgainAfterTheGap;
    procedure TestAlwaysRefusedLiftNeverDrops;
    procedure TestLateLiftIsDroppedOnce;
    procedure TestBounceEveryTimeIsRefused;
    procedure TestBounceOnceThenOk;
    procedure TestBounceToTheFeetCountsAsBounced;
    procedure TestUsedUpIsLeftWithNoRetry;
    procedure TestUnseenDestinationIsLeft;
    procedure TestLiftNotSentDropsNothing;
    procedure TestStopWithTheLiftSeenStillDrops;
    procedure TestStopBeforeTheLiftShowsSendsNothingMore;
    procedure TestStopWhileWaitingForTheDropSendsNothingMore;
    procedure TestPausedWaitDoesNotUseUpTheLiftWait;
    procedure TestOntoAMobileIntoItsBackpackIsOk;
    procedure TestMoveResWords;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TFakeShard.Create;
begin
  inherited Create;
  FNow:=100000;
  LiftDelay:=200;
  DropDelay:=250;
  OldIDLifted:=True;
  NextID:=$40001000;
end;

procedure TFakeShard.Add(ID, Typ : Cardinal; Kind : Integer; Cont, Stack : Cardinal);
var
  n : Integer;
begin
  n:=Length(World);
  SetLength(World,n+1);
  World[n].ID:=ID;
  World[n].Typ:=Typ;
  World[n].Kind:=Kind;
  World[n].Cont:=Cont;
  World[n].Stack:=Stack;
end;

function TFakeShard.Find(ID : Cardinal) : Integer;
var
  i : Integer;
begin
  for i:=0 to High(World) do
    if World[i].ID=ID then Exit(i);
  Result:=-1;
end;

function TFakeShard.IsHidden(Cont : Cardinal) : Boolean;
var
  i : Integer;
begin
  for i:=0 to High(Hidden) do
    if Hidden[i]=Cont then Exit(True);
  Result:=False;
end;

// In the client's list: in the world, and not in a container whose contents the client isn't told.
function TFakeShard.Seen(ID : Cardinal) : Boolean;
var
  i : Integer;
begin
  i:=Find(ID);
  Result:=(i>=0) and not ((World[i].Kind=0) and IsHidden(World[i].Cont));
end;

procedure TFakeShard.Remove(i : Integer);
var
  j : Integer;
begin
  for j:=i to High(World)-1 do World[j]:=World[j+1];
  SetLength(World,Length(World)-1);
end;

// The shard's answers whose time has come, in order.
procedure TFakeShard.Due;
var
  i : Integer;
  E : TEv;
begin
  while (Length(Evs)>0) and (Evs[0].Due<=FNow) do
  begin
    E:=Evs[0];
    for i:=0 to High(Evs)-1 do Evs[i]:=Evs[i+1];
    SetLength(Evs,Length(Evs)-1);
    if E.Kind=evLift then DoLift(E) else DoDrop(E);
  end;
end;

procedure TFakeShard.DoLift(const E : TEv);
var
  i     : Integer;
  S0, A : Cardinal;
begin
  i:=Find(E.ID);
  if i<0 then Exit;
  if RefuseLifts>0 then
  begin
    Dec(RefuseLifts);
    Exit;
  end;
  if ShardHolds then Exit;                    // "You are already holding an item."
  S0:=World[i].Stack;
  if S0=0 then S0:=1;
  A:=E.Amount;
  if A<1 then A:=1;
  if A>S0 then A:=S0;
  HeldFrom:=World[i];
  if A<S0 then
  begin
    if OldIDLifted then
    begin
      Add(NextID,World[i].Typ,World[i].Kind,World[i].Cont,S0-A);   // the rest, a new ID
      Inc(NextID);
      Held:=World[i];
      Held.Stack:=A;
      Remove(i);
    end
    else begin
      World[i].Stack:=S0-A;                   // the old ID keeps the rest
      Held:=World[i];
      Held.ID:=NextID;
      Held.Stack:=A;
      Inc(NextID);
    end;
  end
  else begin
    Held:=World[i];
    Remove(i);
  end;
  ShardHolds:=True;
end;

procedure TFakeShard.DoDrop(const E : TEv);
var
  P   : TDropPolicy;
  i   : Integer;
  n   : Integer;
begin
  if not ShardHolds then Exit;                // the shard drops what it holds, or nothing
  ShardHolds:=False;
  n:=Length(Drops)-1;                         // this drop's plan
  P:=dpAccept;
  if (n>=0) and (n<=High(DropPlan)) then P:=DropPlan[n];
  case P of
    dpAccept:
      begin
        // onto yourself: into your backpack
        if E.Dest=ME then
        begin
          Add(Held.ID,Held.Typ,0,PACK,Held.Stack);
          Exit;
        end;
        // onto a pile of the same kind: it grows
        i:=Find(E.Dest);
        if (i>=0) and (World[i].Typ=Held.Typ) then
        begin
          Inc(World[i].Stack,Held.Stack);
          Exit;
        end;
        // into a container without a position: the first pile of the same kind takes it
        if E.X<0 then
          for i:=0 to High(World) do
            if (World[i].Kind=0) and (World[i].Cont=E.Dest) and (World[i].Typ=Held.Typ) then
            begin
              Inc(World[i].Stack,Held.Stack);
              Exit;
            end;
        Add(Held.ID,Held.Typ,0,E.Dest,Held.Stack);
      end;
    dpBounceOrigin:
      Add(Held.ID,Held.Typ,HeldFrom.Kind,HeldFrom.Cont,Held.Stack);
    dpBounceFeet:
      Add(Held.ID,Held.Typ,1,0,Held.Stack);
    dpUseUp: ;
  end;
end;

function TFakeShard.Snapshot(var Objs : TMoveObjs) : Boolean;
var
  i, n : Integer;
begin
  Due;
  SetLength(Objs,Length(World));
  n:=0;
  for i:=0 to High(World) do
    if not ((World[i].Kind=0) and IsHidden(World[i].Cont)) then
    begin
      Objs[n]:=World[i];
      Inc(n);
    end;
  SetLength(Objs,n);
  Result:=True;
end;

function TFakeShard.Holding : Boolean;
begin
  Result:=Cursor;
end;

function TFakeShard.CharID : Cardinal;
begin
  Result:=ME;
end;

// As ExEv_Drag: nothing is sent for an item the client doesn't hold in its list.
function TFakeShard.Lift(ID, Amount : Cardinal) : Boolean;
var
  n : Integer;
begin
  if ID<>WantID then Breach:=Format('lifted %x, not %x',[ID,WantID]);
  Due;
  Result:=False;
  if LiftsNotSent>0 then
  begin
    Dec(LiftsNotSent);
    Exit;
  end;
  if not Seen(ID) then Exit;
  n:=Length(Lifts);
  SetLength(Lifts,n+1);
  Lifts[n].T:=FNow;
  Lifts[n].ID:=ID;
  Lifts[n].Amount:=Amount;
  n:=Length(Evs);
  SetLength(Evs,n+1);
  Evs[n].Due:=FNow+LiftDelay;
  Evs[n].Kind:=evLift;
  Evs[n].ID:=ID;
  Evs[n].Amount:=Amount;
  Result:=True;
end;

procedure TFakeShard.Drop(ID, Dest : Cardinal; X, Y : Integer);
var
  n, i : Integer;
  E    : TEv;
begin
  if Dest<>WantDest then Breach:=Format('dropped into %x, not %x',[Dest,WantDest]);
  if ID<>WantID then Breach:=Format('the drop named %x, not %x',[ID,WantID]);
  n:=Length(Drops);
  SetLength(Drops,n+1);
  Drops[n].T:=FNow;
  Drops[n].ID:=ID;
  Drops[n].Dest:=Dest;
  Drops[n].X:=X;
  Drops[n].Y:=Y;
  E.Due:=FNow+DropDelay;
  E.Kind:=evDrop;
  E.ID:=ID;
  E.Dest:=Dest;
  E.X:=X;
  E.Y:=Y;
  // the shard answers packets in order: after any lift still on its way
  i:=Length(Evs);
  SetLength(Evs,i+1);
  Evs[i]:=E;
  if (i>0) and (Evs[i-1].Due>E.Due) then Evs[i].Due:=Evs[i-1].Due;
end;

function TFakeShard.Now : QWord;
begin
  Result:=FNow;
end;

function TFakeShard.Wait(Ms : Cardinal) : Boolean;
var
  i : Integer;
begin
  Inc(Waits);
  if (PauseAtWait>0) and (Waits=PauseAtWait) then
  begin
    // held by Pause: the shard's answers came meanwhile, but Now (paused time left out) didn't move
    for i:=0 to High(Evs) do Evs[i].Due:=FNow;
    Due;
    Exit(True);
  end;
  Inc(FNow,Ms);
  Result:=not ((StopAtWait>0) and (Waits=StopAtWait));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoItemMoveTests.SetUp;
begin
  S:=TFakeShard.Create;
  S.Add(ME,$190,1,0,0);              // the character
  S.Add(PACK,$0E75,0,ME,0);          // its backpack
  S.Add(BAG,BAGT,0,PACK,0);
  S.Add(CHEST,$0E43,1,0,0);
  S.Add(DAGGER,DAGT,0,PACK,1);
  S.Add(LOGS,LOGT,0,PACK,50);
end;

procedure TEuoItemMoveTests.TearDown;
begin
  S.Free;
end;

function TEuoItemMoveTests.Move(ID, Dest, Amount : Cardinal; X : Integer; Y : Integer) : TMoveRes;
begin
  S.WantID:=ID;
  S.WantDest:=Dest;
  Result:=RunMove(S,ID,Dest,Amount,X,Y);
  AssertEquals('safety rules', '', S.Breach);
end;

procedure TEuoItemMoveTests.Expect(Want : TMoveRes; Got : TMoveRes);
begin
  AssertEquals('result', MoveResText(Want)+'/'+IntToStr(Ord(Want)), MoveResText(Got)+'/'+IntToStr(Ord(Got)));
end;

function TEuoItemMoveTests.StackOf(ID : Cardinal) : Integer;
var
  i : Integer;
begin
  i:=S.Find(ID);
  if i<0 then Exit(-1);
  Result:=S.World[i].Stack;
end;

function TEuoItemMoveTests.ContOf(ID : Cardinal) : Cardinal;
var
  i : Integer;
begin
  i:=S.Find(ID);
  if i<0 then Exit(0);
  Result:=S.World[i].Cont;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoItemMoveTests.TestWholeStackIntoABag;
begin
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertEquals('one lift', 1, Length(S.Lifts));
  AssertEquals('the whole stack', 50, S.Lifts[0].Amount);
  AssertEquals('one drop', 1, Length(S.Drops));
  AssertEquals('in the bag', BAG, ContOf(LOGS));
  AssertEquals(50, StackOf(LOGS));
end;

procedure TEuoItemMoveTests.TestPartOfAStackKeepsTheIDOnTheLiftedPart;
var
  i, Rest : Integer;
begin
  Expect(mrOk, Move(LOGS,BAG,10));
  AssertEquals('the old ID is the lifted part', 10, StackOf(LOGS));
  AssertEquals(BAG, ContOf(LOGS));
  Rest:=-1;
  for i:=0 to High(S.World) do
    if (S.World[i].Typ=LOGT) and (S.World[i].ID<>LOGS) then Rest:=S.World[i].Stack;
  AssertEquals('the rest stays under a new ID', 40, Rest);
end;

procedure TEuoItemMoveTests.TestJoiningAPileInTheDestinationIsOk;
begin
  S.Add(PILE,LOGT,0,BAG,30);
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertEquals('the ID is gone', -1, S.Find(LOGS));
  AssertEquals('the pile grew', 80, StackOf(PILE));
end;

procedure TEuoItemMoveTests.TestDropOntoAPileIsOk;
begin
  S.Add(PILE,LOGT,0,BAG,30);
  Expect(mrOk, Move(LOGS,PILE,5));
  AssertEquals('the pile grew', 35, StackOf(PILE));
end;

procedure TEuoItemMoveTests.TestAPositionNeverJoinsAPile;
begin
  S.Add(PILE,LOGT,0,BAG,30);
  Expect(mrOk, Move(LOGS,BAG,0,40,40));
  AssertEquals(40, S.Drops[0].X);
  AssertEquals(40, S.Drops[0].Y);
  AssertEquals('its own pile in the bag', BAG, ContOf(LOGS));
  AssertEquals('the other pile kept its amount', 30, StackOf(PILE));
end;

procedure TEuoItemMoveTests.TestShardThatGivesTheLiftedPartANewID;
var
  i, Moved : Integer;
begin
  S.OldIDLifted:=False;
  Expect(mrOk, Move(LOGS,BAG,10));
  AssertEquals('the old ID kept the rest', 40, StackOf(LOGS));
  AssertEquals(PACK, ContOf(LOGS));
  Moved:=-1;
  for i:=0 to High(S.World) do
    if (S.World[i].Typ=LOGT) and (S.World[i].Cont=BAG) then Moved:=S.World[i].Stack;
  AssertEquals('10 arrived under a new ID', 10, Moved);
end;

procedure TEuoItemMoveTests.TestAmountOverTheStackTakesTheStack;
begin
  Expect(mrOk, Move(LOGS,BAG,500));
  AssertEquals(50, S.Lifts[0].Amount);
end;

procedure TEuoItemMoveTests.TestUnknownItemSendsNothing;
begin
  Expect(mrNoItem, Move($40009999,BAG,0));
  AssertEquals(0, Length(S.Lifts));
  AssertEquals(0, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestUnknownDestinationSendsNothing;
begin
  Expect(mrNoDest, Move(LOGS,$40009999,0));
  AssertEquals(0, Length(S.Lifts));
  AssertEquals(0, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestSomethingOnTheCursorSendsNothing;
begin
  S.Cursor:=True;
  Expect(mrHeld, Move(LOGS,BAG,0));
  AssertEquals(0, Length(S.Lifts));
  AssertEquals(0, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestItemIntoItselfIsAnError;
begin
  Expect(mrError, Move(LOGS,LOGS,0));
  Expect(mrError, Move(0,BAG,0));
  AssertEquals(0, Length(S.Lifts));
end;

procedure TEuoItemMoveTests.TestRefusedLiftIsTriedAgainAfterTheGap;
begin
  S.RefuseLifts:=1;
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertEquals('two lifts', 2, Length(S.Lifts));
  AssertTrue('at least the gap apart', S.Lifts[1].T-S.Lifts[0].T>=MOVE_LIFT_GAP);
  AssertEquals('one drop', 1, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestAlwaysRefusedLiftNeverDrops;
begin
  S.RefuseLifts:=100;
  Expect(mrNoLift, Move(LOGS,BAG,0));
  AssertEquals('three lifts', MOVE_LIFTS, Length(S.Lifts));
  AssertEquals('no drop, ever', 0, Length(S.Drops));
  AssertEquals('still in the backpack', PACK, ContOf(LOGS));
end;

// A lift that shows only after the lift wait: the next lift goes out (the shard refuses it, as it holds
// the first), the first then shows, and is dropped once. Nothing is left held.
procedure TEuoItemMoveTests.TestLateLiftIsDroppedOnce;
begin
  S.LiftDelay:=MOVE_LIFT_WAIT+300;
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertTrue('at most two lifts', Length(S.Lifts)<=2);
  AssertEquals('one drop', 1, Length(S.Drops));
  AssertEquals(BAG, ContOf(LOGS));
  AssertFalse('nothing left held', S.ShardHolds);
end;

procedure TEuoItemMoveTests.TestBounceEveryTimeIsRefused;
begin
  SetLength(S.DropPlan,MOVE_LIFTS);
  S.DropPlan[0]:=dpBounceOrigin;
  S.DropPlan[1]:=dpBounceOrigin;
  S.DropPlan[2]:=dpBounceOrigin;
  Expect(mrRefused, Move(LOGS,DAGGER,0));
  AssertEquals(MOVE_LIFTS, Length(S.Lifts));
  AssertEquals(MOVE_LIFTS, Length(S.Drops));
  AssertEquals('back where it was', PACK, ContOf(LOGS));
end;

procedure TEuoItemMoveTests.TestBounceOnceThenOk;
begin
  SetLength(S.DropPlan,1);
  S.DropPlan[0]:=dpBounceOrigin;
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertEquals(2, Length(S.Lifts));
  AssertTrue('the second lift waited the gap', S.Lifts[1].T-S.Lifts[0].T>=MOVE_LIFT_GAP);
  AssertEquals(BAG, ContOf(LOGS));
end;

procedure TEuoItemMoveTests.TestBounceToTheFeetCountsAsBounced;
var
  i : Integer;
begin
  SetLength(S.DropPlan,MOVE_LIFTS);
  for i:=0 to High(S.DropPlan) do S.DropPlan[i]:=dpBounceOrigin;
  S.DropPlan[0]:=dpBounceFeet;
  Expect(mrRefused, Move(LOGS,DAGGER,0));
  AssertEquals('lifted again from the ground', MOVE_LIFTS, Length(S.Lifts));
  AssertEquals('it never went to the ground by our hand: every drop named the dagger', DAGGER, S.Drops[0].Dest);
end;

procedure TEuoItemMoveTests.TestUsedUpIsLeftWithNoRetry;
begin
  SetLength(S.DropPlan,1);
  S.DropPlan[0]:=dpUseUp;
  Expect(mrLeft, Move(LOGS,BAG,0));
  AssertEquals(1, Length(S.Lifts));
  AssertEquals(1, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestUnseenDestinationIsLeft;
begin
  SetLength(S.Hidden,1);
  S.Hidden[0]:=CHEST;
  Expect(mrLeft, Move(LOGS,CHEST,0));
  AssertEquals('it did arrive', CHEST, ContOf(LOGS));
  AssertEquals('no retry', 1, Length(S.Lifts));
end;

procedure TEuoItemMoveTests.TestLiftNotSentDropsNothing;
begin
  S.LiftsNotSent:=1;
  Expect(mrNoLift, Move(LOGS,BAG,0));
  AssertEquals(0, Length(S.Lifts));
  AssertEquals(0, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestStopWithTheLiftSeenStillDrops;
begin
  // the lift shows after 200 ms, at the end of the 4th wait, which reports the Stop
  S.StopAtWait:=4;
  Expect(mrStopped, Move(LOGS,BAG,0));
  AssertEquals(1, Length(S.Lifts));
  AssertEquals('the lifted item is still dropped', 1, Length(S.Drops));
  AssertEquals(BAG, S.Drops[0].Dest);
end;

procedure TEuoItemMoveTests.TestStopBeforeTheLiftShowsSendsNothingMore;
begin
  S.StopAtWait:=1;
  Expect(mrStopped, Move(LOGS,BAG,0));
  AssertEquals(1, Length(S.Lifts));
  AssertEquals('no drop', 0, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestStopWhileWaitingForTheDropSendsNothingMore;
begin
  // the lift is seen after the 4th wait (200 ms); the 6th wait is the drop's
  S.StopAtWait:=6;
  Expect(mrStopped, Move(LOGS,BAG,0));
  AssertEquals(1, Length(S.Lifts));
  AssertEquals(1, Length(S.Drops));
end;

procedure TEuoItemMoveTests.TestPausedWaitDoesNotUseUpTheLiftWait;
begin
  // a lift that shows only after the lift wait would be "late"; held by Pause on the first wait, it
  // is there on resuming with the wait not used up: lifted once, dropped once
  S.LiftDelay:=MOVE_LIFT_WAIT+500;
  S.PauseAtWait:=1;
  Expect(mrOk, Move(LOGS,BAG,0));
  AssertEquals(1, Length(S.Lifts));
  AssertEquals(1, Length(S.Drops));
end;

// Dropped onto a mobile (yourself here), the shard puts it into that mobile's backpack: ok.
procedure TEuoItemMoveTests.TestOntoAMobileIntoItsBackpackIsOk;
begin
  S.World[S.Find(LOGS)].Cont:=BAG;
  Expect(mrOk, Move(LOGS,ME,0));
  AssertEquals(PACK, ContOf(LOGS));
  AssertEquals('one lift', 1, Length(S.Lifts));
end;

procedure TEuoItemMoveTests.TestMoveResWords;
begin
  AssertEquals('ok', MoveResText(mrOk));
  AssertEquals('left', MoveResText(mrLeft));
  AssertEquals('refused', MoveResText(mrRefused));
  AssertEquals('nolift', MoveResText(mrNoLift));
  AssertEquals('noitem', MoveResText(mrNoItem));
  AssertEquals('nodest', MoveResText(mrNoDest));
  AssertEquals('held', MoveResText(mrHeld));
  AssertEquals('error', MoveResText(mrError));
  AssertEquals('', MoveResText(mrStopped));
end;

initialization
  RegisterTest(TEuoItemMoveTests);
end.
