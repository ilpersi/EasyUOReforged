unit EuoExecutorTests;

{
  EuoExecutor.pas drives the interpreter on a real background OS thread on a 50ms
  cycle -- unlike every other test in this suite, these are necessarily
  timing-sensitive integration smoke tests, not exact synchronous unit tests. Kept
  deliberately small rather than exhaustively covering every StepOver/StepOut
  transition, which would mean asserting on precise thread-scheduling timing --
  inherently flaky and not where this migration's test budget is best spent. The
  synchronous TEuoInterpreter itself (EuoInterpreterTests.pas) already has
  exhaustive, deterministic coverage of every control-flow behavior the executor
  merely drives; these tests only confirm the thread/state-machine wiring itself.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoExecutor, EuoInterpreter;

type
  TEuoExecutorTests = class(TTestCase)
  private
    Exec : TExecutor;
    function WaitForVar(const Name, Expected : String; TimeoutMs : Cardinal = 5000) : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialStateIsStop;
    procedure TestPlayRunsScriptToCompletion;
    procedure TestStopThenReplayClearsAndRestartsFromScratch;
    procedure TestStepIntoRunsExactlyOneLineThenPauses;
    procedure TestBreakpointPausesBeforeItsLineRuns;
    procedure TestRunToCursorIsOneShotAndConsumedOnHit;
    procedure TestConditionalBreakpointOnlyPausesWhenTrue;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.SetUp;
var
  StartTick : Cardinal;
begin
  Exec := TExecutor.Create(0);
  // LoadScript only takes effect while (State=Stop) and Paused -- Paused only
  // becomes True after the background thread's first 50ms tick, so give it a
  // short window rather than racing it.
  StartTick := GetTickCount;
  while (not Exec.Paused) and (GetTickCount - StartTick < 2000) do
    Sleep(5);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TearDown;
begin
  Exec.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoExecutorTests.WaitForVar(const Name, Expected : String; TimeoutMs : Cardinal) : Boolean;
var
  StartTick : Cardinal;
begin
  StartTick := GetTickCount;
  repeat
    if Exec.GetVar(Name) = Expected then
    begin
      Result := True;
      Exit;
    end;
    Sleep(10);
  until GetTickCount - StartTick > TimeoutMs;
  Result := False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestInitialStateIsStop;
begin
  AssertEquals(Cardinal(STOP), Exec.State);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestPlayRunsScriptToCompletion;
begin
  Exec.LoadScript('SET %x done' + #13#10 + 'HALT');
  Exec.State := PLAY;
  AssertTrue('script did not reach completion within timeout',
    WaitForVar('%x', 'done'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestStopThenReplayClearsAndRestartsFromScratch;
var
  StartTick : Cardinal;
begin
  Exec.LoadScript('SET %x first' + #13#10 + 'HALT');
  Exec.State := PLAY;
  AssertTrue(WaitForVar('%x', 'first'));

  // Wait for the thread to settle into Paused (it always ends its 50ms tick with
  // Parser.Paused:=True, whether stopped or not) so LoadScript's gate reopens.
  StartTick := GetTickCount;
  while (not Exec.Paused) and (GetTickCount - StartTick < 2000) do
    Sleep(5);

  Exec.LoadScript('SET %x second' + #13#10 + 'HALT');
  Exec.State := PLAY;
  AssertTrue(WaitForVar('%x', 'second'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestStepIntoRunsExactlyOneLineThenPauses;
begin
  Exec.LoadScript('SET %a 1' + #13#10 + 'SET %b 2' + #13#10 + 'HALT');
  Exec.State := STEPINTO;
  AssertTrue(WaitForVar('%a', '1'));

  // Give the thread a further moment to have settled into Pause; StepInto forces
  // exactly one PlayLine per tick, so %b must never get set.
  Sleep(150);
  AssertEquals('N/A', Exec.GetVar('%b'));
  AssertEquals(Cardinal(PAUSE), Exec.State);
end;

////////////////////////////////////////////////////////////////////////////////
// Breakpoints (below) are a new addition, not present in the original
// Delphi 7 app -- see EuoExecutor.pas's own header comment for why they're
// checked inline in the background thread's loop (same place Step*
// already checks its own pause conditions) rather than via external
// polling.
procedure TEuoExecutorTests.TestBreakpointPausesBeforeItsLineRuns;
begin
  Exec.LoadScript(
    'SET %a 1' + #13#10 +   // line 1
    'SET %b 2' + #13#10 +   // line 2 -- breakpoint here
    'SET %c 3' + #13#10 +   // line 3
    'HALT');
  Exec.ToggleBreakpoint(2);
  Exec.State := PLAY;
  AssertTrue('%a should have run', WaitForVar('%a', '1'));
  Sleep(150); // let the thread settle into its post-pause state
  AssertEquals(Cardinal(PAUSE), Exec.State);
  AssertEquals('line 2 must not have run yet', 'N/A', Exec.GetVar('%b'));
  AssertEquals('line 3 must not have run yet', 'N/A', Exec.GetVar('%c'));
  AssertEquals(2, Exec.BreakLine);

  Exec.ToggleBreakpoint(2); // remove so resuming doesn't hit it again
  Exec.State := PLAY;
  AssertTrue('script did not complete after resuming', WaitForVar('%c', '3'));
  AssertEquals('BreakLine must clear on resume', -1, Exec.BreakLine);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestRunToCursorIsOneShotAndConsumedOnHit;
begin
  Exec.LoadScript(
    'SET %x 1' + #13#10 +
    'SET %y 2' + #13#10 +
    'SET %z 3' + #13#10 +
    'HALT');
  Exec.RunToLine(3);
  AssertTrue('%y should have run', WaitForVar('%y', '2'));
  Sleep(150);
  AssertEquals(Cardinal(PAUSE), Exec.State);
  AssertEquals('line 3 must not have run yet', 'N/A', Exec.GetVar('%z'));
  AssertFalse('one-shot breakpoint must be consumed on hit', Exec.HasBreakpoint(3));

  Exec.State := PLAY;
  AssertTrue('script did not complete after resuming', WaitForVar('%z', '3'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoExecutorTests.TestConditionalBreakpointOnlyPausesWhenTrue;
begin
  Exec.LoadScript(
    'SET %i 1' + #13#10 +  // line 1
    'SET %i 2' + #13#10 +  // line 2
    'SET %i 3' + #13#10 +  // line 3 -- this is what makes %i become 3
    'SET %i 4' + #13#10 +  // line 4 -- breakpoint here, condition "%i = 3"
    'HALT');                // line 5
  // Checked BEFORE the target line runs, same as an unconditional
  // breakpoint -- to catch %i right after it becomes 3, the breakpoint
  // belongs on the line AFTER the one that sets it, not on that line
  // itself (which would see %i still at its PREVIOUS value).
  Exec.SetBreakpointCondition(4, '%i = 3');
  Exec.State := PLAY;
  AssertTrue('script did not reach the breakpoint', WaitForVar('%i', '3'));
  Sleep(150);
  AssertEquals(Cardinal(PAUSE), Exec.State);
  AssertEquals(4, Exec.BreakLine);

  Exec.ClearAllBreakpoints;
  Exec.State := PLAY;
  AssertTrue('script did not complete after resuming', WaitForVar('%i', '4'));
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoExecutorTests);
end.
