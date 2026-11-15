unit EuoItemMove;

{
  Port addition (MOVEITEM): moving an item, or an amount of a stack, into a destination and finding
  out what happened, with no client and no interpreter, so all of it runs in the test suite. The
  interpreter (TEuoInterpreter.MoveItemProc) gives it a TMoveClient over the real client
  (TEuoMoveClient: EXEVENT DRAG / DROPC, the client's object list, Delay).

  The route is the server's: a drag packet then a drop packet, as EXEVENT DRAG and DROPC send them. The
  client never holds the item, so #LLiftedKind can't tell what happened. Every check reads the
  client's object list instead, and nothing reads the journal: no outcome depends on a text, so it
  works whatever the client's language and the shard's wording (the owner's rule, 2026-11-15).

  What the shard does, from ModernUO's source and the probe tests\tools\MoveItemProbe.euo (see
  docs\modernuo-reference.md, 3.3):
  - A lift that works takes the item out of everyone's view, the lifter's too. Lifting part of a stack,
    the lifted part keeps the ID and the rest gets a new ID where the pile was. A refused lift sends the
    item again, so its ID stays in the list.
  - A drop ignores the ID it names: the shard drops whatever the player holds. So a drop is sent only
    after the lift has been seen; after a refused lift it could move something else.
  - A refused drop bounces the item back where it was lifted from (or to the player's feet when that
    place is gone): its ID comes back into view outside the destination.
  - Into a container without a position the item may join a pile of its type there: its ID is gone,
    and that pile grows. The client sees a container's contents if it is in the player's backpack (or
    bank box), or if the player has opened it.

  So the stages are: before anything is sent, the item and the destination must be in the list and
  nothing on the cursor (a drop would move what hangs there). Lift, and wait up to MOVE_LIFT_WAIT for
  the ID to leave the list (or, on a shard that gives the lifted part a new ID, for its stack to drop by
  the amount). Then drop, and wait up to MOVE_DROP_WAIT for the ID in the destination, or a pile of its
  type there grown by the amount (ok), or the ID back outside the destination (bounced). Neither in
  time: left (the client can't see where it went; never retried, as there is nothing safe to lift). A
  lift that isn't seen is tried again, MOVE_LIFT_GAP after the one before (ModernUO's action delay is
  500 ms), and before each new lift a late one is looked for, and dropped if found; a bounce starts over.
  MOVE_LIFTS lifts at most. Waits are the client's Wait, so Stop and Pause work; Now leaves paused time
  out. On Stop during a lift wait, a lift that has already happened is still dropped, so the item isn't
  left held by the shard (where the client can't see it).
}

{$mode delphi}{$H+}

interface

const
  MOVE_LIFT_WAIT = 1000;   // ms for a lift to show (seen in ~190 ms)
  MOVE_DROP_WAIT = 1500;   // ms for a drop to show (220 ms into a bag, up to 700 ms for a merge)
  MOVE_LIFT_GAP  = 650;    // ms at least between two lifts (the shard's action delay is 500 ms)
  MOVE_LIFTS     = 3;      // lifts at most
  MOVE_POLL      = 50;     // ms between two looks at the list (one tick)

type
  // One object of the client's list (TUOCmd.ItemSnapshot).
  TMoveObj = record
    ID    : Cardinal;
    Typ   : Cardinal;
    Kind  : Integer;     // 0 = in a container (Cont), 1 = on the ground
    Cont  : Cardinal;
    Stack : Cardinal;
  end;
  TMoveObjs = array of TMoveObj;

  TMoveRes = (mrOk, mrLeft, mrRefused, mrNoLift, mrNoItem, mrNoDest, mrHeld, mrError,
              mrStopped);   // mrStopped: the script was stopped; #MoveRes stays as it was

  TMoveClient = class
  public
    // The client's object list. False when it can't be read.
    function  Snapshot(var Objs : TMoveObjs) : Boolean; virtual; abstract;
    // Something hangs on the client's cursor (#LLiftedKind).
    function  Holding : Boolean; virtual; abstract;
    function  CharID : Cardinal; virtual; abstract;
    // Sends the drag of Amount of ID; True only when it was sent for ID.
    function  Lift(ID, Amount : Cardinal) : Boolean; virtual; abstract;
    // Sends the drop of ID (what the shard holds) into Dest, at X,Y inside it unless X < 0.
    procedure Drop(ID, Dest : Cardinal; X, Y : Integer); virtual; abstract;
    function  Now : QWord; virtual; abstract;                     // ms, paused time left out
    function  Wait(Ms : Cardinal) : Boolean; virtual; abstract;   // False: the script was stopped
  end;

// Moves Amount (0: the whole stack) of the item ID into Dest, at X,Y inside it when X >= 0.
function RunMove(C : TMoveClient; ID, Dest, Amount : Cardinal; X, Y : Integer) : TMoveRes;
// The word #MoveRes shows for a result ('' for mrStopped).
function MoveResText(R : TMoveRes) : String;

implementation

////////////////////////////////////////////////////////////////////////////////
function MoveResText(R : TMoveRes) : String;
begin
  case R of
    mrOk      : Result:='ok';
    mrLeft    : Result:='left';
    mrRefused : Result:='refused';
    mrNoLift  : Result:='nolift';
    mrNoItem  : Result:='noitem';
    mrNoDest  : Result:='nodest';
    mrHeld    : Result:='held';
    mrError   : Result:='error';
  else
    Result:='';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function FindObj(const O : TMoveObjs; ID : Cardinal) : Integer;
var
  i : Integer;
begin
  for i:=0 to High(O) do
    if O[i].ID=ID then Exit(i);
  Result:=-1;
end;

type
  TMover = class
    C        : TMoveClient;
    ID       : Cardinal;
    Dest     : Cardinal;
    DestMob  : Boolean;     // the destination is a mobile (serial below $40000000)
    Typ      : Cardinal;
    Amount   : Cardinal;    // what is lifted each time
    X, Y     : Integer;
    Base     : Int64;       // the stacks of Typ in Dest before (see PileSum)
    SLift    : Cardinal;    // the item's stack when the last lift was sent
    GoneLift : Boolean;     // the last lift showed as the ID leaving the list
    O        : TMoveObjs;
    function  Look : Boolean;
    function  PileSum : Int64;
    function  Lifted : Boolean;
    function  InDest : Boolean;
    function  Bounced : Boolean;
  end;

////////////////////////////////////////////////////////////////////////////////
function TMover.Look : Boolean;
begin
  Result:=C.Snapshot(O);
  if not Result then SetLength(O,0);
end;

// The stacks of Typ lying directly in Dest, the item itself left out, plus Dest's own stack when Dest
// is a pile of Typ (a drop onto a pile).
function TMover.PileSum : Int64;
var
  i : Integer;
begin
  Result:=0;
  for i:=0 to High(O) do
  begin
    if (O[i].Kind=0) and (O[i].Cont=Dest) and (O[i].Typ=Typ) and (O[i].ID<>ID) then
      Inc(Result,O[i].Stack);
    if (O[i].ID=Dest) and (O[i].Typ=Typ) then Inc(Result,O[i].Stack);
  end;
end;

// The last lift has happened: the ID left the list, or its stack dropped by the amount.
function TMover.Lifted : Boolean;
var
  i : Integer;
begin
  i:=FindObj(O,ID);
  GoneLift:=i<0;
  Result:=GoneLift or ((Amount<SLift) and (O[i].Stack+Amount<=SLift));
end;

// The item is in Dest: its ID directly in it (for a mobile, also in a container it wears, as its
// backpack), or the piles of its type there grew by the amount (it joined one).
function TMover.InDest : Boolean;
var
  i, j : Integer;
begin
  Result:=True;
  i:=FindObj(O,ID);
  if (i>=0) and (O[i].Kind=0) then
  begin
    if O[i].Cont=Dest then Exit;
    if DestMob then
    begin
      j:=FindObj(O,O[i].Cont);
      if (j>=0) and (O[j].Kind=0) and (O[j].Cont=Dest) then Exit;
    end;
  end;
  Result:=PileSum>=Base+Amount;
end;

// The drop was refused: the ID is back in view, outside Dest (InDest is asked first). After a lift
// seen as a stack drop (the ID stayed), the stack is back.
function TMover.Bounced : Boolean;
var
  i : Integer;
begin
  i:=FindObj(O,ID);
  if i<0 then Exit(False);
  Result:=GoneLift or (O[i].Stack>=SLift);
end;

////////////////////////////////////////////////////////////////////////////////
function RunMove(C : TMoveClient; ID, Dest, Amount : Cardinal; X, Y : Integer) : TMoveRes;
var
  M        : TMover;
  i        : Integer;
  S        : Cardinal;
  Lifts    : Integer;
  T0       : QWord;
  Seen     : Boolean;   // the pending lift has happened: drop now
  Pending  : Boolean;   // a lift was sent and no drop has followed it yet

  // One more look after a Stop: a pending lift that has happened is still dropped.
  function StopNow : TMoveRes;
  begin
    if Pending and M.Look and M.Lifted then M.C.Drop(ID,Dest,X,Y);
    Result:=mrStopped;
  end;

begin
  if (ID=0) or (Dest=0) or (ID=Dest) then Exit(mrError);
  M:=TMover.Create;
  try
    M.C:=C;
    M.ID:=ID;
    M.Dest:=Dest;
    M.DestMob:=Dest<$40000000;
    if X<0 then
    begin
      X:=-1;
      Y:=-1;
    end;
    M.X:=X;
    M.Y:=Y;
    Lifts:=0;
    Pending:=False;

    // before: nothing on the cursor, the item and the destination known
    if C.Holding then Exit(mrHeld);
    if not M.Look then Exit(mrNoItem);
    i:=FindObj(M.O,ID);
    if i<0 then Exit(mrNoItem);
    if (FindObj(M.O,Dest)<0) and (Dest<>C.CharID) then Exit(mrNoDest);
    M.Typ:=M.O[i].Typ;
    S:=M.O[i].Stack;
    if S=0 then S:=1;
    M.Amount:=Amount;
    if (Amount=0) or (Amount>S) then M.Amount:=S;
    M.Base:=M.PileSum;

    Result:=mrNoLift;
    T0:=0;
    repeat
      Seen:=False;

      // the gap after the last lift; a pending lift that shows meanwhile is dropped, not lifted again
      if Lifts>0 then
        repeat
          if not M.Look then Exit(mrNoItem);
          if Pending and M.Lifted then
          begin
            Seen:=True;
            Break;
          end;
          if C.Now-T0>=MOVE_LIFT_GAP then Break;
          if not C.Wait(MOVE_POLL) then Exit(StopNow);
        until False;

      if not Seen then
      begin
        if not M.Look then Exit(mrNoItem);
        i:=FindObj(M.O,ID);
        if i<0 then
        begin
          // gone before this lift: a pending lift that showed late, or the item is gone
          if not Pending then Exit(mrNoItem);
          M.GoneLift:=True;
          Seen:=True;
        end
        else begin
          M.SLift:=M.O[i].Stack;
          if M.SLift=0 then M.SLift:=1;
          Inc(Lifts);
          T0:=C.Now;
          if C.Lift(ID,M.Amount) then Pending:=True
          else begin
            // not sent for this item: it left the list in between, or the client can't send
            if not (M.Look and (FindObj(M.O,ID)<0)) then Exit(mrNoLift);
            if not Pending then Exit(mrNoItem);
            M.GoneLift:=True;
            Seen:=True;
          end;
          if not Seen then
            repeat
              if not M.Look then Exit(mrNoItem);
              if M.Lifted then
              begin
                Seen:=True;
                Break;
              end;
              if C.Now-T0>=MOVE_LIFT_WAIT then Break;
              if not C.Wait(MOVE_POLL) then Exit(StopNow);
            until False;
        end;
      end;

      if not Seen then
      begin
        if Lifts<MOVE_LIFTS then Continue;
        // the last lift may still show: one gap more, then drop it or give up
        while C.Now-T0<MOVE_LIFT_WAIT+MOVE_LIFT_GAP do
        begin
          if not M.Look then Exit(mrNoItem);
          if M.Lifted then
          begin
            Seen:=True;
            Break;
          end;
          if not C.Wait(MOVE_POLL) then Exit(StopNow);
        end;
        if not Seen then Exit(Result);   // mrNoLift, or mrRefused after a bounce
      end;

      // the lift has happened: drop, then see where the item went
      C.Drop(ID,Dest,X,Y);
      Pending:=False;
      T0:=C.Now;
      repeat
        if M.Look then
        begin
          if M.InDest then Exit(mrOk);
          if M.Bounced then Break;
        end;
        if C.Now-T0>=MOVE_DROP_WAIT then Exit(mrLeft);
        if not C.Wait(MOVE_POLL) then Exit(mrStopped);
      until False;

      // bounced: start over from the lift
      Result:=mrRefused;
      if Lifts>=MOVE_LIFTS then Exit(mrRefused);
    until False;
  finally
    M.Free;
  end;
end;

end.
