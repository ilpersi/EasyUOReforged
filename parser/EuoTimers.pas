unit EuoTimers;

{
  Port addition (TIMER): a script's named timers, with no interpreter. TEuoInterpreter.TimerProc gives
  them their words and puts each answer in #TimerRes.

  A timer is a start time and a due time, both on Clock (milliseconds, GetTickCount64 unless a test sets
  another): it never jumps when the computer's clock is changed and nothing a script does moves it, unlike
  #SCnt/#SCnt2, which a script can set. Names ignore case.

  - Start: (re)starts a timer now, due DueMs later (0: due at once).
  - Elapsed: ms since its start, False for a timer that was never started.
  - Left: ms until it is due, 0 once it is due, and 0 for a timer that was never started.
  - Due: Left = 0, so a timer that was never started counts as due.
  - Stop: forgets it, False if there was no such timer.
  - Clear: forgets them all (a new run).
}

{$mode delphi}{$H+}

interface

uses
  Windows, SysUtils, Classes;

type
  TEuoTimerClock = function : QWord;

  TEuoTimers = class(TObject)
  private
    FNames : TStringList;            // upper-case names, sorted; Objects -> PEuoTimer
    function Find(const Name : String) : Integer;
  public
    Clock  : TEuoTimerClock;
    constructor Create;
    destructor  Destroy; override;
    procedure   Start(const Name : String; DueMs : QWord);
    function    Elapsed(const Name : String; out Ms : QWord) : Boolean;
    function    Left(const Name : String) : QWord;
    function    Due(const Name : String) : Boolean;
    function    Stop(const Name : String) : Boolean;
    procedure   Clear;
    function    Count : Integer;
  end;

function DefaultTimerClock : QWord;

implementation

type
  TEuoTimer = record
    StartMs : QWord;
    DueAt   : QWord;
  end;
  PEuoTimer = ^TEuoTimer;

////////////////////////////////////////////////////////////////////////////////
function DefaultTimerClock : QWord;
begin
  Result:=GetTickCount64;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoTimers.Create;
begin
  inherited Create;
  FNames:=TStringList.Create;
  FNames.Sorted:=True;
  FNames.CaseSensitive:=True;      // the names are kept upper-case
  Clock:=DefaultTimerClock;
end;

destructor TEuoTimers.Destroy;
begin
  Clear;
  FNames.Free;
  inherited;
end;

function TEuoTimers.Find(const Name : String) : Integer;
begin
  if not FNames.Find(UpperCase(Name),Result) then Result:=-1;
end;

procedure TEuoTimers.Start(const Name : String; DueMs : QWord);
var
  i : Integer;
  T : PEuoTimer;
  N : QWord;
begin
  i:=Find(Name);
  if i<0 then
  begin
    New(T);
    FNames.AddObject(UpperCase(Name),TObject(T));
  end
  else T:=PEuoTimer(FNames.Objects[i]);
  N:=Clock();
  T.StartMs:=N;
  T.DueAt:=N+DueMs;
end;

function TEuoTimers.Elapsed(const Name : String; out Ms : QWord) : Boolean;
var
  i : Integer;
  N : QWord;
begin
  Ms:=0;
  i:=Find(Name);
  Result:=i>=0;
  if not Result then Exit;
  N:=Clock();
  with PEuoTimer(FNames.Objects[i])^ do
    if N>StartMs then Ms:=N-StartMs;
end;

function TEuoTimers.Left(const Name : String) : QWord;
var
  i : Integer;
  N : QWord;
begin
  Result:=0;
  i:=Find(Name);
  if i<0 then Exit;
  N:=Clock();
  with PEuoTimer(FNames.Objects[i])^ do
    if DueAt>N then Result:=DueAt-N;
end;

function TEuoTimers.Due(const Name : String) : Boolean;
begin
  Result:=Left(Name)=0;
end;

function TEuoTimers.Stop(const Name : String) : Boolean;
var
  i : Integer;
begin
  i:=Find(Name);
  Result:=i>=0;
  if not Result then Exit;
  Dispose(PEuoTimer(FNames.Objects[i]));
  FNames.Delete(i);
end;

procedure TEuoTimers.Clear;
var
  i : Integer;
begin
  for i:=0 to FNames.Count-1 do
    Dispose(PEuoTimer(FNames.Objects[i]));
  FNames.Clear;
end;

function TEuoTimers.Count : Integer;
begin
  Result:=FNames.Count;
end;

end.
