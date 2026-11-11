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

  The run itself, with these rules, is clisession.pas's TRunSession, which the MCP server
  (climcp.pas) uses too. This unit reads the command line, starts a session, pumps the LCL
  message loop until it ends and prints what it reports. Like clicheck.pas everything is in
  the unit, so the test suite runs scripts through it the way the program does
  (tests\EuoCliRunTests.pas).

  Exit codes of "run": 0 the script stopped itself (HALT, STOP, PAUSE); 2 the command line is
  wrong or the script cannot be read; 3 timeout; 4 a command raised an error; 5 the client
  asked for is not there, or went away; 6 a blocked command; 7 the script started over;
  8 interrupted (Ctrl+C). 1 stays "check --strict found a warning".
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

const
  CLI_TIMEOUT     = 3;
  CLI_ERROR       = 4;
  CLI_NO_CLIENT   = 5;
  CLI_BLOCKED     = 6;
  CLI_RESTARTED   = 7;
  CLI_INTERRUPTED = 8;

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

// What "vars" and "clients" print with --json, for the MCP server too.
// ReadClientVars: Names are #variables and *variables; Every adds every #variable to them.
// ClientNr < 0 becomes 1 when a client is running and 0 (no client) when none is. nil when
// the client asked for is not there: Err says so.
function ReadClientVars(Names : TStrings; Every : Boolean; var ClientNr : Integer; out Err : String) : TJSONObject;
function ListClients : TJSONObject;

implementation

uses
  Windows, Forms, EuoInterpreter, EuoExecutor, scriptfile, clicheck, clisession;

////////////////////////////////////////////////////////////////////////////////
procedure Emit(Output : TStrings; const Line : String);
begin
  if Assigned(CliOnLine) then CliOnLine(Line)
  else Output.Add(Line);
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
  Opt        : TRunOptions;
  Json       : Boolean;
  Dump       : TStringList;
  Allow      : TStringList;
  Blocked    : TStringList;
  Script     : String;
  Session    : TRunSession;
  Pending    : TStringList;
  i, k       : Integer;
  A          : String;
  NoClient   : Boolean;
  Obj        : TJSONObject;
  VarsObj    : TJSONObject;
  Arr        : TJSONArray;
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
    n : Integer;
  begin
    Pending.Clear;
    Session.Take(Pending,Json);
    for n:=0 to Pending.Count-1 do Emit(Output,Pending[n]);
  end;

begin
  Result:=CLI_OK;
  Dump:=TStringList.Create;
  Allow:=TStringList.Create;
  Blocked:=TStringList.Create;
  Pending:=TStringList.Create;
  Session:=nil;
  try
    // ---- the command line ---------------------------------------------------------------
    FileName:='';
    Opt.ClientNr:=0;
    Opt.TimeoutSec:=DefaultTimeoutSec;
    Opt.Trace:=False;
    Opt.ShowBoxes:=False;
    Opt.Answer:='';
    Opt.PauseEnds:=True;
    Opt.AllowHint:='rerun with --allow %s if the user agrees';
    Json:=False;
    i:=0;
    while i<Args.Count do
    begin
      A:=Args[i];
      if A='--json' then Json:=True
      else if A='--trace' then Opt.Trace:=True
      else if A='--show-display' then Opt.ShowBoxes:=True
      else if A='--no-client' then Opt.ClientNr:=0
      else if A='--client' then
      begin
        if not Next(A,A) then Exit;
        if not (TryStrToInt(A,Opt.ClientNr) and (Opt.ClientNr>=0)) then
          Exit(Fail(Output,'run','--client needs a client number, as "EUOCli clients" lists them'));
      end
      else if A='--timeout' then
      begin
        if not Next(A,A) then Exit;
        if not ParseSeconds(A,Opt.TimeoutSec) then
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
        Opt.Answer:=UpperCase(A);
        if (Opt.Answer<>'OK') and (Opt.Answer<>'YES') and (Opt.Answer<>'NO') and (Opt.Answer<>'CANCEL') then
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
      for k:=Low(DefaultBlocked) to High(DefaultBlocked) do
        if DefaultBlocked[k]=Allow[i] then A:=Allow[i];
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
    CliInterrupted:=False;
    Session:=TRunSession.Create;
    if not Session.Start(Script,Opt,Blocked,A,NoClient) then
    begin
      Output.Add('EUOCli run: '+A);
      Exit(CLI_NO_CLIENT);
    end;

    Obj:=TJSONObject.Create;
    try
      Obj.Add('event','start');
      Obj.Add('file',FileName);
      Obj.Add('client',Opt.ClientNr);
      Obj.Add('timeout',Opt.TimeoutSec);
      Arr:=TJSONArray.Create;
      for i:=0 to Blocked.Count-1 do Arr.Add(LowerCase(Blocked[i]));
      Obj.Add('blocked',Arr);
      if Json then Emit(Output,OneLineJson(Obj))
      else begin
        if Opt.ClientNr>0 then A:='on client '+IntToStr(Opt.ClientNr)
        else A:='without a client (commands that need one are skipped)';
        Emit(Output,'running '+FileName+' '+A);
      end;
    finally
      Obj.Free;
    end;

    // ---- the run -------------------------------------------------------------------------
    Session.Go;
    while not Session.Ended do
    begin
      Application.ProcessMessages;
      Flush;
      if CliInterrupted then Session.Finish('interrupted')
      else Session.Tick;
      if not Session.Ended then Sleep(5);
    end;
    Flush;

    // ---- how it ended --------------------------------------------------------------------
    if Session.Reason='timeout' then Result:=CLI_TIMEOUT
    else if Session.Reason='error' then Result:=CLI_ERROR
    else if Session.Reason='client-lost' then Result:=CLI_NO_CLIENT
    else if Session.Reason='blocked' then Result:=CLI_BLOCKED
    else if Session.Reason='restart' then Result:=CLI_RESTARTED
    else if Session.Reason='interrupted' then Result:=CLI_INTERRUPTED
    else Result:=CLI_OK;

    VarsObj:=TJSONObject.Create;
    for i:=0 to Dump.Count-1 do
      if VarsObj.IndexOfName(Dump[i])<0 then VarsObj.Add(Dump[i],Session.GetVar(Dump[i]));

    Obj:=TJSONObject.Create;
    try
      Obj.Add('event','end');
      Obj.Add('reason',Session.Reason);
      Obj.Add('detail',Session.Detail);
      Obj.Add('line',Session.EndLine);
      Obj.Add('exitCode',Result);
      Obj.Add('elapsedMs',Int64(Session.ElapsedMs));
      Obj.Add('client',Opt.ClientNr);
      Obj.Add('clientLinesSkipped',Int64(Session.ClientSkips));
      Obj.Add('vars',VarsObj);
      if Json then Emit(Output,OneLineJson(Obj))
      else begin
        Plain:='ended: '+Session.Reason;
        if Session.EndLine>0 then Plain:=Plain+' at line '+IntToStr(Session.EndLine);
        Plain:=Plain+' after '+FormatFloat('0.0',Session.ElapsedMs/1000,DefaultFormatSettings)+' s';
        if Session.Detail<>'' then Plain:=Plain+' ('+Session.Detail+')';
        Emit(Output,Plain);
        if Session.ClientSkips=1 then
          Emit(Output,'1 line was skipped because its command needs a client')
        else if Session.ClientSkips>1 then
          Emit(Output,IntToStr(Session.ClientSkips)+' lines were skipped because their command needs a client');
        for i:=0 to Dump.Count-1 do
          Emit(Output,Dump[i]+' = '+VarsObj.Get(Dump[i],''));
      end;
    finally
      Obj.Free;
    end;
  finally
    Session.Free;
    Pending.Free;
    Blocked.Free;
    Allow.Free;
    Dump.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ReadClientVars(Names : TStrings; Every : Boolean; var ClientNr : Integer; out Err : String) : TJSONObject;
var
  All     : TStringList;
  Interp  : TEuoInterpreter;
  VarsObj : TJSONObject;
  i       : Integer;
begin
  Result:=nil;
  Err:='';
  All:=TStringList.Create;
  Interp:=TEuoInterpreter.Create(0);
  try
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
        Err:='there is no client number '+IntToStr(ClientNr)+' ("EUOCli clients" lists '+
          IntToStr(Interp.UOSel.Cnt)+')';
        Exit;
      end;

    Result:=TJSONObject.Create;
    Result.Add('client',ClientNr);
    VarsObj:=TJSONObject.Create;
    for i:=0 to Names.Count-1 do
      if VarsObj.IndexOfName(Names[i])<0 then VarsObj.Add(Names[i],Interp.GetVar(Names[i]));
    Result.Add('vars',VarsObj);
  finally
    Interp.Free;
    All.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunVars(Args : TStrings; Output : TStrings) : Integer;
var
  Names    : TStringList;
  ClientNr : Integer;
  Json     : Boolean;
  Every    : Boolean;
  i        : Integer;
  A, Err   : String;
  Obj      : TJSONObject;
begin
  Result:=CLI_OK;
  Names:=TStringList.Create;
  Obj:=nil;
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

    Obj:=ReadClientVars(Names,Every,ClientNr,Err);
    if Obj=nil then
    begin
      Output.Add('EUOCli vars: '+Err);
      Exit(CLI_NO_CLIENT);
    end;

    if Json then Output.Text:=Obj.FormatJSON
    else begin
      if ClientNr=0 then Output.Add('no client: variables of the client read N/A');
      for i:=0 to Names.Count-1 do
        Output.Add(Names[i]+' = '+Obj.Objects['vars'].Get(Names[i],''));
    end;
  finally
    Obj.Free;
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ListClients : TJSONObject;
var
  Interp : TEuoInterpreter;
  i, N   : Integer;
  Item   : TJSONObject;
  Arr    : TJSONArray;
  Name   : String;
  Logged : Boolean;
begin
  Interp:=TEuoInterpreter.Create(0);
  Result:=TJSONObject.Create;
  try
    N:=Interp.UOSel.Cnt;
    Arr:=TJSONArray.Create;
    Result.Add('clients',Arr);
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
    end;
    Result.Add('denied',Int64(Interp.UOSel.DeniedCnt));
  finally
    Interp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunClients(Args : TStrings; Output : TStrings) : Integer;
var
  Json   : Boolean;
  i      : Integer;
  Obj    : TJSONObject;
  Item   : TJSONObject;
  Arr    : TJSONArray;
  Line   : String;
  Denied : Integer;
begin
  Result:=CLI_OK;
  Json:=False;
  for i:=0 to Args.Count-1 do
    if Args[i]='--json' then Json:=True
    else Exit(Fail(Output,'clients','unknown option '+Args[i]));

  Obj:=ListClients;
  try
    if Json then
    begin
      Output.Text:=Obj.FormatJSON;
      Exit;
    end;
    Arr:=Obj.Arrays['clients'];
    for i:=0 to Arr.Count-1 do
    begin
      Item:=Arr.Objects[i];
      Line:=IntToStr(Item.Get('nr',0))+'  '+Item.Get('version','')+'  "'+Item.Get('title','')+'"  ';
      if Item.Get('loggedIn',False) then Line:=Line+'character '+Item.Get('character','')
      else Line:=Line+'nobody logged in';
      Output.Add(Line);
    end;
    if Arr.Count=0 then Output.Add('no UO client found');
    Denied:=Obj.Get('denied',0);
    if Denied>0 then
      Output.Add(IntToStr(Denied)+' client(s) run as administrator and cannot be opened: '+
        'start this program as administrator too, or the client without');
  finally
    Obj.Free;
  end;
end;

end.
