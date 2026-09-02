unit EuoInterpreterTests;

{
  Tier-2 golden-master script corpus for EuoInterpreter.pas (TEuoInterpreter), per
  the migration plan's testing strategy -- the primary safety net for control-flow
  correctness, since there is no working Delphi 7 install on this machine to
  differentially test against. Each test runs a small literal EasyUO script through
  the real interpreter (Cmd2/client-dependent commands are unreachable, since
  tests\stubs\uoselector.pas's TUOSel.Nr always returns 0) and asserts on
  %var/#var/#Result/#StrRes outcomes. Every "must-preserve-exactly" behavior called
  out in EuoInterpreter.pas's own header comment gets a named case here.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter, ReforgedVersion;

type
  TEuoInterpreterTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    procedure PlayScript(const Script : String; MaxSteps : Integer = 500);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSetLiteral;
    procedure TestSetArithmeticShorthand;
    procedure TestBooleanEncodingIsMinusOneAndZero;
    procedure TestCommaTokenMergeAndDiscard;
    procedure TestUnrecognizedCommandIsSilentNoOp;
    procedure TestVersionVarsAreDistinct;
    procedure TestDiagnosticsReportBuildsAsMultilineBlock;
    procedure TestMenuMemoRoundTripsThroughGet;
    procedure TestClientGatedCommandIsSilentNoOpWithNoClient;

    procedure TestIfTrueRunsBodyAndSkipsElse;
    procedure TestIfFalseSkipsBodyAndRunsElse;
    procedure TestIfBlockBraces;

    procedure TestForLoopCountsUp;
    procedure TestForLoopCountsDown;

    procedure TestWhileUntilLoop;

    procedure TestGotoForward;
    procedure TestGotoBackward;

    procedure TestGoSubReturnWithArgs;
    procedure TestGoSubDuplicateNameResolvesToLastMatch;
    procedure TestReturnWithNoActiveGoSubIsATrueNoOp;

    procedure TestExitAtOutermostFrameRestartsFromLineZero;
    procedure TestImplicitEofIsImplicitExit;
    procedure TestHaltActuallyStops;

    procedure TestStrCommandLenUpperLowerLeftRightMid;
    procedure TestDeleteVarRemovesUserVariable;

    procedure TestNameSpaceLocalIsolatesFromDefaultStd;
    procedure TestNameSpaceGlobalSingletonIsSharedAcrossInterpreterInstances;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.SetUp;
begin
  Interp := TEuoInterpreter.Create(0);
  Interp.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TearDown;
begin
  Interp.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.PlayScript(const Script : String; MaxSteps : Integer);
var
  Cnt : Integer;
begin
  Interp.ScrList.Scr.Text := Script;
  Interp.NextLine := 0;
  Cnt := 0;
  while (Interp.ResInt <> RES_STOP) and (Interp.ResInt <> RES_CLOSE) and (Cnt < MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestSetLiteral;
begin
  PlayScript('SET %x hello' + #13#10 + 'HALT');
  AssertEquals('hello', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestSetArithmeticShorthand;
begin
  // SET %x <n> - / SET %x <n> + is a decrement/increment shorthand, distinct from
  // ordinary expression evaluation -- preserved exactly.
  PlayScript('SET %x 5 -' + #13#10 + 'HALT');
  AssertEquals('4', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestBooleanEncodingIsMinusOneAndZero;
begin
  PlayScript(
    'SET %t ( 1 = 1 )' + #13#10 +
    'SET %f ( 1 = 2 )' + #13#10 +
    'HALT');
  AssertEquals('-1', Interp.GetVar('%t'));
  AssertEquals('0', Interp.GetVar('%f'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestCommaTokenMergeAndDiscard;
begin
  // "100" "," "100" -> "100100", the comma token itself vanishes -- this runs
  // strictly after variable substitution in ParseLine. The comma must be its own
  // whitespace-separated token for the merge rule to see it (Parameterize splits
  // on whitespace only, so "100,100" with no spaces is already one token).
  PlayScript('SET %x 100 , 100' + #13#10 + 'HALT');
  AssertEquals('100100', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestUnrecognizedCommandIsSilentNoOp;
begin
  PlayScript(
    'SET %x before' + #13#10 +
    'ThisIsNotARealCommand foo bar' + #13#10 +
    'SET %y after' + #13#10 +
    'HALT');
  AssertEquals('before', Interp.GetVar('%x'));
  AssertEquals('after', Interp.GetVar('%y'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestVersionVarsAreDistinct;
begin
  // #EUOVer stays pinned to the original EasyUO value for script compatibility;
  // #ReforgedVer is this port's own build version (YY.MM.DD.<git commit>), from
  // the single source common\ReforgedVersion.pas.
  PlayScript(
    'SET %e #EUOVer' + #13#10 +
    'SET %r #ReforgedVer' + #13#10 +
    'HALT');
  AssertEquals('1_50_00', Interp.GetVar('%e'));
  AssertEquals(REFORGED_VERSION, Interp.GetVar('%r'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestDiagnosticsReportBuildsAsMultilineBlock;
var
  Report : String;
begin
  // The bug-report diagnostics script (docs\report-diagnostics.euo) builds a
  // '$'-separated block for a MENU MEMO -- one "Key: value" per line, still a
  // single script variable, ready for MemoCreate's '$'->newline substitution.
  PlayScript(
    'set %r ReforgedVer: , #SPC , #ReforgedVer' + #13#10 +
    'set %r %r , $ , Client_version: , #SPC , #CliVer' + #13#10 +
    'set %r %r , $ , Character: , #SPC , #CharName' + #13#10 +
    'HALT');
  Report := Interp.GetVar('%r');
  AssertEquals('ReforgedVer: ' + REFORGED_VERSION, Copy(Report, 1, Pos('$', Report) - 1));
  AssertTrue('fields are $-separated', Pos('$Client_version: ', Report) > 0);
  AssertTrue('fields are $-separated', Pos('$Character: ', Report) > 0);
  AssertEquals(0, Pos(#13, Report) + Pos(#10, Report));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestMenuMemoRoundTripsThroughGet;
begin
  // MENU MEMO is an EasyUO Reforged extension: a multi-line MENU EDIT. Its text
  // takes '$' as a line break; MENU GET reads it back with the breaks folded to
  // '$' again, so #menuRes stays a single line. (MENU SHOW isn't exercised --
  // the headless test host can't register the window class for a visible form.)
  PlayScript(
    'menu Clear' + #13#10 +
    'menu Memo m 0 0 200 120 alpha$beta$gamma' + #13#10 +
    'menu Get m' + #13#10 +
    'HALT');
  AssertEquals('alpha$beta$gamma', Copy(Interp.GetVar('#menuRes'), 1, 16));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestClientGatedCommandIsSilentNoOpWithNoClient;
begin
  // FINDITEM is Cmd2 (RequiresClient); with the test stub's TUOSel.Nr always 0,
  // this must be a silent no-op indistinguishable from an unrecognized word.
  PlayScript(
    'FINDITEM XXXX' + #13#10 +
    'SET %x reached' + #13#10 +
    'HALT');
  AssertEquals('reached', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestIfTrueRunsBodyAndSkipsElse;
begin
  PlayScript(
    'IF ( 1 = 1 )' + #13#10 +
    'SET %x true' + #13#10 +
    'ELSE' + #13#10 +
    'SET %x false' + #13#10 +
    'HALT');
  AssertEquals('true', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestIfFalseSkipsBodyAndRunsElse;
begin
  PlayScript(
    'IF ( 1 = 2 )' + #13#10 +
    'SET %x true' + #13#10 +
    'ELSE' + #13#10 +
    'SET %x false' + #13#10 +
    'HALT');
  AssertEquals('false', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestIfBlockBraces;
begin
  PlayScript(
    'IF ( 1 = 2 )' + #13#10 +
    '{' + #13#10 +
    'SET %x 1' + #13#10 +
    'SET %y 1' + #13#10 +
    '}' + #13#10 +
    'ELSE' + #13#10 +
    '{' + #13#10 +
    'SET %x 2' + #13#10 +
    'SET %y 2' + #13#10 +
    '}' + #13#10 +
    'HALT');
  AssertEquals('2', Interp.GetVar('%x'));
  AssertEquals('2', Interp.GetVar('%y'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestForLoopCountsUp;
begin
  PlayScript(
    'FOR %i 1 3' + #13#10 +
    'SET %last %i' + #13#10 +
    'NEXT' + #13#10 +
    'HALT');
  AssertEquals('3', Interp.GetVar('%last'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestForLoopCountsDown;
begin
  PlayScript(
    'FOR %i 3 1' + #13#10 +
    'SET %last %i' + #13#10 +
    'NEXT' + #13#10 +
    'HALT');
  AssertEquals('1', Interp.GetVar('%last'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestWhileUntilLoop;
begin
  PlayScript(
    'SET %i 0' + #13#10 +
    'REPEAT' + #13#10 +
    'SET %i %i +' + #13#10 +
    'UNTIL ( %i = 3 )' + #13#10 +
    'HALT');
  AssertEquals('3', Interp.GetVar('%i'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestGotoForward;
begin
  PlayScript(
    'GOTO skip:' + #13#10 +
    'SET %x wrong' + #13#10 +
    'skip:' + #13#10 +
    'SET %x right' + #13#10 +
    'HALT');
  AssertEquals('right', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestGotoBackward;
begin
  PlayScript(
    'SET %n 0' + #13#10 +
    'top:' + #13#10 +
    'SET %n %n +' + #13#10 +
    'IF ( %n < 3 )' + #13#10 +
    'GOTO top:' + #13#10 +
    'HALT');
  AssertEquals('3', Interp.GetVar('%n'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestGoSubReturnWithArgs;
begin
  PlayScript(
    'GOSUB double 21' + #13#10 +
    'HALT' + #13#10 +
    'SUB double' + #13#10 +
    'SET %x %1' + #13#10 +
    'RETURN ( %1 * 2 )' + #13#10 +
    'RETURN');
  AssertEquals('21', Interp.GetVar('%x'));
  AssertEquals('42', Interp.GetVar('#Result'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestGoSubDuplicateNameResolvesToLastMatch;
begin
  // GOSUB's backward-from-end scan means the LAST "SUB dup" in the file wins.
  PlayScript(
    'GOSUB dup' + #13#10 +
    'HALT' + #13#10 +
    'SUB dup' + #13#10 +
    'SET %which first' + #13#10 +
    'RETURN' + #13#10 +
    'SUB dup' + #13#10 +
    'SET %which second' + #13#10 +
    'RETURN');
  AssertEquals('second', Interp.GetVar('%which'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestReturnWithNoActiveGoSubIsATrueNoOp;
begin
  // #Result starts at 'N/A'; a bare RETURN with no active GOSUB must not touch it.
  PlayScript('RETURN' + #13#10 + 'HALT');
  AssertEquals('N/A', Interp.GetVar('#Result'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestExitAtOutermostFrameRestartsFromLineZero;
begin
  // EXIT at the base call frame restarts the script from line 0 rather than
  // stopping it -- cap steps low and confirm %n keeps climbing past one full pass.
  // %n is pre-seeded directly (not via a line in the script) so that replaying
  // line 0 on each restart doesn't also reset the counter it's meant to prove
  // survives the restart.
  Interp.SetVar('%n', '0');
  PlayScript(
    'SET %n %n +' + #13#10 +
    'IF ( %n = 5 )' + #13#10 +
    'HALT' + #13#10 +
    'EXIT',
    50);
  AssertEquals('5', Interp.GetVar('%n'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestImplicitEofIsImplicitExit;
begin
  // Running off the end of the script with no explicit EXIT/HALT is itself an
  // implicit EXIT (restart from 0), not a stop -- same restart signature as above,
  // this time triggered by falling off the end rather than a literal EXIT line.
  Interp.SetVar('%n', '0');
  PlayScript(
    'SET %n %n +' + #13#10 +
    'IF ( %n = 3 )' + #13#10 +
    'HALT',
    50);
  AssertEquals('3', Interp.GetVar('%n'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestHaltActuallyStops;
begin
  PlayScript(
    'SET %x before' + #13#10 +
    'HALT' + #13#10 +
    'SET %x after',
    10);
  AssertEquals('before', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrCommandLenUpperLowerLeftRightMid;
begin
  PlayScript(
    'STR LEN Hello' + #13#10 + 'SET %len #StrRes' + #13#10 +
    'STR UPPER Hello' + #13#10 + 'SET %up #StrRes' + #13#10 +
    'STR LOWER Hello' + #13#10 + 'SET %low #StrRes' + #13#10 +
    'STR LEFT Hello 3' + #13#10 + 'SET %left #StrRes' + #13#10 +
    'STR RIGHT Hello 3' + #13#10 + 'SET %right #StrRes' + #13#10 +
    'STR MID Hello 2 3' + #13#10 + 'SET %mid #StrRes' + #13#10 +
    'HALT');
  AssertEquals('5', Interp.GetVar('%len'));
  AssertEquals('HELLO', Interp.GetVar('%up'));
  AssertEquals('hello', Interp.GetVar('%low'));
  AssertEquals('Hel', Interp.GetVar('%left'));
  AssertEquals('llo', Interp.GetVar('%right'));
  AssertEquals('ell', Interp.GetVar('%mid'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestDeleteVarRemovesUserVariable;
begin
  PlayScript(
    'SET %x gone' + #13#10 +
    'DELETEVAR x' + #13#10 +
    'HALT');
  AssertEquals('N/A', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestNameSpaceLocalIsolatesFromDefaultStd;
begin
  PlayScript(
    'SET !v std' + #13#10 +
    'NAMESPACE LOCAL other' + #13#10 +
    'SET !v other' + #13#10 +
    'NAMESPACE LOCAL std' + #13#10 +
    'SET %backToStd !v' + #13#10 +
    'HALT');
  AssertEquals('std', Interp.GetVar('%backToStd'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestNameSpaceGlobalSingletonIsSharedAcrossInterpreterInstances;
var
  Second : TEuoInterpreter;
begin
  // The single most important behavior in EuoVariables.pas: NAMESPACE GLOBAL
  // storage is one process-wide singleton, not per-interpreter-instance. A write
  // from one interpreter must be immediately visible from a second, independent
  // instance with no wiring in this test itself.
  Second := TEuoInterpreter.Create(0);
  try
    Second.Clear;
    PlayScript(
      'NAMESPACE GLOBAL shared' + #13#10 +
      'SET !v fromFirst' + #13#10 +
      'HALT');

    Second.ScrList.Scr.Text :=
      'NAMESPACE GLOBAL shared' + #13#10 +
      'SET %seen !v' + #13#10 +
      'HALT';
    Second.NextLine := 0;
    while (Second.ResInt <> RES_STOP) and (Second.ResInt <> RES_CLOSE) do
      Second.PlayLine;

    AssertEquals('fromFirst', Second.GetVar('%seen'));
  finally
    Second.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoInterpreterTests);
end.
