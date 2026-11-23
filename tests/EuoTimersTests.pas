unit EuoTimersTests;

{
  PSL item 9: timers and time/decimal formatting.
  - TEuoTimersTests: the timer table (EuoTimers.pas) on a clock the test sets.
  - TEuoTimerScriptTests: the TIMER command and #TimerRes through the interpreter, with the run's clock
    set by the test, and what must not change (a sub or label called timer, #SCnt, EXIT, Clear).
  - TEuoStrFormatTests: STR DECIMAL, DATE, CLOCK, DATETIME and DURATION (EuoStrOps.pas), on their own and
    from a script, including the format with plain text and the Windows settings changed underneath.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoTimers, EuoStrOps, EuoInterpreter;

type
  TEuoTimersTests = class(TTestCase)
  private
    T : TEuoTimers;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNeverStartedCountsAsDue;
    procedure TestStartWithADuration;
    procedure TestStartWithoutADurationIsDueAtOnce;
    procedure TestRestartStartsOver;
    procedure TestStopForgets;
    procedure TestNamesIgnoreCase;
    procedure TestClearForgetsAll;
    procedure TestClockGoingBackIsNotNegative;
  end;

  TEuoTimerScriptTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    procedure PlayScript(const Script : String; MaxSteps : Integer = 1000);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestTimerRes;
    procedure TestDurationInTicksAndSeconds;
    procedure TestMissingNameOrUnknownWordIsNA;
    procedure TestNameFromVariablesAndGlue;
    procedure TestTimersSurviveExitRestart;
    procedure TestClearForgetsTimers;
    procedure TestSettingSCntChangesNothing;
    procedure TestEveryThirtySecondsLoop;
    procedure TestSubAndLabelCalledTimerStillWork;
  end;

  TEuoStrFormatTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    procedure PlayScript(const Script : String; MaxSteps : Integer = 1000);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDecimal;
    procedure TestDuration;
    procedure TestDurationFormats;
    procedure TestDate;
    procedure TestDateFormats;
    procedure TestClock;
    procedure TestClockFormats;
    procedure TestDateTime;
    procedure TestQuotesForWordsMadeOfTokens;
    procedure TestLettersThatAreNeverTokens;
    procedure TestWindowsSettingsChangeNothing;
    procedure TestPrepareFormat;
    procedure TestScriptOperations;
    procedure TestScriptMissingParameters;
    procedure TestScriptTimeWithoutLeadingZero;
    procedure TestReplacesHandWrittenElapsedTime;
  end;

implementation

var
  FakeNow : QWord;

function FakeClock : QWord;
begin
  Result:=FakeNow;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoTimersTests ////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoTimersTests.SetUp;
begin
  FakeNow:=1000000;
  T:=TEuoTimers.Create;
  T.Clock:=FakeClock;
end;

procedure TEuoTimersTests.TearDown;
begin
  T.Free;
end;

procedure TEuoTimersTests.TestNeverStartedCountsAsDue;
var
  Ms : QWord;
begin
  AssertFalse(T.Elapsed('cast',Ms));
  AssertEquals(0,Int64(T.Left('cast')));
  AssertTrue(T.Due('cast'));
  AssertFalse(T.Stop('cast'));
end;

procedure TEuoTimersTests.TestStartWithADuration;
var
  Ms : QWord;
begin
  T.Start('cast',5000);
  AssertTrue(T.Elapsed('cast',Ms));
  AssertEquals(0,Int64(Ms));
  AssertEquals(5000,Int64(T.Left('cast')));
  AssertFalse(T.Due('cast'));
  Inc(FakeNow,4999);
  AssertEquals(1,Int64(T.Left('cast')));
  AssertFalse(T.Due('cast'));
  Inc(FakeNow,1);
  AssertEquals(0,Int64(T.Left('cast')));
  AssertTrue(T.Due('cast'));
  Inc(FakeNow,2500);
  AssertEquals(0,Int64(T.Left('cast')));
  AssertTrue(T.Elapsed('cast',Ms));
  AssertEquals(7500,Int64(Ms));
end;

procedure TEuoTimersTests.TestStartWithoutADurationIsDueAtOnce;
var
  Ms : QWord;
begin
  T.Start('run',0);
  AssertTrue(T.Due('run'));
  Inc(FakeNow,1234);
  AssertTrue(T.Elapsed('run',Ms));
  AssertEquals(1234,Int64(Ms));
end;

procedure TEuoTimersTests.TestRestartStartsOver;
var
  Ms : QWord;
begin
  T.Start('save',30000);
  Inc(FakeNow,40000);
  AssertTrue(T.Due('save'));
  T.Start('save',30000);
  AssertFalse(T.Due('save'));
  AssertTrue(T.Elapsed('save',Ms));
  AssertEquals(0,Int64(Ms));
  AssertEquals(1,T.Count);
end;

procedure TEuoTimersTests.TestStopForgets;
var
  Ms : QWord;
begin
  T.Start('a',100);
  AssertTrue(T.Stop('a'));
  AssertFalse(T.Elapsed('a',Ms));
  AssertTrue(T.Due('a'));
  AssertFalse(T.Stop('a'));
end;

procedure TEuoTimersTests.TestNamesIgnoreCase;
var
  Ms : QWord;
begin
  T.Start('Cast',100);
  Inc(FakeNow,10);
  AssertTrue(T.Elapsed('CAST',Ms));
  AssertEquals(10,Int64(Ms));
  AssertEquals(90,Int64(T.Left('cast')));
  AssertEquals(1,T.Count);
end;

procedure TEuoTimersTests.TestClearForgetsAll;
begin
  T.Start('a',100);
  T.Start('b',100);
  AssertEquals(2,T.Count);
  T.Clear;
  AssertEquals(0,T.Count);
  AssertTrue(T.Due('a'));
end;

procedure TEuoTimersTests.TestClockGoingBackIsNotNegative;
var
  Ms : QWord;
begin
  T.Start('a',100);
  Dec(FakeNow,50);   // GetTickCount64 never does this; the table must not wrap if a clock did
  AssertTrue(T.Elapsed('a',Ms));
  AssertEquals(0,Int64(Ms));
  AssertEquals(150,Int64(T.Left('a')));
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoTimerScriptTests ///////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoTimerScriptTests.SetUp;
begin
  FakeNow:=5000000;
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
  Interp.Timers.Clock:=FakeClock;
end;

procedure TEuoTimerScriptTests.TearDown;
begin
  Interp.Free;
end;

procedure TEuoTimerScriptTests.PlayScript(const Script : String; MaxSteps : Integer);
var
  Cnt : Integer;
begin
  Interp.ScrList.Scr.Text:=Script;
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

procedure TEuoTimerScriptTests.TestTimerRes;
begin
  AssertEquals('N/A',Interp.GetVar('#TimerRes'));
  PlayScript(
    'timer due cast' + #13#10 + 'set %neverDue #TimerRes' + #13#10 +
    'timer left cast' + #13#10 + 'set %neverLeft #TimerRes' + #13#10 +
    'timer elapsed cast' + #13#10 + 'set %neverElapsed #TimerRes' + #13#10 +
    'timer start cast 5s' + #13#10 + 'set %start #TimerRes' + #13#10 +
    'timer due cast' + #13#10 + 'set %due #TimerRes' + #13#10 +
    'timer left cast' + #13#10 + 'set %left #TimerRes' + #13#10 +
    'timer elapsed cast' + #13#10 + 'set %elapsed #TimerRes' + #13#10 +
    'timer stop cast' + #13#10 + 'set %stop #TimerRes' + #13#10 +
    'timer stop cast' + #13#10 + 'set %stop2 #TimerRes' + #13#10 +
    'halt');
  AssertEquals('-1',Interp.GetVar('%neverDue'));
  AssertEquals('0',Interp.GetVar('%neverLeft'));
  AssertEquals('N/A',Interp.GetVar('%neverElapsed'));
  AssertEquals('-1',Interp.GetVar('%start'));
  AssertEquals('0',Interp.GetVar('%due'));
  AssertEquals('5000',Interp.GetVar('%left'));
  AssertEquals('0',Interp.GetVar('%elapsed'));
  AssertEquals('-1',Interp.GetVar('%stop'));
  AssertEquals('0',Interp.GetVar('%stop2'));

  // The clock moves between lines: read it again.
  PlayScript('timer start cast 5s' + #13#10 + 'halt');
  FakeNow:=FakeNow+2000;
  PlayScript(
    'timer left cast' + #13#10 + 'set %left #TimerRes' + #13#10 +
    'timer elapsed cast' + #13#10 + 'set %elapsed #TimerRes' + #13#10 +
    'timer due cast' + #13#10 + 'set %due #TimerRes' + #13#10 +
    'if #TimerRes' + #13#10 + '  set %went yes' + #13#10 +
    'halt');
  AssertEquals('3000',Interp.GetVar('%left'));
  AssertEquals('2000',Interp.GetVar('%elapsed'));
  AssertEquals('0',Interp.GetVar('%due'));
  AssertEquals('N/A',Interp.GetVar('%went'));
end;

procedure TEuoTimerScriptTests.TestDurationInTicksAndSeconds;
begin
  PlayScript(
    'timer start a 20' + #13#10 + 'timer left a' + #13#10 + 'set %ticks #TimerRes' + #13#10 +
    'timer start b 3s' + #13#10 + 'timer left b' + #13#10 + 'set %secs #TimerRes' + #13#10 +
    'timer start c' + #13#10 + 'timer left c' + #13#10 + 'set %none #TimerRes' + #13#10 +
    'timer start d %unset' + #13#10 + 'timer left d' + #13#10 + 'set %unset2 #TimerRes' + #13#10 +
    'set %n 7' + #13#10 +
    'timer start e %n , s' + #13#10 + 'timer left e' + #13#10 + 'set %var #TimerRes' + #13#10 +
    'halt');
  AssertEquals('1000',Interp.GetVar('%ticks'));
  AssertEquals('3000',Interp.GetVar('%secs'));
  AssertEquals('0',Interp.GetVar('%none'));
  AssertEquals('0',Interp.GetVar('%unset2'));
  AssertEquals('7000',Interp.GetVar('%var'));
end;

procedure TEuoTimerScriptTests.TestMissingNameOrUnknownWordIsNA;
begin
  PlayScript(
    'timer start a 5s' + #13#10 +
    'timer start' + #13#10 + 'set %noName #TimerRes' + #13#10 +
    'timer start a 5s' + #13#10 + 'timer' + #13#10 + 'set %alone #TimerRes' + #13#10 +
    'timer start a 5s' + #13#10 + 'timer reset a' + #13#10 + 'set %unknown #TimerRes' + #13#10 +
    'halt');
  AssertEquals('N/A',Interp.GetVar('%noName'));
  AssertEquals('N/A',Interp.GetVar('%alone'));
  AssertEquals('N/A',Interp.GetVar('%unknown'));
  AssertEquals(1,Interp.Timers.Count);
end;

procedure TEuoTimerScriptTests.TestNameFromVariablesAndGlue;
begin
  PlayScript(
    'set %i 3' + #13#10 +
    'timer start cast . %i 1s' + #13#10 +
    'timer left CAST3' + #13#10 + 'set %left #TimerRes' + #13#10 +
    'halt');
  AssertEquals('1000',Interp.GetVar('%left'));
end;

procedure TEuoTimerScriptTests.TestTimersSurviveExitRestart;
begin
  // The first pass starts the timer and reaches the end (an implicit EXIT, which restarts the script);
  // the second pass finds it.
  PlayScript(
    'if %pass = 2' + #13#10 +
    '{' + #13#10 +
    '  timer left keep' + #13#10 +
    '  set %left #TimerRes' + #13#10 +
    '  halt' + #13#10 +
    '}' + #13#10 +
    'set %pass 2' + #13#10 +
    'timer start keep 9s');
  AssertEquals('2',Interp.GetVar('%pass'));
  AssertEquals('9000',Interp.GetVar('%left'));
  AssertTrue(Interp.Restarts>=1);
end;

procedure TEuoTimerScriptTests.TestClearForgetsTimers;
begin
  PlayScript('timer start keep 9s' + #13#10 + 'timer left keep' + #13#10 + 'halt');
  AssertEquals('9000',Interp.GetVar('#TimerRes'));
  Interp.Clear;
  AssertEquals('N/A',Interp.GetVar('#TimerRes'));
  AssertEquals(0,Interp.Timers.Count);
  PlayScript('timer left keep' + #13#10 + 'halt');
  AssertEquals('0',Interp.GetVar('#TimerRes'));
end;

procedure TEuoTimerScriptTests.TestSettingSCntChangesNothing;
begin
  PlayScript(
    'timer start t 4s' + #13#10 +
    'set #SCnt 0' + #13#10 + 'set #SCnt2 0' + #13#10 +
    'timer left t' + #13#10 + 'set %left #TimerRes' + #13#10 +
    'halt');
  AssertEquals('4000',Interp.GetVar('%left'));
end;

procedure TEuoTimerScriptTests.TestEveryThirtySecondsLoop;
const
  Loop =
    'timer due save' + #13#10 +
    'if #TimerRes' + #13#10 +
    '{' + #13#10 +
    '  set %saves %saves + 1' + #13#10 +
    '  timer start save 30s' + #13#10 +
    '}' + #13#10 +
    'halt';
begin
  Interp.SetVar('%saves','0');
  PlayScript(Loop);                   // never started: due, so it runs at once
  AssertEquals('1',Interp.GetVar('%saves'));
  FakeNow:=FakeNow+29999;
  PlayScript(Loop);
  AssertEquals('1',Interp.GetVar('%saves'));
  FakeNow:=FakeNow+1;
  PlayScript(Loop);
  AssertEquals('2',Interp.GetVar('%saves'));
end;

procedure TEuoTimerScriptTests.TestSubAndLabelCalledTimerStillWork;
begin
  PlayScript(
    'gosub timer' + #13#10 +
    'goto timer' + #13#10 +
    'set %skipped yes' + #13#10 +
    'timer:' + #13#10 +
    'set %label yes' + #13#10 +
    'halt' + #13#10 +
    'sub timer' + #13#10 +
    '  set %sub yes' + #13#10 +
    'return');
  AssertEquals('yes',Interp.GetVar('%sub'));
  AssertEquals('yes',Interp.GetVar('%label'));
  AssertEquals('N/A',Interp.GetVar('%skipped'));
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoStrFormatTests /////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoStrFormatTests.SetUp;
begin
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
end;

procedure TEuoStrFormatTests.TearDown;
begin
  Interp.Free;
end;

procedure TEuoStrFormatTests.PlayScript(const Script : String; MaxSteps : Integer);
var
  Cnt : Integer;
begin
  Interp.ScrList.Scr.Text:=Script;
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

procedure TEuoStrFormatTests.TestDecimal;
begin
  AssertEquals('95.3',StrDecimal(953,1));
  AssertEquals('0.07',StrDecimal(7,2));
  AssertEquals('-0.5',StrDecimal(-5,1));
  AssertEquals('0.00',StrDecimal(0,2));
  AssertEquals('0.100',StrDecimal(100,3));
  AssertEquals('-1.00',StrDecimal(-100,2));
  AssertEquals('953',StrDecimal(953,0));
  AssertEquals('-953',StrDecimal(-953,0));
  AssertEquals('0.000000000000000001',StrDecimal(1,18));
  AssertEquals('-922337203685477580.8',StrDecimal(Low(Int64),1));
  AssertEquals('N/A',StrDecimal(953,19));
  AssertEquals('N/A',StrDecimal(953,-1));
end;

procedure TEuoStrFormatTests.TestDuration;
begin
  AssertEquals('1:02:05',StrDuration(3725,''));
  AssertEquals('25:00:00',StrDuration(90000,''));
  AssertEquals('0:00:00',StrDuration(0,''));
  AssertEquals('0:00:59',StrDuration(59,''));
  AssertEquals('23:59:59',StrDuration(86399,''));
  AssertEquals('-0:00:05',StrDuration(-5,''));
  AssertEquals('-1:02:05',StrDuration(-3725,''));
  AssertEquals('72:01:01',StrDuration(3*86400+61,''));
  AssertEquals('596523:14:07',StrDuration(High(Integer),''));
  AssertEquals('N/A',StrDuration(Int64(High(Integer))+1,''));
  AssertEquals('N/A',StrDuration(Low(Int64),''));
  AssertEquals('N/A',StrDuration(High(Int64),''));
end;

procedure TEuoStrFormatTests.TestDurationFormats;
begin
  AssertEquals('62 min',StrDuration(3725,'[n] min'));
  AssertEquals('62 min',StrDuration(3725,'[m] min'));
  AssertEquals('3725 sec',StrDuration(3725,'[s] sec'));
  AssertEquals('3725 5',StrDuration(3725,'[s] s'));      // s alone is a token: the seconds
  AssertEquals('1 hours 2 min',StrDuration(3725,'h hours n min'));
  AssertEquals('1h 02m 05s',StrDuration(3725,'h"h" nn"m" ss"s"'));
  AssertEquals('01:02:05',StrDuration(3725,'hh:mm:ss'));
  AssertEquals('62:05',StrDuration(3725,'[n]:ss'));
  AssertEquals('d 1',StrDuration(3725,'d h'));          // d is no token in a duration
  AssertEquals('-62 min',StrDuration(-3725,'[n] min'));
end;

procedure TEuoStrFormatTests.TestDate;
begin
  AssertEquals('2026-11-22',StrDate('261122',''));
  AssertEquals('2005-11-22',StrDate('51122',''));
  AssertEquals('2000-01-01',StrDate('101',''));
  AssertEquals('2028-02-29',StrDate('280229',''));
  AssertEquals('N/A',StrDate('260229',''));
  AssertEquals('N/A',StrDate('261322',''));
  AssertEquals('N/A',StrDate('261100',''));
  AssertEquals('N/A',StrDate('1234567',''));
  AssertEquals('N/A',StrDate('',''));
  AssertEquals('N/A',StrDate('26-11-22',''));
  AssertEquals('N/A',StrDate('-61122',''));
end;

procedure TEuoStrFormatTests.TestDateFormats;
begin
  AssertEquals('22/11/2026',StrDate('261122','dd/mm/yyyy'));
  AssertEquals('11/22/26',StrDate('261122','mm/dd/yy'));
  AssertEquals('22.11.2026',StrDate('261122','dd.mm.yyyy'));
  AssertEquals('20261122',StrDate('261122','yyyymmdd'));
  AssertEquals('Sunday 22 November 2026',StrDate('261122','dddd d mmmm yyyy'));
  AssertEquals('Sun, 22 Nov 26',StrDate('261122','ddd, d mmm yy'));
  AssertEquals('5/1/2026',StrDate('260105','d/m/yyyy'));
  AssertEquals('Today is Sunday',StrDate('261122','Today is dddd'));
  AssertEquals('Date: 2026-11-22',StrDate('261122','Date: yyyy-mm-dd'));
  AssertEquals('N/A',StrDate('261122','ddddd'));
  AssertEquals('N/A',StrDate('261122','dddddd'));
end;

procedure TEuoStrFormatTests.TestClock;
begin
  AssertEquals('14:30:05',StrClock('143005',''));
  AssertEquals('09:30:15',StrClock('93015',''));
  AssertEquals('09:30:15',StrClock('093015',''));
  AssertEquals('00:05:00',StrClock('500',''));
  AssertEquals('00:00:00',StrClock('0',''));
  AssertEquals('23:59:59',StrClock('235959',''));
  AssertEquals('N/A',StrClock('240000',''));
  AssertEquals('N/A',StrClock('146000',''));
  AssertEquals('N/A',StrClock('143060',''));
  AssertEquals('N/A',StrClock('14:30',''));
end;

procedure TEuoStrFormatTests.TestClockFormats;
begin
  AssertEquals('2:30 pm',StrClock('143005','h:nn am/pm'));
  AssertEquals('9:30 AM',StrClock('093015','h:mm AM/PM'));
  AssertEquals('02:30 PM',StrClock('143005','hh:nn ampm'));
  AssertEquals('12:00 a',StrClock('000000','h:nn a/p'));
  AssertEquals('2:30pm',StrClock('143005','h:nnam/pm'));
  AssertEquals('14h30',StrClock('143005','hh"h"nn'));
  AssertEquals('14:30',StrClock('143005','hh:mm'));
  AssertEquals('30 min',StrClock('143005','m min'));          // m alone is minutes in a clock
  AssertEquals('14:30:05.000',StrClock('143005','hh:nn:ss.zzz'));
  AssertEquals('d 14',StrClock('143005','d h'));                // d is no token in a clock
end;

procedure TEuoStrFormatTests.TestDateTime;
begin
  AssertEquals('2026-11-22 14:30:05',StrDateTime('261122','143005',''));
  AssertEquals('22/11 14:30',StrDateTime('261122','143005','dd/mm hh:nn'));
  AssertEquals('22/11 14:30',StrDateTime('261122','143005','dd/mm hh:mm'));
  AssertEquals('Sunday 2:30 pm',StrDateTime('261122','143005','dddd h:nn am/pm'));
  AssertEquals('2026-11-22 09:30:15',StrDateTime('261122','93015',''));
  AssertEquals('N/A',StrDateTime('261322','143005',''));
  AssertEquals('N/A',StrDateTime('261122','246000',''));
end;

procedure TEuoStrFormatTests.TestQuotesForWordsMadeOfTokens;
begin
  AssertEquals('22 November my birthday',StrDate('261122','dd mmmm ''my'' birthday'));
  AssertEquals('22 November 1126 birthday',StrDate('261122','dd mmmm my birthday'));
  AssertEquals('1500 ms',StrDuration(1500,'[s] ''ms'''));
  AssertEquals('14:30 h',StrClock('143005','hh:nn ''h'''));
  AssertEquals('14:30 14',StrClock('143005','hh:nn h'));
  AssertEquals('day: 22',StrDate('261122','''day:'' dd'));
  AssertEquals('day: 22',StrDate('261122','day: dd'));
  AssertEquals('on the 22nd',StrDate('261122','"on the" dd"nd"'));
  AssertEquals('22 x',StrDate('261122','dd ''x'));            // an unclosed quote runs to the end
end;

procedure TEuoStrFormatTests.TestLettersThatAreNeverTokens;
begin
  // c, f, t read Windows formats in FPC, e and g give era years on East-Asian Windows: always text here.
  AssertEquals('c f t e g',StrDate('261122','c f t e g'));
  AssertEquals('c f t e g',StrClock('143005','c f t e g'));
  AssertEquals('c f t e g',StrDateTime('261122','143005','c f t e g'));
  AssertEquals('c f t e g',StrDuration(60,'c f t e g'));
  AssertEquals('a 14',StrClock('143005','a hh'));   // a alone is an error in FPC: here it is text
end;

procedure TEuoStrFormatTests.TestWindowsSettingsChangeNothing;
var
  Saved : TFormatSettings;
begin
  Saved:=DefaultFormatSettings;
  try
    DefaultFormatSettings.DateSeparator:='.';
    DefaultFormatSettings.TimeSeparator:='.';
    DefaultFormatSettings.LongMonthNames[11]:='novembre';
    DefaultFormatSettings.ShortMonthNames[11]:='nov';
    DefaultFormatSettings.LongDayNames[1]:='domenica';
    DefaultFormatSettings.TimeAMString:='m.';
    DefaultFormatSettings.TimePMString:='p.';
    DefaultFormatSettings.ShortDateFormat:='d.m.yy';
    DefaultFormatSettings.DecimalSeparator:=',';
    AssertEquals('22/11/2026',StrDate('261122','dd/mm/yyyy'));
    AssertEquals('Sunday 22 November 2026',StrDate('261122','dddd d mmmm yyyy'));
    AssertEquals('14:30:05',StrClock('143005',''));
    AssertEquals('02:30 PM',StrClock('143005','hh:nn ampm'));
    AssertEquals('2026-11-22 14:30:05',StrDateTime('261122','143005',''));
    AssertEquals('1:02:05',StrDuration(3725,''));
    AssertEquals('95.3',StrDecimal(953,1));
  finally
    DefaultFormatSettings:=Saved;
  end;
end;

procedure TEuoStrFormatTests.TestPrepareFormat;
var
  P : String;
begin
  AssertTrue(PrepareFormat('Today is dddd',stkDate,P));
  AssertEquals('"Today" "is" dddd',P);
  AssertTrue(PrepareFormat('h:mm am/pm',stkClock,P));
  AssertEquals('h:nn am/pm',P);
  AssertTrue(PrepareFormat('hh:mm',stkDateTime,P));
  AssertEquals('hh:mm',P);
  AssertTrue(PrepareFormat('[h]:mm',stkDuration,P));
  AssertEquals('[h]:nn',P);
  AssertTrue(PrepareFormat('dd ''my',stkDate,P));
  AssertEquals('dd ''my''',P);   // an unclosed quote is closed
  AssertFalse(PrepareFormat('ddddd',stkDate,P));
end;

procedure TEuoStrFormatTests.TestScriptOperations;
begin
  PlayScript(
    'str decimal 953 1' + #13#10 + 'set %dec #StrRes' + #13#10 +
    'str decimal -5 1' + #13#10 + 'set %neg #StrRes' + #13#10 +
    'str duration 3725' + #13#10 + 'set %dur #StrRes' + #13#10 +
    'str duration 3725 [n] min' + #13#10 + 'set %durFmt #StrRes' + #13#10 +
    'str date 261122' + #13#10 + 'set %date #StrRes' + #13#10 +
    'str date 261122 dddd d mmmm yyyy' + #13#10 + 'set %long #StrRes' + #13#10 +
    'str date 261122 dd , / , mm' + #13#10 + 'set %glued #StrRes' + #13#10 +
    'str date 261122   dd    mm' + #13#10 + 'set %spaces #StrRes' + #13#10 +
    'str clock 143005 h:nn am/pm' + #13#10 + 'set %clock #StrRes' + #13#10 +
    'str datetime 261122 143005' + #13#10 + 'set %dt #StrRes' + #13#10 +
    'str datetime 261122 143005 dd/mm hh:nn' + #13#10 + 'set %dtFmt #StrRes' + #13#10 +
    'str date 261122 dd mmmm ''my'' birthday' + #13#10 + 'set %quoted #StrRes' + #13#10 +
    'set %secs 125' + #13#10 +
    'str duration %secs' + #13#10 + 'set %var #StrRes' + #13#10 +
    'halt');
  AssertEquals('95.3',Interp.GetVar('%dec'));
  AssertEquals('-0.5',Interp.GetVar('%neg'));
  AssertEquals('1:02:05',Interp.GetVar('%dur'));
  AssertEquals('62 min',Interp.GetVar('%durFmt'));
  AssertEquals('2026-11-22',Interp.GetVar('%date'));
  AssertEquals('Sunday 22 November 2026',Interp.GetVar('%long'));
  AssertEquals('22/11',Interp.GetVar('%glued'));
  AssertEquals('22 11',Interp.GetVar('%spaces'));
  AssertEquals('2:30 pm',Interp.GetVar('%clock'));
  AssertEquals('2026-11-22 14:30:05',Interp.GetVar('%dt'));
  AssertEquals('22/11 14:30',Interp.GetVar('%dtFmt'));
  AssertEquals('22 November my birthday',Interp.GetVar('%quoted'));
  AssertEquals('0:02:05',Interp.GetVar('%var'));
end;

procedure TEuoStrFormatTests.TestScriptMissingParameters;
begin
  PlayScript(
    'str duration' + #13#10 + 'set %a #StrRes' + #13#10 +
    'str duration abc' + #13#10 + 'set %b #StrRes' + #13#10 +
    'str decimal 953' + #13#10 + 'set %c #StrRes' + #13#10 +
    'str decimal abc 1' + #13#10 + 'set %d #StrRes' + #13#10 +
    'str decimal 953 x' + #13#10 + 'set %e #StrRes' + #13#10 +
    'str datetime 261122' + #13#10 + 'set %f #StrRes' + #13#10 +
    'str date' + #13#10 + 'set %g #StrRes' + #13#10 +
    'str clock %unset' + #13#10 + 'set %h #StrRes' + #13#10 +
    'halt');
  AssertEquals('N/A',Interp.GetVar('%a'));
  AssertEquals('N/A',Interp.GetVar('%b'));
  AssertEquals('N/A',Interp.GetVar('%c'));
  AssertEquals('N/A',Interp.GetVar('%d'));
  AssertEquals('N/A',Interp.GetVar('%e'));
  AssertEquals('N/A',Interp.GetVar('%f'));
  AssertEquals('N/A',Interp.GetVar('%g'));
  AssertEquals('N/A',Interp.GetVar('%h'));
end;

procedure TEuoStrFormatTests.TestScriptTimeWithoutLeadingZero;
var
  Clock : String;
begin
  // Arithmetic turns 093015 into 93015: STR CLOCK puts the zero back.
  PlayScript(
    'set %t 093015 + 0' + #13#10 +
    'str clock %t' + #13#10 + 'set %c #StrRes' + #13#10 +
    'str clock #Time' + #13#10 + 'set %now #StrRes' + #13#10 +
    'str date #Date' + #13#10 + 'set %today #StrRes' + #13#10 +
    'halt');
  AssertEquals('93015',Interp.GetVar('%t'));
  AssertEquals('09:30:15',Interp.GetVar('%c'));
  Clock:=Interp.GetVar('%now');
  AssertEquals(8,Length(Clock));
  AssertEquals(':',Clock[3]);
  AssertEquals(':',Clock[6]);
  AssertEquals(10,Length(Interp.GetVar('%today')));
  AssertEquals('20',Copy(Interp.GetVar('%today'),1,2));
end;

procedure TEuoStrFormatTests.TestReplacesHandWrittenElapsedTime;
const
  Secs : array[0..6] of Integer = (0, 9, 60, 599, 3600, 3725, 86399);
var
  i : Integer;
begin
  // The elapsed-time display scripts build by hand: hours, then minutes and seconds padded to two digits.
  for i:=0 to High(Secs) do
  begin
    Interp.SetVar('%tt',IntToStr(Secs[i]));
    PlayScript(
      'set %h %tt / 3600' + #13#10 +
      'set %m ( %tt / 60 ) % 60' + #13#10 +
      'set %s %tt % 60' + #13#10 +
      'if %m < 10' + #13#10 + '  set %m 0 , %m' + #13#10 +
      'if %s < 10' + #13#10 + '  set %s 0 , %s' + #13#10 +
      'set %byHand %h , : , %m , : , %s' + #13#10 +
      'str duration %tt' + #13#10 +
      'halt');
    AssertEquals(IntToStr(Secs[i]),Interp.GetVar('%byHand'),Interp.GetVar('#StrRes'));
    AssertEquals(IntToStr(Secs[i]),StrDuration(Secs[i],''),Interp.GetVar('#StrRes'));
  end;
end;

initialization
  RegisterTest(TEuoTimersTests);
  RegisterTest(TEuoTimerScriptTests);
  RegisterTest(TEuoStrFormatTests);
end.
