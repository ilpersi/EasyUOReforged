unit EuoHostHooksTests;

{
  Tests for what the interpreter offers a host that runs scripts with nobody watching
  (docs\agent-support.md, phase 3): the LOG command and its queue, OnDisplay, BlockCommands,
  Restarts and ClientSkips. Each must do nothing at all until a host asks: the editor never
  sets OnDisplay or blocks a command, and its scripts run as they always did.

  Scripts are played line by line on the test's own thread, like EuoSqlTests.PlayScript, with
  no client selected.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter;

type
  TEuoHostHooksTests = class(TTestCase)
  private
    Interp   : TEuoInterpreter;
    Shown    : TStringList;
    Answer   : String;
    procedure Play(const Script : array of String; MaxSteps : Integer = 500);
    function  OnDisplay(const Text, Buttons : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestLogQueuesItsWordsWithTheLineNumber;
    procedure TestLogTextIsNotTranslated;
    procedure TestLogNeedsNoClientAndNeverWaits;
    procedure TestTakeLogEmptiesTheQueue;
    procedure TestLogQueueKeepsTheNewestLines;
    procedure TestASubCalledLogStillWorks;
    procedure TestOnDisplayAnswersWithoutABox;
    procedure TestOnDisplayGetsTheButtonsAndLineBreaks;
    procedure TestBlockedCommandStopsTheRun;
    procedure TestBlockingIsUndone;
    procedure TestNothingIsBlockedByDefault;
    procedure TestRestartsCountsEndOfScriptAndExit;
    procedure TestExitInACalledScriptIsNoRestart;
    procedure TestClearResetsTheHostState;
    procedure TestClientSkipsCountsSkippedLines;
  end;

implementation

const
  CRLF = #13#10;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.SetUp;
begin
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
  Shown:=TStringList.Create;
  Answer:='Ok';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TearDown;
begin
  Interp.OnDisplay:=nil;
  Interp.Free;
  Shown.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.Play(const Script : array of String; MaxSteps : Integer);
var
  Cnt : Integer;
  S   : String;
begin
  S:='';
  for Cnt:=Low(Script) to High(Script) do S:=S+Script[Cnt]+CRLF;
  Interp.ScrList.Scr.Text:=S;
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoHostHooksTests.OnDisplay(const Text, Buttons : String) : String;
begin
  Shown.Add(Buttons+'|'+Text);
  Result:=Answer;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestLogQueuesItsWordsWithTheLineNumber;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    Play(['set %a 5','log The value is %a','','log second','halt']);
    AssertTrue('there are lines to take',Interp.TakeLog(L));
    AssertEquals(2,L.Count);
    AssertEquals('variables are replaced, words joined by one space','The value is 5',L[0]);
    AssertEquals('the 1-based line of the script',2,Integer(PtrUInt(L.Objects[0])));
    AssertEquals('second',L[1]);
    AssertEquals(4,Integer(PtrUInt(L.Objects[1])));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestLogTextIsNotTranslated;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    // DISPLAY turns $ into a line break; LOG leaves the text as the script has it, so a
    // #Property or a journal line can be logged as it reads.
    Play(['log Runebook$Blessed$','log   spaced    out  ','log','log a , b','halt']);
    Interp.TakeLog(L);
    AssertEquals(4,L.Count);
    AssertEquals('Runebook$Blessed$',L[0]);
    AssertEquals('spaced out',L[1]);
    AssertEquals('log alone is an empty line','',L[2]);
    AssertEquals('the , operator still glues','ab',L[3]);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestLogNeedsNoClientAndNeverWaits;
var
  L     : TStringList;
  Start : QWord;
begin
  L:=TStringList.Create;
  try
    AssertEquals('no client is selected in this test',0,Integer(Interp.UOSel.Nr));
    Start:=GetTickCount64;
    Play(['for %i 1 200','  log line %i','halt'],2000);
    AssertTrue('200 log lines take no time worth measuring',GetTickCount64-Start<1000);
    Interp.TakeLog(L);
    AssertEquals(200,L.Count);
    AssertEquals('line 200',L[199]);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestTakeLogEmptiesTheQueue;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    AssertFalse('nothing logged yet',Interp.TakeLog(L));
    Play(['log one','halt']);
    AssertTrue(Interp.TakeLog(L));
    AssertFalse('taken once',Interp.TakeLog(L));
    AssertEquals('TakeLog adds to the list it is given',1,L.Count);
    Play(['log two','halt']);
    Interp.TakeLog(L);
    AssertEquals(2,L.Count);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestLogQueueKeepsTheNewestLines;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    Play(['set %n '+IntToStr(LOG_QUEUE_MAX+25),'for %i 1 %n','  log line %i','halt'],3*LOG_QUEUE_MAX);
    Interp.TakeLog(L);
    AssertEquals('the newest lines, and one line saying what was dropped',LOG_QUEUE_MAX+1,L.Count);
    AssertEquals('(25 earlier log lines were dropped: nothing was reading them)',L[0]);
    AssertEquals('line 26',L[1]);
    AssertEquals('line '+IntToStr(LOG_QUEUE_MAX+25),L[L.Count-1]);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestASubCalledLogStillWorks;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    // "log" is only a command as the first word of a line. A script that already had a sub
    // or a label of that name runs as before.
    Play(['gosub log 7','goto log','set %skipped 1','log:','halt','sub log','  set %got %1','return']);
    AssertEquals('7',Interp.GetVar('%got'));
    AssertEquals('the goto jumped over the set','N/A',Interp.GetVar('%skipped'));
    AssertFalse('none of those lines logged anything',Interp.TakeLog(L));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestOnDisplayAnswersWithoutABox;
begin
  Interp.OnDisplay:=OnDisplay;
  Answer:='No';
  Play(['display yesno Stop now?','set %r #DispRes','halt']);
  AssertEquals('the handler was asked once',1,Shown.Count);
  AssertEquals('YESNO|Stop now?',Shown[0]);
  AssertEquals('its answer is #DispRes','No',Interp.GetVar('%r'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestOnDisplayGetsTheButtonsAndLineBreaks;
begin
  Interp.OnDisplay:=OnDisplay;
  Play(['display plain text','display ok two$lines','display okcancel a','display yesnocancel b','halt']);
  AssertEquals(4,Shown.Count);
  AssertEquals('no button word means OK','OK|plain text',Shown[0]);
  AssertEquals('$ is a line break, as in the box','OK|two'+CRLF+'lines',Shown[1]);
  AssertEquals('OKCANCEL|a',Shown[2]);
  AssertEquals('YESNOCANCEL|b',Shown[3]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestBlockedCommandStopsTheRun;
var
  Names : TStringList;
begin
  Names:=TStringList.Create;
  try
    Names.Add('execute');
    Names.Add('Terminate');
    Interp.BlockCommands(Names);
    Play(['set %a 1','terminate euo','set %a 2','halt']);
    AssertEquals('the run stopped at the blocked line, like a halt',RES_STOP,Interp.ResInt);
    AssertEquals('TERMINATE',Interp.BlockedCmd);
    AssertEquals('its 0-based line',1,Interp.BlockedLine);
    AssertEquals('nothing after it ran','1',Interp.GetVar('%a'));
  finally
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestBlockingIsUndone;
var
  Names : TStringList;
begin
  Names:=TStringList.Create;
  try
    Names.Add('SET');
    Interp.BlockCommands(Names);
    Play(['set %a 1','halt']);
    AssertEquals('SET',Interp.BlockedCmd);
    AssertEquals('N/A',Interp.GetVar('%a'));

    Interp.Clear;
    Interp.BlockCommands(nil);
    Play(['set %a 1','halt']);
    AssertEquals('',Interp.BlockedCmd);
    AssertEquals('1',Interp.GetVar('%a'));
  finally
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestNothingIsBlockedByDefault;
begin
  // TERMINATE with a word it does not know does nothing, so it is safe to run here; that
  // it runs at all is the point.
  Play(['set %a 1','terminate nothing','set %a 2','halt']);
  AssertEquals('',Interp.BlockedCmd);
  AssertEquals(-1,Interp.BlockedLine);
  AssertEquals('2',Interp.GetVar('%a'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestRestartsCountsEndOfScriptAndExit;
begin
  AssertEquals(0,Integer(Interp.Restarts));
  // No HALT: the script runs off its end and starts over, as it always did. Seven steps
  // are three and a half rounds of two lines.
  Play(['set %n %n + 1','set %x 1'],7);
  AssertEquals('three times through the end',3,Integer(Interp.Restarts));
  AssertEquals('and the script did restart: the first line ran four times','4',Interp.GetVar('%n'));

  Interp.Clear;
  Play(['set %n %n + 1','if %n < 3','  exit','halt','set %never 1']);
  AssertEquals('two EXITs at the outermost level',2,Integer(Interp.Restarts));
  AssertEquals('3',Interp.GetVar('%n'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestExitInACalledScriptIsNoRestart;
var
  Dir, FN : String;
  SL      : TStringList;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir);
  FN:=Dir+'euohooks-'+IntToStr(GetProcessID)+'.euo';
  SL:=TStringList.Create;
  try
    SL.Add('set %called yes');
    SL.Add('exit');
    SL.SaveToFile(FN);
    Play(['call '+FN,'set %back yes','halt','set %never 1']);
    AssertEquals('yes',Interp.GetVar('%called'));
    AssertEquals('yes',Interp.GetVar('%back'));
    AssertEquals('an EXIT that returns to the caller restarts nothing',0,Integer(Interp.Restarts));
  finally
    SL.Free;
    DeleteFile(FN);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestClearResetsTheHostState;
var
  Names : TStringList;
  L     : TStringList;
begin
  Names:=TStringList.Create;
  L:=TStringList.Create;
  try
    Names.Add('STR');
    Interp.BlockCommands(Names);
    Play(['log kept','set %n 1','str len abc']);
    AssertEquals('STR',Interp.BlockedCmd);
    Interp.Clear;
    AssertEquals('',Interp.BlockedCmd);
    AssertEquals(-1,Interp.BlockedLine);
    AssertEquals(0,Integer(Interp.Restarts));
    AssertTrue('what was logged is still there for the host to take',Interp.TakeLog(L));
    AssertEquals('kept',L[0]);
  finally
    L.Free;
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHostHooksTests.TestClientSkipsCountsSkippedLines;
begin
  AssertEquals(0,Integer(Interp.ClientSkips));
  Play(['set %a 1','finditem POF','event macro 17 0','nosuchcommand','wait 0','msg hello$','halt']);
  AssertEquals('finditem, event and msg need a client; the others do not',3,Integer(Interp.ClientSkips));
end;

initialization
  RegisterTest(TEuoHostHooksTests);

end.
