unit EuoLogFileTests;

{
  Tests for the LOGFILE command and its logging system (parser\EuoLogFile.pas), with no client:
  levels, the output target, file targets as plain file writing and as logs, formats, append and
  new, size and daily rotation, errors in #LogRes, files shared by two interpreters and by two
  threads, files closed when a run ends, and EUOCli's program-folder rule (ConfineFiles).

  Scripts are played line by line on the test's own thread, as in EuoHostHooksTests. Files go to a
  folder of their own under the temp folder, removed afterwards; the few tests of relative names
  use a folder of their own next to the test program, removed too.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, SyncObjs, fpcunit, testregistry, EuoInterpreter, EuoExecutor, EuoLogFile;

type
  TEuoLogFileTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    Dir    : String;     // the test's own folder, with a trailing '\'
    procedure Play(const Script : array of String; MaxSteps : Integer = 2000);
    function  ReadBytes(const FN : String) : String;
    function  ReadLines(const FN : String) : TStringList;
    procedure RemoveTree(const D : String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWriteIsTheTextExactly;
    procedure TestAConfigWrittenLoadsBackWithCall;
    procedure TestNewEmptiesTheFileAppendKeepsIt;
    procedure TestOutputTargetGoesToTheLogQueue;
    procedure TestLevelsOfTheScriptAndOfATarget;
    procedure TestFileFormatAndFields;
    procedure TestScriptFieldNamesTheCalledFile;
    procedure TestErrorsGoToLogRes;
    procedure TestLogResIsResetByClear;
    procedure TestSizeRotationKeepsNumberedFiles;
    procedure TestDailyRotationNamesTheDay;
    procedure TestDailyRotationOfAFileLastWrittenYesterday;
    procedure TestDailyRotationKeepsTheNewestDays;
    procedure TestDailyAndSizeRotationTogether;
    procedure TestTwoInterpretersShareAFile;
    procedure TestTwoThreadsWriteWholeLines;
    procedure TestClearAndCloseReleaseTheFile;
    procedure TestFilesAreClosedWhenTheRunHalts;
    procedure TestFilesAreClosedWhenTheRunIsStopped;
    procedure TestConfinedFilesStayInTheProgramFolder;
    procedure TestRelativeNamesStartAtCurPath;
    procedure TestASubCalledLogfileStillWorks;
    procedure TestWritingIsFast;
  end;

implementation

const
  CRLF = #13#10;

var
  FakeNow : TDateTime;

function FakeClock : TDateTime;
begin
  Result:=FakeNow;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir(False))+'euologfile-'+IntToStr(GetTickCount64)+'-'+
    IntToStr(Random(100000))+'\';
  ForceDirectories(Dir);
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TearDown;
begin
  Interp.Free;
  RemoveTree(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.RemoveTree(const D : String);
var
  SR : TSearchRec;
begin
  if not DirectoryExists(D) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(D)+'*',faAnyFile,SR)=0 then
  try
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then RemoveTree(IncludeTrailingPathDelimiter(D)+SR.Name)
      else begin
        FileSetAttr(IncludeTrailingPathDelimiter(D)+SR.Name,0);
        DeleteFile(IncludeTrailingPathDelimiter(D)+SR.Name);
      end;
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
  RemoveDir(D);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.Play(const Script : array of String; MaxSteps : Integer);
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
function TEuoLogFileTests.ReadBytes(const FN : String) : String;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;
end;

function TEuoLogFileTests.ReadLines(const FN : String) : TStringList;
begin
  Result:=TStringList.Create;
  Result.Text:=ReadBytes(FN);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestWriteIsTheTextExactly;
begin
  Play(['set %hp 50',
        'logfile open cfg '+Dir+'a.txt new',
        'logfile write cfg #smc , Saved by a test',
        'logfile write cfg set % , hp %hp',
        'logfile write cfg Runebook$Blessed$   spaced    out',
        'logfile write cfg caf'#$C3#$A9' & | > ^ %',
        'logfile write cfg',
        'logfile close cfg',
        'halt']);
  AssertEquals('OK',Interp.GetVar('#LogRes'));
  AssertEquals('every line as given, UTF-8 without a BOM, CRLF',
    ';Saved by a test'+CRLF+'set %hp 50'+CRLF+'Runebook$Blessed$ spaced out'+CRLF+
    'caf'#$C3#$A9' & | > ^ %'+CRLF+CRLF,
    ReadBytes(Dir+'a.txt'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestAConfigWrittenLoadsBackWithCall;
begin
  Play(['set %hp 50',
        'set %name Lord_British',
        'set %i 3',
        'set %x3 1234',
        'logfile open cfg '+Dir+'cfg.txt new',
        'logfile write cfg #smc , Created by a test',
        'logfile write cfg set % , hp %hp',
        'logfile write cfg set % , name %name',
        'logfile write cfg set % , X , %i , #spc , %x . %i',
        'logfile close cfg',
        'set %hp 0',
        'set %name nobody',
        'set %x3 0',
        'call '+Dir+'cfg.txt',
        'halt']);
  AssertEquals('50',Interp.GetVar('%hp'));
  AssertEquals('Lord_British',Interp.GetVar('%name'));
  AssertEquals('the rail writer''s glued names',
    '1234',Interp.GetVar('%x3'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestNewEmptiesTheFileAppendKeepsIt;
begin
  Play(['logfile open f '+Dir+'b.txt new','logfile write f one','logfile close f',
        'logfile open f '+Dir+'b.txt','logfile write f two','logfile close f',
        'logfile open f '+Dir+'b.txt append','logfile write f three','logfile close f','halt']);
  AssertEquals('one'+CRLF+'two'+CRLF+'three'+CRLF,ReadBytes(Dir+'b.txt'));
  Play(['logfile open f '+Dir+'b.txt new','logfile write f fresh','halt']);
  AssertEquals('new empties it, as > did',
    'fresh'+CRLF,ReadBytes(Dir+'b.txt'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestOutputTargetGoesToTheLogQueue;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    Play(['log plain log',
          'logfile info Started',
          'logfile warning Low on bandages',
          'logfile write output just this',
          'logfile set output format raw',
          'logfile error raw now',
          'logfile set output format level line',
          'logfile debug with the line',
          'halt']);
    Interp.TakeLog(L);
    AssertEquals(6,L.Count);
    AssertEquals('LOG is unchanged','plain log',L[0]);
    AssertEquals('[Info] Started',L[1]);
    AssertEquals('the 1-based script line, as LOG',2,Integer(PtrUInt(L.Objects[1])));
    AssertEquals('[Warning] Low on bandages',L[2]);
    AssertEquals('write adds nothing','just this',L[3]);
    AssertEquals('raw now',L[4]);
    AssertEquals('[Debug] line 8 with the line',L[5]);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestLevelsOfTheScriptAndOfATarget;
var
  L : TStringList;
  F : TStringList;
begin
  L:=TStringList.Create;
  try
    Play(['logfile open f '+Dir+'lv.log new',
          'logfile set f format raw',
          'logfile set output level warning',
          'logfile debug d1',
          'logfile info i1',
          'logfile warning w1',
          'logfile level error',
          'logfile warning w2',
          'logfile error e2',
          'logfile write f written whatever the level',
          'logfile level off',
          'logfile error e3',
          'logfile level debug',
          'logfile set f level off',
          'logfile set output level debug',
          'logfile debug d4',
          'halt']);
    Interp.TakeLog(L);
    AssertEquals('[Warning] w1|[Error] e2|[Debug] d4',StringReplace(Trim(L.Text),CRLF,'|',[rfReplaceAll]));
    F:=ReadLines(Dir+'lv.log');
    try
      AssertEquals('d1|i1|w1|e2|written whatever the level',StringReplace(Trim(F.Text),CRLF,'|',[rfReplaceAll]));
    finally
      F.Free;
    end;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestFileFormatAndFields;
var
  F : TStringList;
  S : String;
begin
  Interp.ScriptName:='heal.euo';
  Play(['logfile open f '+Dir+'fmt.log new',
        'logfile warning Low on bandages',
        'logfile set f format level',
        'logfile info two',
        'logfile set f format time script',
        'logfile info three',
        'logfile set f format date',
        'logfile info',
        'halt']);
  F:=ReadLines(Dir+'fmt.log');
  try
    AssertEquals(4,F.Count);
    S:=F[0];
    // 2026-11-18 14:03:22.123 [Warning] heal.euo:2 Low on bandages
    AssertEquals('date',10,Pos(' ',S)-1);
    AssertEquals('-',S[5]);
    AssertEquals(' ',S[11]);
    AssertEquals(':',S[14]);
    AssertEquals('.',S[20]);
    AssertEquals('[Warning] heal.euo:2 Low on bandages',Copy(S,25,MaxInt));
    AssertEquals('[Info] two',F[1]);
    AssertEquals('heal.euo three',Copy(F[2],14,MaxInt));
    AssertEquals('a message with no text is the fields',FormatDateTime('yyyy-mm-dd',Now),F[3]);
  finally
    F.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestScriptFieldNamesTheCalledFile;
var
  L  : TStringList;
  CF : TStringList;
begin
  CF:=TStringList.Create;
  L:=TStringList.Create;
  try
    CF.Text:='logfile info from the called file'+CRLF;
    CF.SaveToFile(Dir+'sub.euo');
    Play(['logfile set output format script line','logfile info main one','call '+Dir+'sub.euo',
          'logfile info back','halt']);
    Interp.TakeLog(L);
    AssertEquals(3,L.Count);
    AssertEquals('no name from the host','main:2 main one',L[0]);
    AssertEquals('sub.euo:1 from the called file',L[1]);
    AssertEquals('main:4 back',L[2]);
  finally
    L.Free;
    CF.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestErrorsGoToLogRes;

  function Res(const Line : String) : String;
  begin
    Play([Line,'halt']);
    Result:=Interp.GetVar('#LogRes');
  end;

begin
  AssertEquals('no target cfg',Res('logfile write cfg x'));
  AssertEquals('no target cfg',Res('logfile set cfg level info'));
  AssertEquals('unknown logfile command foo',Res('logfile foo'));
  AssertEquals('logfile needs a command: open, close, write, debug, info, warning, error, level or set',Res('logfile'));
  AssertEquals('unknown level loud: debug, info, warning, error or off',Res('logfile level loud'));
  AssertEquals('open takes append or new, not twice',Res('logfile open f '+Dir+'x.txt twice'));
  AssertEquals('not a file: '+Dir,Res('logfile open f '+Dir));
  AssertEquals('a folder, not a file: '+ExcludeTrailingPathDelimiter(Dir),
    Res('logfile open f '+ExcludeTrailingPathDelimiter(Dir)));
  AssertEquals('output is the Output panel: give the file another target name',Res('logfile open output '+Dir+'x.txt'));
  AssertEquals('output cannot be closed: logfile set output level off silences it',Res('logfile close output'));
  AssertEquals('unknown format field when: raw, or any of date time level script line',Res('logfile set output format when'));
  AssertEquals('unknown logfile set option color: level, format, rotate or daily',Res('logfile set output color red'));
  AssertEquals('output is the Output panel, not a file',Res('logfile set output rotate 1m'));
  AssertEquals('#Result is left alone','N/A',Interp.GetVar('#Result'));

  // A file nobody may write.
  with TStringList.Create do
  try
    Add('locked');
    SaveToFile(Dir+'ro.txt');
  finally
    Free;
  end;
  FileSetAttr(Dir+'ro.txt',faReadOnly);
  AssertTrue('a read-only file is refused',Pos('cannot open '+Dir+'ro.txt: ',Res('logfile open f '+Dir+'ro.txt'))=1);
  AssertTrue('and new does not empty it',Pos('cannot open',Res('logfile open f '+Dir+'ro.txt new'))=1);
  AssertEquals('locked',Trim(ReadBytes(Dir+'ro.txt')));
  // A folder in the way of the file's folder.
  AssertTrue(Pos('cannot create the folder',Res('logfile open f '+Dir+'ro.txt\inner\x.log'))=1);

  AssertEquals('OK',Res('logfile info fine'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestLogResIsResetByClear;
begin
  AssertEquals('N/A before any logfile line','N/A',Interp.GetVar('#LogRes'));
  Play(['logfile info x','halt']);
  AssertEquals('OK',Interp.GetVar('#LogRes'));
  Interp.Clear;
  AssertEquals('N/A',Interp.GetVar('#LogRes'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestSizeRotationKeepsNumberedFiles;
begin
  // Each line is 9 bytes with its CRLF: 3 fit in 27 bytes.
  Play(['logfile open f '+Dir+'run.log new',
        'logfile set f format raw',
        'logfile set f rotate 27 2',
        'for %i 10 21',
        '  logfile info line_ , %i',
        'halt']);
  AssertEquals('OK',Interp.GetVar('#LogRes'));
  AssertEquals('line_19'+CRLF+'line_20'+CRLF+'line_21'+CRLF,ReadBytes(Dir+'run.log'));
  AssertEquals('line_16'+CRLF+'line_17'+CRLF+'line_18'+CRLF,ReadBytes(Dir+'run.1.log'));
  AssertEquals('line_13'+CRLF+'line_14'+CRLF+'line_15'+CRLF,ReadBytes(Dir+'run.2.log'));
  AssertFalse('keep 2: the oldest went',FileExists(Dir+'run.3.log'));

  Play(['logfile set f rotate 0','for %i 1 20','  logfile info more','halt']);
  AssertFalse('0 turns it off',FileExists(Dir+'run.3.log'));
  Play(['logfile set f rotate 2k','halt']);
  AssertEquals('OK',Interp.GetVar('#LogRes'));
  Play(['logfile set f rotate big','halt']);
  AssertEquals('rotate needs a size: bytes, or with k or m, 0 = off',Interp.GetVar('#LogRes'));
end;


////////////////////////////////////////////////////////////////////////////////
function RawWords : TStringList;
begin
  Result:=TStringList.Create;
  Result.Add('raw');
end;

// A logger with its own clock, writing raw lines to Dir+Name.
function DayLogger(const Path : String) : TEuoScriptLogger;
var
  W : TStringList;
begin
  Result:=TEuoScriptLogger.Create(nil);
  Result.Clock:=FakeClock;
  if Result.Open('d',Path,False)<>'' then raise Exception.Create('cannot open '+Path);
  W:=RawWords;
  try
    Result.SetFormat('d',W);
  finally
    W.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestDailyRotationNamesTheDay;
var
  Lg : TEuoScriptLogger;
begin
  FakeNow:=EncodeDate(2026,11,17)+EncodeTime(23,59,0,0);
  Lg:=DayLogger(Dir+'day.log');
  try
    AssertEquals('',Lg.SetDaily('d',''));
    AssertEquals('',Lg.Log(etInfo,'late','',0));
    AssertEquals('',Lg.Log(etInfo,'later','',0));
    FakeNow:=EncodeDate(2026,11,18)+EncodeTime(0,1,0,0);
    AssertEquals('',Lg.Log(etInfo,'early','',0));
    AssertEquals('',Lg.Log(etInfo,'same day','',0));
  finally
    Lg.Free;
  end;
  AssertEquals('the day it holds','late'+CRLF+'later'+CRLF,ReadBytes(Dir+'day.2026-11-17.log'));
  AssertEquals('early'+CRLF+'same day'+CRLF,ReadBytes(Dir+'day.log'));

  // A day that already has its file (rotated once, then written again with that day): one file a
  // day. day.log was last written today, by the clock of the machine.
  with TStringList.Create do
  try
    Add('earlier');
    SaveToFile(Dir+'day.'+FormatDateTime('yyyy-mm-dd',Date)+'.log');
  finally
    Free;
  end;
  FakeNow:=Date+1+EncodeTime(1,0,0,0);
  Lg:=DayLogger(Dir+'day.log');
  try
    Lg.SetDaily('d','');
    Lg.Log(etInfo,'next day','',0);
  finally
    Lg.Free;
  end;
  AssertEquals('earlier'+CRLF+'early'+CRLF+'same day'+CRLF,ReadBytes(Dir+'day.'+FormatDateTime('yyyy-mm-dd',Date)+'.log'));
  AssertEquals('next day'+CRLF,ReadBytes(Dir+'day.log'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestDailyRotationOfAFileLastWrittenYesterday;
var
  Lg : TEuoScriptLogger;
begin
  with TStringList.Create do
  try
    Add('written today');
    SaveToFile(Dir+'old.log');
  finally
    Free;
  end;
  // Opened tomorrow: the file's last-write time says which day it holds.
  FakeNow:=Now+1;
  Lg:=DayLogger(Dir+'old.log');
  try
    Lg.SetDaily('d','');
    AssertEquals('',Lg.Log(etInfo,'tomorrow','',0));
  finally
    Lg.Free;
  end;
  AssertEquals('written today'+LineEnding,ReadBytes(Dir+'old.'+FormatDateTime('yyyy-mm-dd',Date)+'.log'));
  AssertEquals('tomorrow'+CRLF,ReadBytes(Dir+'old.log'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestDailyRotationKeepsTheNewestDays;
var
  Lg : TEuoScriptLogger;
  D  : Integer;
begin
  FakeNow:=EncodeDate(2026,11,1)+EncodeTime(12,0,0,0);
  Lg:=DayLogger(Dir+'k.log');
  try
    AssertEquals('',Lg.SetDaily('d','2'));
    for D:=1 to 5 do
    begin
      FakeNow:=EncodeDate(2026,11,D)+EncodeTime(12,0,0,0);
      Lg.Log(etInfo,'day '+IntToStr(D),'',0);
    end;
    AssertEquals('daily keeps 1 to 3650 days, or off, not 0',Lg.SetDaily('d','0'));
    AssertEquals('',Lg.SetDaily('d','off'));
    FakeNow:=EncodeDate(2026,11,6)+EncodeTime(12,0,0,0);
    Lg.Log(etInfo,'off now','',0);
  finally
    Lg.Free;
  end;
  AssertFalse(FileExists(Dir+'k.2026-11-01.log'));
  AssertFalse(FileExists(Dir+'k.2026-11-02.log'));
  AssertEquals('day 3'+CRLF,ReadBytes(Dir+'k.2026-11-03.log'));
  AssertEquals('day 4'+CRLF,ReadBytes(Dir+'k.2026-11-04.log'));
  AssertEquals('day 5'+CRLF+'off now'+CRLF,ReadBytes(Dir+'k.log'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestDailyAndSizeRotationTogether;
var
  Lg : TEuoScriptLogger;
  i  : Integer;
begin
  FakeNow:=EncodeDate(2026,11,17)+EncodeTime(10,0,0,0);
  Lg:=DayLogger(Dir+'both.log');
  try
    Lg.SetDaily('d','');
    AssertEquals('',Lg.SetRotate('d','20','3'));   // two 10-byte lines a file
    for i:=1 to 5 do Lg.Log(etInfo,'a'+IntToStr(i)+'xxxxxx','',0);
    AssertEquals('a1xxxxxx'+CRLF+'a2xxxxxx'+CRLF,ReadBytes(Dir+'both.2.log'));
    FakeNow:=EncodeDate(2026,11,18)+EncodeTime(10,0,0,0);
    Lg.Log(etInfo,'b1xxxxxx','',0);
  finally
    Lg.Free;
  end;
  AssertEquals('a5xxxxxx'+CRLF,ReadBytes(Dir+'both.2026-11-17.log'));
  AssertEquals('a3xxxxxx'+CRLF+'a4xxxxxx'+CRLF,ReadBytes(Dir+'both.2026-11-17.1.log'));
  AssertEquals('a1xxxxxx'+CRLF+'a2xxxxxx'+CRLF,ReadBytes(Dir+'both.2026-11-17.2.log'));
  AssertFalse('the numbered files went with their day',FileExists(Dir+'both.1.log'));
  AssertEquals('b1xxxxxx'+CRLF,ReadBytes(Dir+'both.log'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestTwoInterpretersShareAFile;
var
  B      : TEuoInterpreter;
  Before : Integer;

  procedure PlayB(const Script : array of String);
  var
    Cnt : Integer;
    S   : String;
  begin
    S:='';
    for Cnt:=Low(Script) to High(Script) do S:=S+Script[Cnt]+CRLF;
    B.ScrList.Scr.Text:=S;
    B.NextLine:=0;
    B.ResInt:=RES_OK;
    while B.ResInt<>RES_STOP do B.PlayLine;
  end;

begin
  Before:=OpenLogFileCount;
  B:=TEuoInterpreter.Create(0);
  try
    B.Clear;
    Play(['logfile open f '+Dir+'shared.log new','logfile set f format raw','logfile info A1','halt']);
    PlayB(['logfile open g '+Dir+'shared.log','logfile set g format raw','logfile info B1','halt']);
    AssertEquals('one handle for both',Before+1,OpenLogFileCount);
    Play(['logfile info A2','halt']);
    PlayB(['logfile info B2','halt']);
    Play(['logfile close','halt']);
    AssertEquals('still open for the other',Before+1,OpenLogFileCount);
    PlayB(['logfile write g B3','halt']);
    AssertEquals('A1'+CRLF+'B1'+CRLF+'A2'+CRLF+'B2'+CRLF+'B3'+CRLF,ReadBytes(Dir+'shared.log'));
  finally
    B.Free;
  end;
  AssertEquals('closed with the last of them',Before,OpenLogFileCount);
end;

////////////////////////////////////////////////////////////////////////////////
type
  TWriterThread = class(TThread)
  public
    Path : String;
    Tag  : String;
    Err  : String;
    procedure Execute; override;
  end;

const
  THREAD_LINES = 2000;

procedure TWriterThread.Execute;
var
  Lg : TEuoScriptLogger;
  i  : Integer;
  W  : TStringList;
  E  : String;
begin
  Lg:=TEuoScriptLogger.Create(nil);
  W:=RawWords;
  try
    Err:=Lg.Open('f',Path,False);
    Lg.SetFormat('f',W);
    for i:=1 to THREAD_LINES do
    begin
      E:=Lg.Log(etInfo,Tag+' '+IntToStr(i)+' '+StringOfChar('x',60),'',0);
      if (E<>'') and (Err='') then Err:=E;
    end;
  finally
    W.Free;
    Lg.Free;
  end;
end;

procedure TEuoLogFileTests.TestTwoThreadsWriteWholeLines;
var
  T1, T2 : TWriterThread;
  L      : TStringList;
  i, N1, N2, K : Integer;
  P      : TStringList;
begin
  T1:=TWriterThread.Create(True);
  T2:=TWriterThread.Create(True);
  try
    T1.Path:=Dir+'threads.log';
    T2.Path:=Dir+'threads.log';
    T1.Tag:='one';
    T2.Tag:='two';
    T1.Start;
    T2.Start;
    T1.WaitFor;
    T2.WaitFor;
    AssertEquals('',T1.Err);
    AssertEquals('',T2.Err);
  finally
    T1.Free;
    T2.Free;
  end;
  L:=ReadLines(Dir+'threads.log');
  P:=TStringList.Create;
  try
    AssertEquals(2*THREAD_LINES,L.Count);
    N1:=0;
    N2:=0;
    P.Delimiter:=' ';
    P.StrictDelimiter:=True;
    for i:=0 to L.Count-1 do
    begin
      P.DelimitedText:=L[i];
      AssertEquals('a whole line: '+L[i],3,P.Count);
      AssertEquals(StringOfChar('x',60),P[2]);
      K:=StrToInt(P[1]);
      if P[0]='one' then
      begin
        Inc(N1);
        AssertEquals('each thread''s lines in order',N1,K);
      end
      else begin
        AssertEquals('two',P[0]);
        Inc(N2);
        AssertEquals(N2,K);
      end;
    end;
  finally
    P.Free;
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Whether a program can have the file to itself, which it can't while LOGFILE holds it.
function CanOpenAlone(const FN : String) : Boolean;
var
  FS : TFileStream;
begin
  try
    FS:=TFileStream.Create(FN,fmOpenReadWrite or fmShareExclusive);
    FS.Free;
    Result:=True;
  except
    Result:=False;
  end;
end;

procedure TEuoLogFileTests.TestClearAndCloseReleaseTheFile;
var
  Before : Integer;
begin
  Before:=OpenLogFileCount;
  Play(['logfile open f '+Dir+'c.log','logfile info x','halt']);
  AssertFalse('held while the target is open',CanOpenAlone(Dir+'c.log'));
  AssertTrue('but anyone may read it',Length(ReadBytes(Dir+'c.log'))>0);
  Play(['logfile close f','halt']);
  AssertTrue('close lets it go',CanOpenAlone(Dir+'c.log'));
  Play(['logfile open f '+Dir+'c.log','logfile open g '+Dir+'d.log','halt']);
  AssertEquals(Before+2,OpenLogFileCount);
  Play(['logfile close','halt']);
  AssertEquals('close alone closes every file',Before,OpenLogFileCount);
  Play(['logfile open f '+Dir+'c.log','halt']);
  Interp.Clear;
  AssertTrue('Clear (a new run) lets it go',CanOpenAlone(Dir+'c.log'));
  Play(['logfile info after clear','halt']);
  AssertEquals('the target went with it','OK',Interp.GetVar('#LogRes'));
  Play(['logfile write f x','halt']);
  AssertEquals('no target f',Interp.GetVar('#LogRes'));
end;

////////////////////////////////////////////////////////////////////////////////
function WaitUntilAlone(const FN : String; Ms : Integer) : Boolean;
var
  Start : QWord;
begin
  Start:=GetTickCount64;
  repeat
    Result:=CanOpenAlone(FN);
    if Result then Exit;
    Sleep(20);
  until GetTickCount64-Start>QWord(Ms);
end;

procedure TEuoLogFileTests.TestFilesAreClosedWhenTheRunHalts;
var
  Ex    : TExecutor;
  Start : QWord;
begin
  Ex:=TExecutor.Create(0);
  try
    Start:=GetTickCount64;
    while (not Ex.Paused) and (GetTickCount64-Start<3000) do Sleep(5);
    Ex.LoadScript('logfile open f '+Dir+'h.log'+CRLF+'logfile info x'+CRLF+'wait 5'+CRLF+'halt'+CRLF);
    Ex.State:=EuoExecutor.PLAY;
    Start:=GetTickCount64;
    while (Ex.GetVar('#LogRes')<>'OK') and (GetTickCount64-Start<3000) do Sleep(5);
    AssertFalse('open while the script runs',CanOpenAlone(Dir+'h.log'));
    AssertTrue('closed once it halts',WaitUntilAlone(Dir+'h.log',3000));
    AssertEquals(Cardinal(STOP),Ex.State);
  finally
    Ex.Free;
  end;
  AssertEquals('[Info] main:2 x',Copy(Trim(ReadBytes(Dir+'h.log')),25,MaxInt));
end;

procedure TEuoLogFileTests.TestFilesAreClosedWhenTheRunIsStopped;
var
  Ex    : TExecutor;
  Start : QWord;
begin
  Ex:=TExecutor.Create(0);
  try
    Start:=GetTickCount64;
    while (not Ex.Paused) and (GetTickCount64-Start<3000) do Sleep(5);
    Ex.LoadScript('logfile open f '+Dir+'s.log'+CRLF+'repeat'+CRLF+'  wait 1'+CRLF+'until #false'+CRLF);
    Ex.State:=EuoExecutor.PLAY;
    Start:=GetTickCount64;
    while (Ex.GetVar('#LogRes')<>'OK') and (GetTickCount64-Start<3000) do Sleep(5);
    AssertEquals('OK',Ex.GetVar('#LogRes'));
    Ex.State:=PAUSE;
    Sleep(200);
    AssertFalse('a pause keeps it open',CanOpenAlone(Dir+'s.log'));
    Ex.State:=STOP;
    AssertTrue('Stop closes it',WaitUntilAlone(Dir+'s.log',3000));
  finally
    Ex.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestConfinedFilesStayInTheProgramFolder;
var
  Sub  : String;
  Base : String;
begin
  Base:=ExtractFilePath(ParamStr(0));
  Sub:='euologfile-confined-'+IntToStr(Random(1000000));
  Interp.ConfineFiles:=True;
  try
    Play(['logfile open f '+Dir+'abs.log','halt']);
    AssertEquals('outside the program folder: '+Dir+'abs.log',Interp.GetVar('#LogRes'));
    Play(['logfile open f ..\up.log','halt']);
    AssertEquals('outside the program folder: ..\up.log',Interp.GetVar('#LogRes'));
    Play(['logfile open f '+Sub+'/../../up.log','halt']);
    AssertEquals('outside the program folder: '+Sub+'/../../up.log',Interp.GetVar('#LogRes'));
    Play(['logfile open f C:up.log','halt']);
    AssertEquals('outside the program folder: C:up.log',Interp.GetVar('#LogRes'));
    AssertFalse(FileExists(Dir+'abs.log'));

    Play(['logfile open f '+Sub+'\in.log new','logfile write f inside','logfile close f','halt']);
    AssertEquals('OK',Interp.GetVar('#LogRes'));
    AssertEquals('inside'+CRLF,ReadBytes(Base+Sub+'\in.log'));
  finally
    Interp.ConfineFiles:=False;
    RemoveTree(Base+Sub);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestRelativeNamesStartAtCurPath;
var
  Sub : String;
begin
  Sub:='euologfile-relative-'+IntToStr(Random(1000000));
  try
    Play(['logfile open cfg '+Sub+'\deep\cfg.txt new','logfile write cfg set % , v 42','logfile close cfg',
          'call '+Sub+'\deep\cfg','halt']);
    AssertEquals('OK',Interp.GetVar('#LogRes'));
    AssertTrue('in #CurPath, folders made',FileExists(Interp.GetVar('#CurPath')+Sub+'\deep\cfg.txt'));
    AssertEquals('CALL finds it by the same name','42',Interp.GetVar('%v'));
  finally
    RemoveTree(ExtractFilePath(ParamStr(0))+Sub);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestASubCalledLogfileStillWorks;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    // "logfile" is only a command as the first word of a line. A script that already had a sub or
    // a label of that name runs as before.
    Play(['gosub logfile 7','goto logfile','set %skipped 1','logfile:','halt','sub logfile','  set %got %1','return']);
    AssertEquals('7',Interp.GetVar('%got'));
    AssertEquals('the goto jumped over the set','N/A',Interp.GetVar('%skipped'));
    AssertEquals('no logfile line ran','N/A',Interp.GetVar('#LogRes'));
    AssertFalse(Interp.TakeLog(L));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLogFileTests.TestWritingIsFast;
var
  Start : QWord;
  L     : TStringList;
begin
  // CEOMedic writes its config in 40 EXECUTE lines of 2 s each. Ten times that here.
  Start:=GetTickCount64;
  Play(['logfile open cfg '+Dir+'fast.txt new','for %i 1 400','  logfile write cfg set % , v , %i , #spc , %i',
        'logfile close cfg','halt'],5000);
  AssertTrue('400 lines in well under a second each',GetTickCount64-Start<3000);
  L:=ReadLines(Dir+'fast.txt');
  try
    AssertEquals(400,L.Count);
    AssertEquals('set %v400 400',L[399]);
  finally
    L.Free;
  end;
end;

initialization
  RegisterTest(TEuoLogFileTests);
end.
