unit clisession;

{
  Port addition (docs\agent-support.md, phases 3 and 4): one run of a script with nobody
  watching, on the real TExecutor the editor uses. "EUOCli run" (clirun.pas) starts one and
  waits for its end; the MCP server (climcp.pas) keeps one alive between tool calls, so an
  agent can follow it, pause it, step it and read its variables.

  Both get the same rules from here, which are the owner's decisions and not defaults to tune:

  - A script runs WITHOUT a client unless the host passes a client number. Commands that
    need a client are then skipped, as the interpreter always skips them without one.
  - DISPLAY does not open a box (TEuoInterpreter.OnDisplay): the text becomes an event and
    the box is answered with its first button, or with the answer the host chose.
  - The run always ends: after its timeout, or when the main script starts over because it
    has no HALT (TExecutor.StopOnRestart), which would otherwise repeat for ever. The
    timeout counts the time the script runs, not the time it sits paused.
  - The commands in DefaultBlocked stop the run instead of running
    (TEuoInterpreter.BlockCommands) unless the host leaves them out of the blocked list.
    They reach beyond the script: start programs, switch the computer off, close or start
    clients, fetch a reply from the web and run it.

  The script's thread reports through a queue the host object owns (TRunHost); the main
  thread must keep pumping the LCL message loop while a run is alive (MENU builds its
  windows there, through TThread.Synchronize) and call Tick, which notices how the run ends.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpjson, EuoLock, EuoExecutor;

const
  // What a run will not run unless its host allows it.
  DefaultBlocked : array[0..4] of String = ('EXECUTE','SHUTDOWN','TERMINATE','UOXL','SEND');
  DefaultTimeoutSec = 60;
  MaxTraceLines     = 5000;
  // Events kept for a host that is not taking them; the oldest go first.
  MaxQueuedEvents   = 10000;

type
  TRunOptions = record
    ClientNr   : Integer;   // 0 = no client
    TimeoutSec : Integer;   // 0 = none
    Trace      : Boolean;
    ShowBoxes  : Boolean;   // DISPLAY opens its real box
    Answer     : String;    // 'OK', 'YES', 'NO', 'CANCEL', or '' = the box's first button
    PauseEnds  : Boolean;   // a paused script is a finished run: nobody can press Play
    AllowHint  : String;    // what to tell about a blocked command; %s is the command
  end;

  // What the running script reports, queued on its thread and taken on the main one.
  TRunHost = class(TObject)
  private
    FLock     : TEuoLock;
    FPlain    : TStringList;
    FJson     : TStringList;
    FExec     : TExecutor;
    FTraced   : Integer;
    FDropped  : Integer;
    procedure Add(const Plain : String; Obj : TJSONObject);
    procedure DrainLog;
  public
    Trace     : Boolean;
    Answer    : String;
    LastLine  : Integer;     // 0-based line that ran last, -1 before the first
    constructor Create(AExec : TExecutor);
    destructor  Destroy; override;
    function  Display(const Text, Buttons : String) : String;
    procedure Line(LineIdx : Integer);
    procedure Note(const Kind, Text : String);
    // The oldest Max events queued (all of them when Max is 0), in the order they happened:
    // as text lines, or as one JSON object per line. Returns how many are still queued.
    function  Take(List : TStrings; AsJson : Boolean; Max : Integer = 0) : Integer;
    // Events thrown away because nobody took them; reading it sets it back to 0.
    function  TakeDropped : Integer;
  end;

  TRunSession = class(TObject)
  private
    FExec      : TExecutor;
    FHost      : TRunHost;
    FOpt       : TRunOptions;
    FBreaks    : TStringList;   // "line=condition", for the host to list
    FEnded     : Boolean;
    FReason    : String;
    FDetail    : String;
    FEndLine   : Integer;
    FRunMs     : QWord;
    FLastTick  : QWord;
    FCounting  : Boolean;
    procedure Conclude(const Why : String);
    procedure CountTime;
  public
    constructor Create;
    destructor  Destroy; override;
    // Makes the engine, selects the client and loads the script; nothing runs yet.
    // False: Err says why, and NoClient that the reason is the client asked for.
    function  Start(const Script : String; const Opt : TRunOptions; Blocked : TStrings;
                out Err : String; out NoClient : Boolean) : Boolean;
    // Play, or (Step) the first line and then a pause.
    procedure Go(Step : Boolean = False);
    // Call often from the main thread, between Application.ProcessMessages calls.
    procedure Tick;
    // Ends the run now: 'interrupted', 'stopped', ...
    procedure Finish(const Why : String);
    // While it is alive: PAUSE, PLAY, STEPINTO, STEPOVER, STEPOUT, or run to a line (1-based).
    procedure SetState(Value : Cardinal);
    procedure RunToLine(Line : Integer);
    procedure SetBreakpoint(Line : Integer; const Condition : String);
    procedure RemoveBreakpoint(Line : Integer);
    procedure ClearBreakpoints;
    function  Take(List : TStrings; AsJson : Boolean; Max : Integer = 0) : Integer;
    function  Paused : Boolean;        // alive, and waiting for a step or Play
    function  NextLine : Integer;      // 1-based line that runs next
    function  LineText(Line : Integer) : String;
    function  ElapsedMs : QWord;
    function  ClientSkips : Cardinal;
    function  GetVar(const Name : String) : String;
    property  Exec : TExecutor read FExec;
    property  Host : TRunHost read FHost;
    property  Options : TRunOptions read FOpt;
    property  Breakpoints : TStringList read FBreaks;
    property  Ended : Boolean read FEnded;
    // halt, pause, timeout, error, client-lost, blocked, restart, or what Finish was given.
    property  Reason : String read FReason;
    property  Detail : String read FDetail;
    property  EndLine : Integer read FEndLine;   // 1-based, 0 when nothing ran
  end;

// An event as one line of JSON, with no spaces to pay for.
function OneLineJson(Obj : TJSONData) : String;
// The LCL's window classes, once per program: MENU builds real windows.
procedure EnsureLcl;
// Lets the script thread reach the main one for Ms milliseconds.
procedure PumpFor(Ms : Integer);

implementation

uses
  Windows, Forms, EuoInterpreter;

var
  LclReady : Boolean = False;

////////////////////////////////////////////////////////////////////////////////
function OneLineJson(Obj : TJSONData) : String;
begin
  Result:=Obj.FormatJSON([foSingleLineArray,foSingleLineObject,foSkipWhiteSpace]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure EnsureLcl;
begin
  if LclReady then Exit;
  Application.Initialize;
  LclReady:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure PumpFor(Ms : Integer);
var
  Start : QWord;
begin
  Start:=GetTickCount64;
  repeat
    Application.ProcessMessages;
    Sleep(5);
  until GetTickCount64-Start>=QWord(Ms);
end;

////////////////////////////////////////////////////////////////////////////////
function OneLine(const S : String) : String;
begin
  Result:=StringReplace(S,#13#10,' / ',[rfReplaceAll]);
  Result:=StringReplace(Result,#10,' / ',[rfReplaceAll]);
end;

////////////////////////////////////////////////////////////////////////////////
/// TRunHost ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TRunHost.Create(AExec : TExecutor);
begin
  inherited Create;
  FExec:=AExec;
  FLock:=TEuoLock.Create;
  FPlain:=TStringList.Create;
  FJson:=TStringList.Create;
  FTraced:=0;
  FDropped:=0;
  Trace:=False;
  Answer:='';
  LastLine:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TRunHost.Destroy;
begin
  FJson.Free;
  FPlain.Free;
  FLock.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
// Queues one event, as its text line and as its JSON object on one line. Takes the object.
procedure TRunHost.Add(const Plain : String; Obj : TJSONObject);
begin
  FLock.BeginWrite;
  try
    if FPlain.Count>=MaxQueuedEvents then
    begin
      FPlain.Delete(0);
      FJson.Delete(0);
      Inc(FDropped);
    end;
    FPlain.Add(Plain);
    FJson.Add(OneLineJson(Obj));
  finally
    FLock.EndWrite;
    Obj.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// What LOG has queued in the interpreter moves into this queue. Every event calls this
// first, so the lines a script logged before a DISPLAY come before it.
procedure TRunHost.DrainLog;
var
  Lines  : TStringList;
  i      : Integer;
  Obj    : TJSONObject;
  LineNr : Integer;
begin
  Lines:=TStringList.Create;
  try
    if not FExec.Parser.TakeLog(Lines) then Exit;
    for i:=0 to Lines.Count-1 do
    begin
      LineNr:=PtrUInt(Lines.Objects[i]);
      Obj:=TJSONObject.Create;
      Obj.Add('event','log');
      Obj.Add('line',LineNr);
      Obj.Add('text',Lines[i]);
      Add('['+IntToStr(LineNr)+'] log: '+Lines[i],Obj);
    end;
  finally
    Lines.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// TEuoInterpreter.OnDisplay, on the script's thread: no box. The answer is Answer when the
// box has that button, otherwise its first button.
function TRunHost.Display(const Text, Buttons : String) : String;
var
  Obj    : TJSONObject;
  LineNr : Integer;
begin
  if (Buttons='YESNO') or (Buttons='YESNOCANCEL') then Result:='Yes' else Result:='Ok';
  if Answer<>'' then
  begin
    if (Answer='CANCEL') and ((Buttons='OKCANCEL') or (Buttons='YESNOCANCEL')) then Result:='Cancel';
    if (Answer='NO') and ((Buttons='YESNO') or (Buttons='YESNOCANCEL')) then Result:='No';
    if (Answer='YES') and ((Buttons='YESNO') or (Buttons='YESNOCANCEL')) then Result:='Yes';
    if (Answer='OK') and ((Buttons='OK') or (Buttons='OKCANCEL')) then Result:='Ok';
  end;

  DrainLog;
  LineNr:=FExec.Parser.CurLine+1;
  Obj:=TJSONObject.Create;
  Obj.Add('event','display');
  Obj.Add('line',LineNr);
  Obj.Add('buttons',LowerCase(Buttons));
  Obj.Add('text',Text);
  Obj.Add('answer',Result);
  Add('['+IntToStr(LineNr)+'] display ('+LowerCase(Buttons)+', answered '+Result+'): '+OneLine(Text),Obj);
end;

////////////////////////////////////////////////////////////////////////////////
// TExecutor.OnLine, on the script's thread, before each line runs.
procedure TRunHost.Line(LineIdx : Integer);
var
  Obj  : TJSONObject;
  Text : String;
begin
  LastLine:=LineIdx;
  if not Trace then Exit;
  if FTraced>MaxTraceLines then Exit;
  Inc(FTraced);
  DrainLog;
  if FTraced>MaxTraceLines then
  begin
    Note('trace','the trace stops here: '+IntToStr(MaxTraceLines)+' lines were shown');
    Exit;
  end;
  Text:='';
  with FExec.Parser.ScrList do
    if (LineIdx>=0) and (LineIdx<Scr.Count) then Text:=Trim(Scr[LineIdx]);
  Obj:=TJSONObject.Create;
  Obj.Add('event','line');
  Obj.Add('line',LineIdx+1);
  Obj.Add('depth',Integer(FExec.Parser.ScrList.CallLevel));
  Obj.Add('text',Text);
  Add('['+IntToStr(LineIdx+1)+'] > '+Text,Obj);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunHost.Note(const Kind, Text : String);
var
  Obj : TJSONObject;
begin
  Obj:=TJSONObject.Create;
  Obj.Add('event',Kind);
  Obj.Add('text',Text);
  Add(Kind+': '+Text,Obj);
end;

////////////////////////////////////////////////////////////////////////////////
function TRunHost.Take(List : TStrings; AsJson : Boolean; Max : Integer) : Integer;
var
  N, i : Integer;
begin
  DrainLog;
  FLock.BeginWrite;
  try
    N:=FPlain.Count;
    if (Max>0) and (N>Max) then N:=Max;
    for i:=0 to N-1 do
      if AsJson then List.Add(FJson[i]) else List.Add(FPlain[i]);
    for i:=1 to N do
    begin
      FPlain.Delete(0);
      FJson.Delete(0);
    end;
    Result:=FPlain.Count;
  finally
    FLock.EndWrite;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunHost.TakeDropped : Integer;
begin
  FLock.BeginWrite;
  try
    Result:=FDropped;
    FDropped:=0;
  finally
    FLock.EndWrite;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// TRunSession ////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TRunSession.Create;
begin
  inherited Create;
  FExec:=nil;
  FHost:=nil;
  FBreaks:=TStringList.Create;
  FEnded:=False;
  FReason:='';
  FDetail:='';
  FEndLine:=0;
  FRunMs:=0;
  FCounting:=False;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TRunSession.Destroy;
begin
  if FExec<>nil then
  begin
    FExec.Parser.OnDisplay:=nil;
    FExec.OnLine:=nil;
    FExec.Free;
  end;
  FHost.Free;
  FBreaks.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.Start(const Script : String; const Opt : TRunOptions; Blocked : TStrings;
  out Err : String; out NoClient : Boolean) : Boolean;
var
  Start : QWord;
begin
  Result:=False;
  Err:='';
  NoClient:=False;
  FOpt:=Opt;
  EnsureLcl;

  FExec:=TExecutor.Create(0);
  // LoadScript only works once the script thread has idled a first time.
  Start:=GetTickCount64;
  while (not FExec.Paused) and (GetTickCount64-Start<3000) do Sleep(5);

  if Opt.ClientNr>0 then
    if not FExec.Parser.UOSel.SelectClient(Opt.ClientNr) then
    begin
      if FExec.Parser.UOSel.Cnt=0 then Err:='no UO client is running, or none EasyUO Reforged can drive'
      else Err:='there is no client number '+IntToStr(Opt.ClientNr)+' ("EUOCli clients" lists '+
        IntToStr(FExec.Parser.UOSel.Cnt)+')';
      NoClient:=True;
      Exit;
    end;

  FHost:=TRunHost.Create(FExec);
  FHost.Trace:=Opt.Trace;
  FHost.Answer:=Opt.Answer;
  if not Opt.ShowBoxes then FExec.Parser.OnDisplay:=FHost.Display;
  FExec.Parser.BlockCommands(Blocked);
  FExec.StopOnRestart:=True;
  FExec.OnLine:=FHost.Line;
  FExec.LoadScript(Script);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.Go(Step : Boolean);
begin
  FLastTick:=GetTickCount64;
  FCounting:=True;
  if Step then FExec.State:=STEPINTO else FExec.State:=PLAY;
end;

////////////////////////////////////////////////////////////////////////////////
// The time the script has been running: a pause does not count.
procedure TRunSession.CountTime;
var
  Now64 : QWord;
begin
  Now64:=GetTickCount64;
  if FCounting then Inc(FRunMs,Now64-FLastTick);
  FLastTick:=Now64;
  FCounting:=(not FEnded) and (FExec.State<>PAUSE);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.Tick;
var
  St : Cardinal;
begin
  if FEnded or (FExec=nil) or (FHost=nil) then Exit;
  CountTime;
  St:=FExec.State;
  if St=STOP then Conclude('halt')
  else if (St=PAUSE) and FOpt.PauseEnds then Conclude('pause')
  else if (FOpt.TimeoutSec>0) and (FRunMs>=QWord(FOpt.TimeoutSec)*1000) then Conclude('timeout')
  else if (FOpt.ClientNr>0) and (FExec.Parser.UOSel.Nr=0) then Conclude('client-lost');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.Finish(const Why : String);
begin
  if FEnded or (FExec=nil) or (FHost=nil) then Exit;
  CountTime;
  Conclude(Why);
end;

////////////////////////////////////////////////////////////////////////////////
// Stops the script and works out why and where the run ended.
procedure TRunSession.Conclude(const Why : String);
var
  Start  : QWord;
  ErrMsg : String;
  Notice : String;
begin
  FEnded:=True;
  FCounting:=False;
  FReason:=Why;

  // Stop it, and let the script thread come to rest before its state is read. Nothing runs
  // after this: TExecutor marks the script stopped before it breaks the wait it is in
  // (tests\EuoCliRunTests.pas, TestNothingRunsAfterATimeout).
  FExec.State:=STOP;
  Start:=GetTickCount64;
  while (not FExec.Paused) and (GetTickCount64-Start<3000) do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;

  ErrMsg:=FExec.LastError;
  FExec.LastError:='';
  Notice:=FExec.Parser.TakeMenuNotice;
  if Notice<>'' then FHost.Note('menu',Notice);
  FEndLine:=FHost.LastLine+1;
  FDetail:='';
  if ErrMsg<>'' then
  begin
    FReason:='error';
    FDetail:=ErrMsg;
  end
  else if FReason='halt' then
  begin
    if FExec.Parser.BlockedCmd<>'' then
    begin
      FReason:='blocked';
      FEndLine:=FExec.Parser.BlockedLine+1;
      FDetail:=LowerCase(FExec.Parser.BlockedCmd)+' is blocked';
      if FOpt.AllowHint<>'' then
        FDetail:=FDetail+': '+StringReplace(FOpt.AllowHint,'%s',LowerCase(FExec.Parser.BlockedCmd),[rfReplaceAll]);
    end
    else if FExec.Restarted then
    begin
      FReason:='restart';
      FDetail:='the script reached its end and started over: it has no halt';
    end;
  end
  else if FReason='timeout' then FDetail:='stopped by the timeout of '+IntToStr(FOpt.TimeoutSec)+' s'
  else if FReason='client-lost' then FDetail:='client '+IntToStr(FOpt.ClientNr)+' is gone'
  else if FReason='pause' then FDetail:='the script paused itself, and nobody is here to press Play';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.SetState(Value : Cardinal);
begin
  if FEnded or (FExec=nil) then Exit;
  CountTime;
  FExec.State:=Value;
  FCounting:=FExec.State<>PAUSE;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.RunToLine(Line : Integer);
begin
  if FEnded or (FExec=nil) then Exit;
  CountTime;
  FExec.RunToLine(Line);
  FCounting:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.SetBreakpoint(Line : Integer; const Condition : String);
var
  i : Integer;
begin
  if FExec=nil then Exit;
  FExec.SetBreakpointCondition(Line,Condition);
  for i:=FBreaks.Count-1 downto 0 do
    if FBreaks.Names[i]=IntToStr(Line) then FBreaks.Delete(i);
  FBreaks.Add(IntToStr(Line)+'='+Trim(Condition));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.RemoveBreakpoint(Line : Integer);
var
  i : Integer;
begin
  if FExec=nil then Exit;
  if FExec.HasBreakpoint(Line) then FExec.ToggleBreakpoint(Line);
  for i:=FBreaks.Count-1 downto 0 do
    if FBreaks.Names[i]=IntToStr(Line) then FBreaks.Delete(i);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TRunSession.ClearBreakpoints;
begin
  if FExec<>nil then FExec.ClearAllBreakpoints;
  FBreaks.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.Take(List : TStrings; AsJson : Boolean; Max : Integer) : Integer;
begin
  if FHost=nil then Exit(0);
  Result:=FHost.Take(List,AsJson,Max);
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.Paused : Boolean;
begin
  Result:=(not FEnded) and (FExec<>nil) and (FExec.State=PAUSE) and FExec.Paused;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.NextLine : Integer;
begin
  if FExec=nil then Exit(0);
  Result:=Integer(FExec.NextLine)+1;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.LineText(Line : Integer) : String;
begin
  Result:='';
  if FExec=nil then Exit;
  with FExec.Parser.ScrList do
    if (Line>=1) and (Line<=Scr.Count) then Result:=Trim(Scr[Line-1]);
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.ElapsedMs : QWord;
begin
  Result:=FRunMs;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.ClientSkips : Cardinal;
begin
  if FExec=nil then Exit(0);
  Result:=FExec.Parser.ClientSkips;
end;

////////////////////////////////////////////////////////////////////////////////
function TRunSession.GetVar(const Name : String) : String;
begin
  if FExec=nil then Exit('');
  Result:=FExec.GetVar(Name);
end;

end.
