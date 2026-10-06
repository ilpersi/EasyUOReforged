unit MenuBenchTests;

{
  Opt-in benchmark for building a MENU window from a script. Like PerfBenchTests it is
  Ignore()d unless EUO_PERF=1 is set, so the normal CI run stays fast.

  What it measures: wall-clock time for a script to run "menu Clear" + a few dozen MENU
  lines (font changes, text/edit/button/check controls), repeated, with the script played
  on its OWN thread exactly like TExeThread does while this (main) thread services
  TThread.Synchronize -- so every MENU line that still takes the thread hop pays for it.
  The 50 ms #LPC pacing is deliberately out of the picture (no Sleep between cycles).

  What it does NOT measure: painting. The headless test host cannot show the menu form,
  so repaint coalescing (TMenuObj.BurstBegin) is never exercised and child windows are
  not realised. Treat the numbers as the CPU / thread-hop cost of a build only.

  Results are appended to perf_results.txt next to the executable. Run through
  tests\tools\RunBench.ps1 -Suite TMenuBenchTests.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, EuoInterpreter;

type
  TPlayThread = class(TThread)
  private
    FInterp : TEuoInterpreter;
  protected
    procedure Execute; override;
  public
    Done    : Boolean;
    Failure : String;
    constructor Create(AInterp : TEuoInterpreter);
  end;

  TMenuBenchTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    function  BuildScript(Rows, Rebuilds : Integer) : String;
    function  RunOnce(const Script : String; ExpectRebuilds : Integer) : Double;
    procedure Report(const Name : String; Rows, Rebuilds : Integer; BestSec, MeanSec : Double);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBuildWindow;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function Now_Sec : Double;
var
  f, c : Int64;
begin
  QueryPerformanceFrequency(f);
  QueryPerformanceCounter(c);
  Result := c / f;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TPlayThread.Create(AInterp : TEuoInterpreter);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FInterp := AInterp;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TPlayThread.Execute;
var
  Cnt : Integer;
begin
  Cnt := 0;
  try
    while (FInterp.ResInt <> RES_STOP) and (FInterp.ResInt <> RES_CLOSE) and
          (Cnt < 10000000) do
    begin
      FInterp.PlayLine;
      Inc(Cnt);
    end;
  except
    on E : Exception do Failure := E.Message;
  end;
  Done := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuBenchTests.SetUp;
begin
  Interp := TEuoInterpreter.Create(0);
  Interp.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuBenchTests.TearDown;
begin
  Interp.Free;
end;

////////////////////////////////////////////////////////////////////////////////
// Rows * 7 + 4 MENU lines per rebuild: per row a font size + colour change, then a
// text, edit, button and check control (the "build a form" shape real scripts use).
function TMenuBenchTests.BuildScript(Rows, Rebuilds : Integer) : String;
var
  S : TStringList;
  r : Integer;
begin
  S := TStringList.Create;
  try
    S.Add('set %cnt 0');
    S.Add('for %r 1 ' + IntToStr(Rebuilds));
    S.Add('  gosub Build');
    S.Add('next');
    S.Add('menu Get e' + IntToStr(Rows));
    S.Add('set %last #menuRes');
    S.Add('halt');
    S.Add('sub Build');
    S.Add('  set %cnt ( %cnt + 1 )');
    S.Add('  menu Clear');
    S.Add('  menu Window Title Bench');
    S.Add('  menu Window Size 400 600');
    S.Add('  menu Font Name Arial');
    for r := 1 to Rows do
    begin
      S.Add('  menu Font Size ' + IntToStr(8 + r mod 6));
      S.Add('  menu Font Color Black');
      S.Add(Format('  menu Text t%d 10 %d Label %d', [r, r * 20, r]));
      S.Add(Format('  menu Edit e%d 120 %d 100 value %d', [r, r * 20, r]));
      S.Add(Format('  menu Button b%d 230 %d 60 18 Go', [r, r * 20]));
      S.Add(Format('  menu Check c%d 300 %d 80 18 0 Opt %d', [r, r * 20, r]));
      S.Add(Format('  menu Set e%d changed %d', [r, r]));
    end;
    S.Add('return');
    Result := S.Text;
  finally
    S.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TMenuBenchTests.RunOnce(const Script : String; ExpectRebuilds : Integer) : Double;
var
  Thr : TPlayThread;
  t0  : Double;
begin
  Interp.Clear;
  Interp.ScrList.Scr.Text := Script;
  Interp.NextLine := 0;

  Thr := TPlayThread.Create(Interp);
  try
    t0 := Now_Sec;
    Thr.Start;
    // Service the script thread's Synchronize calls, as the GUI's message loop does.
    while not Thr.Done do
      CheckSynchronize(1);
    Result := Now_Sec - t0;
    Thr.WaitFor;
    AssertEquals('script thread failure', '', Thr.Failure);
    // Prove the script really ran every rebuild and the last control exists.
    AssertEquals('rebuilds executed', IntToStr(ExpectRebuilds), Interp.GetVar('%cnt'));
    AssertTrue('last control readable: ' + Interp.GetVar('%last'),
      Copy(Interp.GetVar('%last'), 1, 7) = 'changed');
  finally
    Thr.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuBenchTests.Report(const Name : String; Rows, Rebuilds : Integer;
  BestSec, MeanSec : Double);
var
  F       : TextFile;
  LogName : String;
  Txt     : String;
begin
  Txt := Format('PERF %-12s rows=%d rebuilds=%d  best %.1f ms/rebuild  mean %.1f ms/rebuild',
                [Name, Rows, Rebuilds, BestSec * 1000 / Rebuilds, MeanSec * 1000 / Rebuilds]);
  Writeln(Txt);
  LogName := ExtractFilePath(ParamStr(0)) + 'perf_results.txt';
  AssignFile(F, LogName);
  if FileExists(LogName) then Append(F) else Rewrite(F);
  Writeln(F, Txt);
  CloseFile(F);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenuBenchTests.TestBuildWindow;
const
  Rows     = 20;
  Rebuilds = 20;
  Runs     = 5;
var
  Script : String;
  i      : Integer;
  t, Best, Sum : Double;
begin
  if SysUtils.GetEnvironmentVariable('EUO_PERF') <> '1' then
  begin
    Ignore('set EUO_PERF=1 to run the menu benchmark');
    Exit;
  end;

  Script := BuildScript(Rows, Rebuilds);
  RunOnce(BuildScript(Rows, 2), 2);   // warm-up, discarded

  Best := 1e30;
  Sum := 0;
  for i := 1 to Runs do
  begin
    t := RunOnce(Script, Rebuilds);
    Sum := Sum + t;
    if t < Best then Best := t;
  end;
  Report('MenuBuild', Rows, Rebuilds, Best, Sum / Runs);
  AssertTrue('benchmark ran', Best < 1e30);
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TMenuBenchTests);
end.
