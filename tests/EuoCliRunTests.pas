unit EuoCliRunTests;

{
  Tests for EUOCli's "run", "vars" and "clients" (tools\EUOCli\clirun.pas), called as the
  program calls them. "run" starts a real TExecutor, so like EuoExecutorTests these run a
  background thread and depend a little on timing; the scripts are short and the waits
  generous. No client is used: "run" selects none unless told to, and that is one of the
  things tested.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, climain, clicheck, clirun;

type
  TEuoCliRunTests = class(TTestCase)
  private
    Dir    : String;
    Output : TStringList;
    function  Run(const Args : String; const StdIn : String = '') : Integer;
    function  Script(const Name : String; const Lines : array of String) : String;
    // The JSON events of the last run, parsed; the caller frees the list (it owns them).
    function  Events : TList;
    function  EventOf(List : TList; const Kind : String; Nth : Integer = 0) : TJSONObject;
    procedure FreeEvents(List : TList);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRunPrintsLogDisplayAndTheEnd;
    procedure TestRunHasNoClientUnlessAsked;
    procedure TestJsonEvents;
    procedure TestDisplayIsAnsweredWithItsFirstButton;
    procedure TestAnswerOption;
    procedure TestAScriptWithoutHaltIsStoppedAtItsRestart;
    procedure TestHaltOnTheLastLineIsNoRestart;
    procedure TestBlockedCommandStopsTheRun;
    procedure TestAllowOption;
    procedure TestTimeout;
    procedure TestNothingRunsAfterATimeout;
    procedure TestTrace;
    procedure TestDump;
    procedure TestPauseEndsTheRun;
    procedure TestMenuScriptRuns;
    procedure TestStdIn;
    procedure TestClientThatIsNotThere;
    procedure TestRunUsageErrors;
    procedure TestVars;
    procedure TestClients;
    procedure TestHelpOfEachCommand;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euoclirun-'+IntToStr(GetProcessID);
  ForceDirectories(Dir);
  Output:=TStringList.Create;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TearDown;
var
  SR : TSearchRec;
begin
  Output.Free;
  if FindFirst(Dir+PathDelim+'*',faAnyFile,SR)=0 then
  begin
    repeat
      if (SR.Attr and faDirectory)=0 then DeleteFile(Dir+PathDelim+SR.Name);
    until FindNext(SR)<>0;
    FindClose(SR);
  end;
  RemoveDir(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliRunTests.Run(const Args : String; const StdIn : String) : Integer;
var
  SL : TStringList;
begin
  SL:=TStringList.Create;
  try
    SL.Delimiter:='|';
    SL.StrictDelimiter:=True;
    SL.DelimitedText:=Args;
    Output.Clear;
    Result:=RunCli(SL,StdIn,Dir,Output);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliRunTests.Script(const Name : String; const Lines : array of String) : String;
var
  SL  : TStringList;
  Cnt : Integer;
begin
  Result:=Dir+PathDelim+Name;
  SL:=TStringList.Create;
  try
    for Cnt:=Low(Lines) to High(Lines) do SL.Add(Lines[Cnt]);
    SL.SaveToFile(Result);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliRunTests.Events : TList;
var
  i : Integer;
begin
  Result:=TList.Create;
  for i:=0 to Output.Count-1 do
    if Trim(Output[i])<>'' then Result.Add(GetJSON(Output[i]));
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliRunTests.EventOf(List : TList; const Kind : String; Nth : Integer) : TJSONObject;
var
  i : Integer;
begin
  Result:=nil;
  for i:=0 to List.Count-1 do
    if TJSONObject(List[i]).Get('event','')=Kind then
    begin
      if Nth=0 then Exit(TJSONObject(List[i]));
      Dec(Nth);
    end;
  Fail('no "'+Kind+'" event in:'+LineEnding+Output.Text);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.FreeEvents(List : TList);
var
  i : Integer;
begin
  for i:=0 to List.Count-1 do TObject(List[i]).Free;
  List.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestRunPrintsLogDisplayAndTheEnd;
var
  FN : String;
begin
  FN:=Script('a.euo',['set %sum 2 + 3','log The sum is %sum','display ok Done$with two lines','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN));
  AssertEquals('running '+FN+' without a client (commands that need one are skipped)',Output[0]);
  AssertEquals('[2] log: The sum is 5',Output[1]);
  AssertEquals('[3] display (ok, answered Ok): Done / with two lines',Output[2]);
  AssertTrue('the last line says how it ended: '+Output[3],Pos('ended: halt at line 4 after ',Output[3])=1);
  AssertEquals(4,Output.Count);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestRunHasNoClientUnlessAsked;
var
  FN : String;
  Ev : TList;
begin
  // Whatever is running on this machine, "run" selects no client by itself: the client
  // commands are skipped and client variables read N/A.
  FN:=Script('c.euo',['finditem POF G_3','event macro 17 0','log Found #FindCnt at #CharPosX','halt']);
  AssertEquals(CLI_OK,Run('run|--json|'+FN));
  Ev:=Events;
  try
    AssertEquals(0,EventOf(Ev,'start').Get('client',-1));
    AssertEquals('Found N/A at N/A',EventOf(Ev,'log').Get('text',''));
    AssertEquals(0,EventOf(Ev,'end').Get('client',-1));
    AssertEquals(2,EventOf(Ev,'end').Get('clientLinesSkipped',-1));
  finally
    FreeEvents(Ev);
  end;
  AssertEquals('--no-client says the same out loud',CLI_OK,Run('run|--no-client|'+FN));
  AssertEquals('2 lines were skipped because their command needs a client',Output[Output.Count-1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestJsonEvents;
var
  FN  : String;
  Ev  : TList;
  E   : TJSONObject;
begin
  FN:=Script('j.euo',['log one','display yesno Sure?','log two','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--json'));
  Ev:=Events;
  try
    AssertEquals('start, log, display, log, end: one object per line',5,Ev.Count);
    E:=EventOf(Ev,'start');
    AssertEquals(FN,E.Get('file',''));
    AssertEquals(60,E.Get('timeout',-1));
    AssertEquals('execute',E.Arrays['blocked'].Strings[0]);
    AssertEquals(5,E.Arrays['blocked'].Count);

    E:=EventOf(Ev,'log');
    AssertEquals(1,E.Get('line',-1));
    AssertEquals('one',E.Get('text',''));

    E:=EventOf(Ev,'display');
    AssertEquals(2,E.Get('line',-1));
    AssertEquals('yesno',E.Get('buttons',''));
    AssertEquals('Sure?',E.Get('text',''));
    AssertEquals('Yes',E.Get('answer',''));

    AssertEquals('in the order it happened','two',EventOf(Ev,'log',1).Get('text',''));
    AssertEquals('the end comes last','end',TJSONObject(Ev[4]).Get('event',''));

    E:=EventOf(Ev,'end');
    AssertEquals('halt',E.Get('reason',''));
    AssertEquals(4,E.Get('line',-1));
    AssertEquals(CLI_OK,E.Get('exitCode',-1));
    AssertTrue(E.Get('elapsedMs',-1)>=0);
  finally
    FreeEvents(Ev);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestDisplayIsAnsweredWithItsFirstButton;
var
  FN : String;
begin
  FN:=Script('d.euo',['display ok a','set %r1 #DispRes','display okcancel b','set %r2 #DispRes',
    'display yesno c','set %r3 #DispRes','display yesnocancel d','set %r4 #DispRes',
    'log %r1 %r2 %r3 %r4','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN));
  AssertEquals('[9] log: Ok Ok Yes Yes',Output[Output.Count-2]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestAnswerOption;
var
  FN : String;
begin
  FN:=Script('d.euo',['display ok a','set %r1 #DispRes','display okcancel b','set %r2 #DispRes',
    'display yesno c','set %r3 #DispRes','display yesnocancel d','set %r4 #DispRes',
    'log %r1 %r2 %r3 %r4','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--answer|no'));
  AssertEquals('only the boxes that have a No button','[9] log: Ok Ok No No',Output[Output.Count-2]);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--answer|cancel'));
  AssertEquals('[9] log: Ok Cancel Yes Cancel',Output[Output.Count-2]);
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|--answer|maybe'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestAScriptWithoutHaltIsStoppedAtItsRestart;
var
  FN : String;
begin
  FN:=Script('r.euo',['set %n %n + 1','log round %n']);
  AssertEquals(CLI_RESTARTED,Run('run|'+FN+'|--dump|%n'));
  AssertEquals('it ran once, not twice','[2] log: round 1',Output[1]);
  AssertTrue(Output[2],Pos('ended: restart at line 2 ',Output[2])=1);
  AssertTrue('and it says why',Pos('it has no halt',Output[2])>0);
  AssertEquals('%n = 1',Output[3]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestHaltOnTheLastLineIsNoRestart;
var
  FN : String;
begin
  // With no line after the HALT the interpreter passes through its end-of-script code too.
  FN:=Dir+PathDelim+'h.euo';
  with TStringList.Create do
  try
    Text:='log once'+LineEnding+'halt';
    SaveToFile(FN);
  finally
    Free;
  end;
  AssertEquals(CLI_OK,Run('run|'+FN));
  AssertTrue(Output[Output.Count-1],Pos('ended: halt at line 2 ',Output[Output.Count-1])=1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestBlockedCommandStopsTheRun;
var
  FN   : String;
  Cmds : array[0..4] of String = ('execute notepad.exe','shutdown','terminate uo','uoxl new','send httppost example.invalid /x y');
  i    : Integer;
begin
  for i:=Low(Cmds) to High(Cmds) do
  begin
    FN:=Script('b.euo',['log before',Cmds[i],'log after','halt']);
    AssertEquals(Cmds[i],CLI_BLOCKED,Run('run|'+FN));
    AssertEquals('[1] log: before',Output[1]);
    AssertTrue(Cmds[i]+': '+Output[2],Pos('ended: blocked at line 2 ',Output[2])=1);
    AssertTrue('it names the option that would allow it',Pos('--allow ',Output[2])>0);
    AssertEquals('nothing after the blocked line ran',3,Output.Count);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestAllowOption;
var
  FN : String;
begin
  // TERMINATE with a word it does not know does nothing: safe to let through.
  FN:=Script('t.euo',['terminate nothing','log after','halt']);
  AssertEquals(CLI_BLOCKED,Run('run|'+FN));
  AssertEquals(CLI_OK,Run('run|'+FN+'|--allow|terminate'));
  AssertEquals('[2] log: after',Output[1]);
  AssertEquals('several, in any case',CLI_OK,Run('run|'+FN+'|--allow|Execute,TERMINATE'));
  AssertEquals('only blocked commands can be allowed',CLI_USAGE,Run('run|'+FN+'|--allow|finditem'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestTimeout;
var
  FN    : String;
  Start : QWord;
begin
  FN:=Script('l.euo',['log started','loop:','wait 2','goto loop']);
  Start:=GetTickCount64;
  AssertEquals(CLI_TIMEOUT,Run('run|'+FN+'|--timeout|1'));
  AssertTrue('it ran for about a second',(GetTickCount64-Start>=900) and (GetTickCount64-Start<6000));
  AssertEquals('[1] log: started',Output[1]);
  AssertTrue(Output[2],Pos('ended: timeout at line ',Output[2])=1);
  AssertEquals('1s is one second too',CLI_TIMEOUT,Run('run|'+FN+'|--timeout|1s'));
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|--timeout|soon'));
end;

////////////////////////////////////////////////////////////////////////////////
// A timeout that falls into a wait must not let the line after the wait run. TExecutor's
// Stop used to break the wait a moment before the script counted as stopped, and about one
// time in four the next line then ran (EuoExecutor.pas's header; EuoExecutorTests has the
// test of the executor itself). Several rounds, because one round would pass by luck most
// of the time.
procedure TEuoCliRunTests.TestNothingRunsAfterATimeout;
var
  FN : String;
  i  : Integer;
begin
  FN:=Script('w.euo',['log before','wait 60s','log after the wait','halt']);
  for i:=1 to 8 do
  begin
    AssertEquals(CLI_TIMEOUT,Run('run|'+FN+'|--timeout|1'));
    AssertEquals('round '+IntToStr(i)+': '+Output.Text,3,Output.Count);
    AssertEquals('[1] log: before',Output[1]);
    AssertTrue(Output[2],Pos('ended: timeout at line 2 ',Output[2])=1);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestTrace;
var
  FN : String;
begin
  FN:=Script('t.euo',['set %a 1','if %a = 1','  log yes','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--trace'));
  AssertEquals('[1] > set %a 1',Output[1]);
  AssertEquals('[2] > if %a = 1',Output[2]);
  AssertEquals('[3] > log yes',Output[3]);
  AssertEquals('what a line logs comes after the line','[3] log: yes',Output[4]);
  AssertEquals('[4] > halt',Output[5]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestDump;
var
  FN : String;
  Ev : TList;
begin
  FN:=Script('v.euo',['set %a 5','set !b six','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--dump|%a,!b, %never'));
  AssertEquals('%a = 5',Output[Output.Count-3]);
  AssertEquals('!b = six',Output[Output.Count-2]);
  AssertEquals('%never = N/A',Output[Output.Count-1]);

  AssertEquals(CLI_OK,Run('run|'+FN+'|--json|--dump|%a'));
  Ev:=Events;
  try
    AssertEquals('5',EventOf(Ev,'end').Objects['vars'].Get('%a',''));
  finally
    FreeEvents(Ev);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestPauseEndsTheRun;
var
  FN : String;
begin
  FN:=Script('p.euo',['log before','pause','log after','halt']);
  AssertEquals('nobody is there to press Play',CLI_OK,Run('run|'+FN));
  AssertEquals('[1] log: before',Output[1]);
  AssertTrue(Output[2],Pos('ended: pause at line 2 ',Output[2])=1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestMenuScriptRuns;
var
  FN : String;
begin
  // MENU builds real windows on the main thread, which "run" has to keep serving while
  // the script's thread waits for it.
  FN:=Script('m.euo',['menu clear','menu window size 120 40','menu button ok 10 10 60 25 OK',
    'menu show','menu get ok','menu hide','log menu done','halt']);
  AssertEquals(CLI_OK,Run('run|'+FN+'|--timeout|20'));
  AssertEquals('[7] log: menu done',Output[1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestStdIn;
begin
  AssertEquals(CLI_OK,Run('run|-','log from stdin'+LineEnding+'halt'+LineEnding));
  AssertEquals('running <stdin> without a client (commands that need one are skipped)',Output[0]);
  AssertEquals('[1] log: from stdin',Output[1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestClientThatIsNotThere;
var
  FN : String;
begin
  FN:=Script('a.euo',['log should not run','halt']);
  AssertEquals(CLI_NO_CLIENT,Run('run|'+FN+'|--client|99'));
  AssertEquals('the script did not start',1,Output.Count);
  AssertEquals(CLI_NO_CLIENT,Run('vars|--client|99|#CharName'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestRunUsageErrors;
var
  FN : String;
begin
  FN:=Script('a.euo',['halt']);
  AssertEquals(CLI_USAGE,Run('run'));
  AssertTrue(Pos('no script given',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('run|'+Dir+PathDelim+'nothere.euo'));
  AssertTrue(Pos('file not found',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|'+FN));
  AssertTrue(Pos('one script at a time',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|--frob'));
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|--client'));
  AssertEquals(CLI_USAGE,Run('run|'+FN+'|--client|one'));
  AssertEquals(CLI_USAGE,Run('run|-',''));
  AssertTrue(Pos('the script is empty',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestVars;
var
  Data : TJSONData;
begin
  AssertEquals(CLI_OK,Run('vars|--client|0|#True|False|SPC'));
  AssertEquals('no client: variables of the client read N/A',Output[0]);
  AssertEquals('#True = -1',Output[1]);
  AssertEquals('a bare name is a #variable','#False = 0',Output[2]);
  AssertEquals('#SPC =  ',Output[3]);

  AssertEquals(CLI_OK,Run('vars|--no-client|--json|#CharPosX|#True'));
  Data:=GetJSON(Output.Text);
  try
    AssertEquals(0,TJSONObject(Data).Get('client',-1));
    AssertEquals('N/A',TJSONObject(Data).Objects['vars'].Get('#CharPosX',''));
    AssertEquals('-1',TJSONObject(Data).Objects['vars'].Get('#True',''));
  finally
    Data.Free;
  end;

  AssertEquals(CLI_OK,Run('vars|--no-client|--all'));
  AssertTrue('every #variable: '+IntToStr(Output.Count),Output.Count>150);

  AssertEquals(CLI_USAGE,Run('vars'));
  AssertEquals(CLI_USAGE,Run('vars|%mine'));
  AssertTrue(Pos('script''s own variable',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('vars|--frob|#True'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestClients;
var
  Data : TJSONData;
begin
  // Whatever runs on this machine: the command answers and its JSON has its two members.
  AssertEquals(CLI_OK,Run('clients'));
  AssertTrue(Output.Count>0);
  AssertEquals(CLI_OK,Run('clients|--json'));
  Data:=GetJSON(Output.Text);
  try
    AssertTrue(TJSONObject(Data).Arrays['clients'].Count>=0);
    AssertTrue(TJSONObject(Data).Get('denied',-1)>=0);
  finally
    Data.Free;
  end;
  AssertEquals(CLI_USAGE,Run('clients|--frob'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliRunTests.TestHelpOfEachCommand;
begin
  AssertEquals(CLI_OK,Run('help'));
  AssertTrue(Pos('EUOCli run ',Output.Text)>0);
  AssertTrue(Pos('EUOCli vars ',Output.Text)>0);
  AssertTrue(Pos('EUOCli clients',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|run'));
  AssertTrue(Pos('--timeout',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|vars'));
  AssertTrue(Pos('--all',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|clients'));
  AssertTrue(Pos('--client takes',Output.Text)>0);
end;

initialization
  RegisterTest(TEuoCliRunTests);

end.
