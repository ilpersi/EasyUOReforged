unit clirun;

{
  Port addition (docs\agent-support.md, phase 3): the EUOCli commands that need the engine.

    run      runs a script with nobody watching, on the real TExecutor the editor uses, and
             prints what happens: what the script logs, what DISPLAY would have shown and
             how it was answered, why and where the run ended.
    vars     reads variables from a client, without a script.
    clients  lists the UO clients found.

  "run" is built for an AI coding agent, which cannot click a message box, press Stop or
  look at the game, and whose scripts nobody has read yet:

  - A script runs WITHOUT a client unless the command line says --client N. Commands that
    need a client are skipped, as the interpreter always skips them without one, so the
    logic can be tried safely; acting on the user's character is an explicit choice that
    shows in the command the agent asks the user to approve.
  - DISPLAY does not open a box (TEuoInterpreter.OnDisplay): the text is printed and the
    box is answered with its first button, or with --answer.
  - The run always ends: after --timeout (60 s unless said), or when the main script starts
    over because it has no HALT (TExecutor.StopOnRestart), which would otherwise repeat for ever.
  - EXECUTE, SHUTDOWN, TERMINATE, UOXL and SEND stop the run instead of running
    (TEuoInterpreter.BlockCommands) unless --allow names them. They reach beyond the script:
    start programs, switch the computer off, close or start clients, fetch and run a reply.

  The script's thread reports through a queue this unit's host object owns; the main thread
  pumps the LCL message loop (MENU builds its windows there, through TThread.Synchronize) and
  prints the queue as it fills. Like clicheck.pas everything is in the unit, so the test suite
  runs scripts through it the way the program does (tests\EuoCliRunTests.pas).

  Exit codes of "run": 0 the script stopped itself (HALT, STOP, PAUSE); 2 the command line is
  wrong or the script cannot be read; 3 timeout; 4 a command raised an error; 5 the client
  asked for is not there, or went away; 6 a blocked command; 7 the script started over;
  8 interrupted (Ctrl+C). 1 stays "check --strict found a warning".
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  CLI_TIMEOUT     = 3;
  CLI_ERROR       = 4;
  CLI_NO_CLIENT   = 5;
  CLI_BLOCKED     = 6;
  CLI_RESTARTED   = 7;
  CLI_INTERRUPTED = 8;

  // What "run" will not run unless --allow names it.
  DefaultBlocked : array[0..4] of String = ('EXECUTE','SHUTDOWN','TERMINATE','UOXL','SEND');
  DefaultTimeoutSec = 60;
  MaxTraceLines     = 5000;

type
  // Where a line of output goes the moment it exists, when a host wants it then (the
  // program: straight to standard output). nil collects everything in Output instead.
  TCliLineProc = procedure(const Line : String);

var
  CliOnLine      : TCliLineProc = nil;
  // Set by the program's Ctrl+C handler; "run" stops the script and ends.
  CliInterrupted : Boolean = False;

function RunRun(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
function RunVars(Args : TStrings; Output : TStrings) : Integer;
function RunClients(Args : TStrings; Output : TStrings) : Integer;

procedure RunHelp(Output : TStrings);
procedure VarsHelp(Output : TStrings);
procedure ClientsHelp(Output : TStrings);

implementation

uses
  Windows, Forms, fpjson, EuoInterpreter, EuoExecutor, EuoLock, scriptfile, clicheck;

type
  // What the running script reports, queued on its thread and printed on the main one.
  TRunHost = class(TObject)
  private
    FLock     : TEuoLock;
    FQueue    : TStringList;
    FExec     : TExecutor;
    FTraced   : Integer;
    procedure Add(const Plain : String; Obj : TJSONObject);
    procedure DrainLog;
  public
    Json      : Boolean;
    Trace     : Boolean;
    Answer    : String;      // '' = the box's first button
    LastLine  : Integer;     // 0-based line that ran last, -1 before the first
    constructor Create(AExec : TExecutor);
    destructor  Destroy; override;
    function  Display(const Text, Buttons : String) : String;
    procedure Line(LineIdx : Integer);
    procedure Note(const Kind, Text : String);
    // Everything queued so far, in the order it happened, into List.
    procedure Take(List : TStrings);
  end;

var
  LclReady : Boolean = False;

////////////////////////////////////////////////////////////////////////////////
procedure Emit(Output : TStrings; const Line : String);
begin
  if Assigned(CliOnLine) then CliOnLine(Line)
  else Output.Add(Line);
end;

////////////////////////////////////////////////////////////////////////////////
// An event as one line of JSON, with no spaces to pay for.
function OneLineJson(Obj : TJSONObject) : String;
begin
  Result:=Obj.FormatJSON([foSingleLineArray,foSingleLineObject,foSkipWhiteSpace]);
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
  FQueue:=TStringList.Create;
  FTraced:=0;
  Json:=False;
  Trace:=False;
  Answer:='';
  LastLine:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TRunHost.Destroy;
begin
  FQueue.Free;
  FLock.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
// Queues one event: the plain line, or the JSON object as one line. Takes the object.
procedure TRunHost.Add(const Plain : String; Obj : TJSONObject);
begin
  FLock.BeginWrite;
  try
    if Json then FQueue.Add(OneLineJson(Obj)) else FQueue.Add(Plain);
  finally
    FLock.EndWrite;
    Obj.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// What LOG has queued in the interpreter moves into this queue. Every event calls this
// first, so the lines a script logged before a DISPLAY are printed before it.
procedure TRunHost.DrainLog;
var
  Lines : TStringList;
  i     : Integer;
  Obj   : TJSONObject;
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
// TEuoInterpreter.OnDisplay, on the script's thread: no box. The answer is --answer when the
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
procedure TRunHost.Take(List : TStrings);
begin
  DrainLog;
  FLock.BeginWrite;
  try
    List.AddStrings(FQueue);
    FQueue.Clear;
  finally
    FLock.EndWrite;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// The commands ///////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure RunHelp(Output : TStrings);
begin
  Output.Add('EUOCli run <script.euo> [--client <n>] [--timeout <seconds>] [--json] [--trace]');
  Output.Add('           [--dump <variables>] [--answer ok|yes|no|cancel] [--allow <commands>]');
  Output.Add('');
  Output.Add('Runs a script with nobody watching and prints what happens: what it logs with "log",');
  Output.Add('what "display" would have shown, and why and where the run ended.');
  Output.Add('');
  Output.Add('  <script>            a script file; - reads the script from standard input');
  Output.Add('  --client <n>        run it on UO client number n (see "EUOCli clients"). Without');
  Output.Add('                      this the script runs with NO client: commands that need one are');
  Output.Add('                      skipped, and nothing happens in the game');
  Output.Add('  --timeout <sec>     stop the script after this many seconds. Default: 60. 0: never');
  Output.Add('  --json              print one JSON object per line instead of text');
  Output.Add('  --trace             print every line before it runs (the first '+IntToStr(MaxTraceLines)+')');
  Output.Add('  --dump <variables>  print these variables when the run ends: %a,%b,#FindCnt');
  Output.Add('  --answer <button>   how to answer "display" boxes that have that button.');
  Output.Add('                      Default: the first button (ok, or yes)');
  Output.Add('  --show-display      open the real message boxes instead, and wait for a click');
  Output.Add('  --allow <commands>  run these although they are blocked: execute,shutdown,terminate,');
  Output.Add('                      uoxl,send. A blocked command stops the run');
  Output.Add('');
  Output.Add('Exit code: 0 the script stopped itself; 2 wrong command line or unreadable script;');
  Output.Add('3 timeout; 4 a command raised an error; 5 the client is not there; 6 a blocked command;');
  Output.Add('7 the script reached its end and started over (it has no halt); 8 interrupted.');
end;

////////////////////////////////////////////////////////////////////////////////
procedure VarsHelp(Output : TStrings);
begin
  Output.Add('EUOCli vars <variable> [more variables] [--client <n>] [--json]');
  Output.Add('EUOCli vars --all [--client <n>] [--json]');
  Output.Add('');
  Output.Add('Reads variables from a UO client, without a script: EUOCli vars #CharPosX #CharPosY');
  Output.Add('');
  Output.Add('  <variable>     a #variable (the # may be left out), or a persistent *variable');
  Output.Add('  --all          every #variable');
  Output.Add('  --client <n>   which client (see "EUOCli clients"). Default: 1 when one is running.');
  Output.Add('                 0 reads without a client: client variables then read N/A');
  Output.Add('  --json         print JSON');
  Output.Add('');
  Output.Add('Exit code: 0; 2 wrong command line; 5 the client asked for is not there.');
end;

////////////////////////////////////////////////////////////////////////////////
procedure ClientsHelp(Output : TStrings);
begin
  Output.Add('EUOCli clients [--json]');
  Output.Add('');
  Output.Add('Lists the UO clients EasyUO Reforged can drive: number, version, window title and the');
  Output.Add('character logged in. The number is what --client takes.');
end;

////////////////////////////////////////////////////////////////////////////////
function Fail(Output : TStrings; const Cmd, Msg : String) : Integer;
begin
  Output.Add('EUOCli '+Cmd+': '+Msg);
  Output.Add('Try: EUOCli help '+Cmd);
  Result:=CLI_USAGE;
end;

////////////////////////////////////////////////////////////////////////////////
// "60", "60s" -> 60. False when it is not a number of seconds.
function ParseSeconds(S : String; out Sec : Integer) : Boolean;
begin
  S:=LowerCase(Trim(S));
  if (S<>'') and (S[Length(S)]='s') then Delete(S,Length(S),1);
  Result:=TryStrToInt(S,Sec) and (Sec>=0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SplitList(const S : String; List : TStrings);
var
  SL : TStringList;
  i  : Integer;
begin
  SL:=TStringList.Create;
  try
    SL.Delimiter:=',';
    SL.StrictDelimiter:=True;
    SL.DelimitedText:=S;
    for i:=0 to SL.Count-1 do
      if Trim(SL[i])<>'' then List.Add(Trim(SL[i]));
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunRun(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
var
  FileName   : String;
  ClientNr   : Integer;
  TimeoutSec : Integer;
  Json       : Boolean;
  Trace      : Boolean;
  ShowBoxes  : Boolean;
  Answer     : String;
  Dump       : TStringList;
  Allow      : TStringList;
  Blocked    : TStringList;
  Script     : String;
  Exec       : TExecutor;
  Host       : TRunHost;
  Pending    : TStringList;
  i          : Integer;
  A          : String;
  Start      : QWord;
  Reason     : String;
  Detail     : String;
  ErrMsg     : String;
  Obj        : TJSONObject;
  VarsObj    : TJSONObject;
  Arr        : TJSONArray;
  ElapsedMs  : QWord;
  EndLine    : Integer;
  Plain      : String;

  function Next(const Opt : String; out Value : String) : Boolean;
  begin
    Inc(i);
    Result:=i<Args.Count;
    if Result then Value:=Args[i]
    else RunRun:=Fail(Output,'run',Opt+' needs a value');
  end;

  procedure Flush;
  var
    k : Integer;
  begin
    Pending.Clear;
    Host.Take(Pending);
    for k:=0 to Pending.Count-1 do Emit(Output,Pending[k]);
  end;

begin
  Result:=CLI_OK;
  Dump:=TStringList.Create;
  Allow:=TStringList.Create;
  Blocked:=TStringList.Create;
  Pending:=TStringList.Create;
  Exec:=nil;
  Host:=nil;
  try
    // ---- the command line ---------------------------------------------------------------
    FileName:='';
    ClientNr:=0;
    TimeoutSec:=DefaultTimeoutSec;
    Json:=False;
    Trace:=False;
    ShowBoxes:=False;
    Answer:='';
    i:=0;
    while i<Args.Count do
    begin
      A:=Args[i];
      if A='--json' then Json:=True
      else if A='--trace' then Trace:=True
      else if A='--show-display' then ShowBoxes:=True
      else if A='--no-client' then ClientNr:=0
      else if A='--client' then
      begin
        if not Next(A,A) then Exit;
        if not (TryStrToInt(A,ClientNr) and (ClientNr>=0)) then
          Exit(Fail(Output,'run','--client needs a client number, as "EUOCli clients" lists them'));
      end
      else if A='--timeout' then
      begin
        if not Next(A,A) then Exit;
        if not ParseSeconds(A,TimeoutSec) then
          Exit(Fail(Output,'run','--timeout needs a number of seconds'));
      end
      else if A='--dump' then
      begin
        if not Next(A,A) then Exit;
        SplitList(A,Dump);
      end
      else if A='--allow' then
      begin
        if not Next(A,A) then Exit;
        SplitList(UpperCase(A),Allow);
      end
      else if A='--answer' then
      begin
        if not Next(A,A) then Exit;
        Answer:=UpperCase(A);
        if (Answer<>'OK') and (Answer<>'YES') and (Answer<>'NO') and (Answer<>'CANCEL') then
          Exit(Fail(Output,'run','--answer is ok, yes, no or cancel'));
      end
      else if (A<>'-') and (Copy(A,1,1)='-') then Exit(Fail(Output,'run','unknown option '+A))
      else if FileName<>'' then Exit(Fail(Output,'run','one script at a time'))
      else FileName:=A;
      Inc(i);
    end;
    if FileName='' then Exit(Fail(Output,'run','no script given'));
    for i:=0 to Allow.Count-1 do
    begin
      A:='';
      for EndLine:=Low(DefaultBlocked) to High(DefaultBlocked) do
        if DefaultBlocked[EndLine]=Allow[i] then A:=Allow[i];
      if A='' then Exit(Fail(Output,'run','--allow takes execute, shutdown, terminate, uoxl or send; "'+
        LowerCase(Allow[i])+'" is not a blocked command'));
    end;

    if FileName='-' then
    begin
      Script:=StdInText;
      FileName:='<stdin>';
    end
    else begin
      if not FileExists(FileName) then Exit(Fail(Output,'run','file not found: '+FileName));
      try
        Script:=LoadScriptFileAsUTF8(FileName);
      except
        on E : Exception do Exit(Fail(Output,'run','cannot read '+FileName+': '+E.Message));
      end;
    end;
    if Trim(Script)='' then Exit(Fail(Output,'run','the script is empty'));

    for i:=Low(DefaultBlocked) to High(DefaultBlocked) do
      if Allow.IndexOf(DefaultBlocked[i])<0 then Blocked.Add(DefaultBlocked[i]);

    // ---- the engine ----------------------------------------------------------------------
    // MENU builds real windows on the main thread; they need the LCL's window classes.
    if not LclReady then
    begin
      Application.Initialize;
      LclReady:=True;
    end;
    CliInterrupted:=False;

    Exec:=TExecutor.Create(0);
    // LoadScript only works once the script thread has idled a first time.
    Start:=GetTickCount64;
    while (not Exec.Paused) and (GetTickCount64-Start<3000) do Sleep(5);

    if ClientNr>0 then
      if not Exec.Parser.UOSel.SelectClient(ClientNr) then
      begin
        if Exec.Parser.UOSel.Cnt=0 then A:='no UO client is running, or none EasyUO Reforged can drive'
        else A:='there is no client number '+IntToStr(ClientNr)+' ("EUOCli clients" lists '+
          IntToStr(Exec.Parser.UOSel.Cnt)+')';
        Output.Add('EUOCli run: '+A);
        Exit(CLI_NO_CLIENT);
      end;

    Host:=TRunHost.Create(Exec);
    Host.Json:=Json;
    Host.Trace:=Trace;
    Host.Answer:=Answer;
    if not ShowBoxes then Exec.Parser.OnDisplay:=Host.Display;
    Exec.Parser.BlockCommands(Blocked);
    Exec.StopOnRestart:=True;
    Exec.OnLine:=Host.Line;

    Obj:=TJSONObject.Create;
    try
      Obj.Add('event','start');
      Obj.Add('file',FileName);
      Obj.Add('client',ClientNr);
      Obj.Add('timeout',TimeoutSec);
      Arr:=TJSONArray.Create;
      for i:=0 to Blocked.Count-1 do Arr.Add(LowerCase(Blocked[i]));
      Obj.Add('blocked',Arr);
      if Json then Emit(Output,OneLineJson(Obj))
      else begin
        if ClientNr>0 then A:='on client '+IntToStr(ClientNr)
        else A:='without a client (commands that need one are skipped)';
        Emit(Output,'running '+FileName+' '+A);
      end;
    finally
      Obj.Free;
    end;

    // ---- the run -------------------------------------------------------------------------
    Exec.LoadScript(Script);
    Start:=GetTickCount64;
    Exec.State:=PLAY;
    Reason:='';
    while Reason='' do
    begin
      Application.ProcessMessages;
      Flush;
      if Exec.State=STOP then Reason:='halt'
      else if Exec.State=PAUSE then Reason:='pause'
      else if CliInterrupted then Reason:='interrupted'
      else if (TimeoutSec>0) and (GetTickCount64-Start>=QWord(TimeoutSec)*1000) then Reason:='timeout'
      else if (ClientNr>0) and (Exec.Parser.UOSel.Nr=0) then Reason:='client-lost'
      else Sleep(5);
    end;
    ElapsedMs:=GetTickCount64-Start;

    // Stop it, and let the script thread come to rest before its state is read. Nothing runs
    // after this: TExecutor marks the script stopped before it breaks the wait it is in
    // (tests\EuoCliRunTests.pas, TestNothingRunsAfterATimeout).
    Exec.State:=STOP;
    Start:=GetTickCount64;
    while (not Exec.Paused) and (GetTickCount64-Start<3000) do
    begin
      Application.ProcessMessages;
      Sleep(5);
    end;

    // ---- how it ended --------------------------------------------------------------------
    ErrMsg:=Exec.LastError;
    Exec.LastError:='';
    A:=Exec.Parser.TakeMenuNotice;
    if A<>'' then Host.Note('menu',A);
    EndLine:=Host.LastLine+1;
    Detail:='';
    if ErrMsg<>'' then
    begin
      Reason:='error';
      Detail:=ErrMsg;
    end
    else if Reason='halt' then
    begin
      if Exec.Parser.BlockedCmd<>'' then
      begin
        Reason:='blocked';
        EndLine:=Exec.Parser.BlockedLine+1;
        Detail:=LowerCase(Exec.Parser.BlockedCmd)+' is blocked: rerun with --allow '+
          LowerCase(Exec.Parser.BlockedCmd)+' if the user agrees';
      end
      else if Exec.Restarted then
      begin
        Reason:='restart';
        Detail:='the script reached its end and started over: it has no halt';
      end;
    end
    else if Reason='timeout' then Detail:='stopped by the timeout of '+IntToStr(TimeoutSec)+' s'
    else if Reason='client-lost' then Detail:='client '+IntToStr(ClientNr)+' is gone'
    else if Reason='pause' then Detail:='the script paused itself, and nobody is here to press Play';
    Flush;

    if Reason='timeout' then Result:=CLI_TIMEOUT
    else if Reason='error' then Result:=CLI_ERROR
    else if Reason='client-lost' then Result:=CLI_NO_CLIENT
    else if Reason='blocked' then Result:=CLI_BLOCKED
    else if Reason='restart' then Result:=CLI_RESTARTED
    else if Reason='interrupted' then Result:=CLI_INTERRUPTED
    else Result:=CLI_OK;

    VarsObj:=TJSONObject.Create;
    for i:=0 to Dump.Count-1 do VarsObj.Add(Dump[i],Exec.GetVar(Dump[i]));

    Obj:=TJSONObject.Create;
    try
      Obj.Add('event','end');
      Obj.Add('reason',Reason);
      Obj.Add('detail',Detail);
      Obj.Add('line',EndLine);
      Obj.Add('exitCode',Result);
      Obj.Add('elapsedMs',Int64(ElapsedMs));
      Obj.Add('client',ClientNr);
      Obj.Add('clientLinesSkipped',Int64(Exec.Parser.ClientSkips));
      Obj.Add('vars',VarsObj);
      if Json then Emit(Output,OneLineJson(Obj))
      else begin
        Plain:='ended: '+Reason;
        if EndLine>0 then Plain:=Plain+' at line '+IntToStr(EndLine);
        Plain:=Plain+' after '+FormatFloat('0.0',ElapsedMs/1000,DefaultFormatSettings)+' s';
        if Detail<>'' then Plain:=Plain+' ('+Detail+')';
        Emit(Output,Plain);
        if Exec.Parser.ClientSkips=1 then
          Emit(Output,'1 line was skipped because its command needs a client')
        else if Exec.Parser.ClientSkips>1 then
          Emit(Output,IntToStr(Exec.Parser.ClientSkips)+' lines were skipped because their command needs a client');
        for i:=0 to Dump.Count-1 do
          Emit(Output,Dump[i]+' = '+VarsObj.Get(Dump[i],''));
      end;
    finally
      Obj.Free;
    end;
  finally
    if Exec<>nil then
    begin
      Exec.Parser.OnDisplay:=nil;
      Exec.OnLine:=nil;
      Exec.Free;
    end;
    Host.Free;
    Pending.Free;
    Blocked.Free;
    Allow.Free;
    Dump.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunVars(Args : TStrings; Output : TStrings) : Integer;
var
  Names    : TStringList;
  All      : TStringList;
  Interp   : TEuoInterpreter;
  ClientNr : Integer;
  Json     : Boolean;
  Every    : Boolean;
  i        : Integer;
  A        : String;
  Obj      : TJSONObject;
  VarsObj  : TJSONObject;
begin
  Result:=CLI_OK;
  Names:=TStringList.Create;
  All:=TStringList.Create;
  Interp:=nil;
  try
    ClientNr:=-1;   // not said: 1 when a client is running
    Json:=False;
    Every:=False;
    i:=0;
    while i<Args.Count do
    begin
      A:=Args[i];
      if A='--json' then Json:=True
      else if A='--all' then Every:=True
      else if A='--no-client' then ClientNr:=0
      else if A='--client' then
      begin
        Inc(i);
        if (i>=Args.Count) or not (TryStrToInt(Args[i],ClientNr) and (ClientNr>=0)) then
          Exit(Fail(Output,'vars','--client needs a client number, as "EUOCli clients" lists them'));
      end
      else if Copy(A,1,2)='--' then Exit(Fail(Output,'vars','unknown option '+A))
      else begin
        // A bare name is a #variable. % and ! variables belong to a running script.
        if A[1] in ['%','!'] then
          Exit(Fail(Output,'vars',A+' is a script''s own variable: only #variables and *variables can be read without a script'));
        if not (A[1] in ['#','*']) then A:='#'+A;
        Names.Add(A);
      end;
      Inc(i);
    end;
    if (Names.Count=0) and not Every then Exit(Fail(Output,'vars','no variable given'));

    Interp:=TEuoInterpreter.Create(0);
    if Every then
    begin
      Interp.GetVariableNames(All);
      All.Sort;
      for i:=0 to All.Count-1 do Names.Add('#'+All[i]);
    end;
    if ClientNr<0 then
    begin
      if Interp.UOSel.Cnt>0 then ClientNr:=1 else ClientNr:=0;
    end;
    if ClientNr>0 then
      if not Interp.UOSel.SelectClient(ClientNr) then
      begin
        Output.Add('EUOCli vars: there is no client number '+IntToStr(ClientNr)+' ("EUOCli clients" lists '+
          IntToStr(Interp.UOSel.Cnt)+')');
        Exit(CLI_NO_CLIENT);
      end;

    if Json then
    begin
      Obj:=TJSONObject.Create;
      try
        Obj.Add('client',ClientNr);
        VarsObj:=TJSONObject.Create;
        for i:=0 to Names.Count-1 do
          if VarsObj.IndexOfName(Names[i])<0 then VarsObj.Add(Names[i],Interp.GetVar(Names[i]));
        Obj.Add('vars',VarsObj);
        Output.Text:=Obj.FormatJSON;
      finally
        Obj.Free;
      end;
    end
    else begin
      if ClientNr=0 then Output.Add('no client: variables of the client read N/A');
      for i:=0 to Names.Count-1 do
        Output.Add(Names[i]+' = '+Interp.GetVar(Names[i]));
    end;
  finally
    if Interp<>nil then Interp.Free;
    All.Free;
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunClients(Args : TStrings; Output : TStrings) : Integer;
var
  Interp  : TEuoInterpreter;
  Json    : Boolean;
  i, N    : Integer;
  Obj     : TJSONObject;
  Item    : TJSONObject;
  Arr     : TJSONArray;
  Name    : String;
  Logged  : Boolean;
  Line    : String;
begin
  Result:=CLI_OK;
  Json:=False;
  for i:=0 to Args.Count-1 do
    if Args[i]='--json' then Json:=True
    else Exit(Fail(Output,'clients','unknown option '+Args[i]));

  Interp:=TEuoInterpreter.Create(0);
  Obj:=TJSONObject.Create;
  try
    N:=Interp.UOSel.Cnt;
    Arr:=TJSONArray.Create;
    Obj.Add('clients',Arr);
    for i:=1 to N do
    begin
      Name:='';
      Logged:=False;
      if Interp.UOSel.SelectClient(i) then
      begin
        Logged:=Interp.GetVar('#CliLogged')='1';
        if Logged then Name:=Interp.GetVar('#CharName');
      end;
      Item:=TJSONObject.Create;
      Item.Add('nr',i);
      Item.Add('pid',Int64(Interp.UOSel.GetPID(i)));
      Item.Add('version',Interp.UOSel.GetVer(i));
      Item.Add('title',Interp.UOSel.GetTitle(i));
      Item.Add('loggedIn',Logged);
      Item.Add('character',Name);
      Arr.Add(Item);
      Line:=IntToStr(i)+'  '+Interp.UOSel.GetVer(i)+'  "'+Interp.UOSel.GetTitle(i)+'"  ';
      if Logged then Line:=Line+'character '+Name else Line:=Line+'nobody logged in';
      if not Json then Output.Add(Line);
    end;
    Obj.Add('denied',Int64(Interp.UOSel.DeniedCnt));
    if Json then Output.Text:=Obj.FormatJSON
    else begin
      if N=0 then Output.Add('no UO client found');
      if Interp.UOSel.DeniedCnt>0 then
        Output.Add(IntToStr(Interp.UOSel.DeniedCnt)+' client(s) run as administrator and cannot be opened: '+
          'start this program as administrator too, or the client without');
    end;
  finally
    Obj.Free;
    Interp.Free;
  end;
end;

end.
