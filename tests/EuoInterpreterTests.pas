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
    procedure TestMenuNamesAreCaseInsensitive;
    procedure TestMenuFontLinesAreHarmlessAndLeaveStateAlone;
    procedure TestClientGatedCommandIsSilentNoOpWithNoClient;
    procedure TestScanBuffsIsASilentNoOpWithNoClient;
    procedure TestBuffVariablesReadNAWithNoClient;
    procedure TestBuffAdditionsLeaveTheOriginalVariablesAlone;
    procedure TestPathVariablesBeforeAnyPathCommand;
    procedure TestPathFindNeedsAClient;
    procedure TestPathRulesWorkWithoutAClient;
    procedure TestPathBadArgumentsLandInPathState;

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
procedure TEuoInterpreterTests.TestMenuNamesAreCaseInsensitive;
begin
  // TMenuObj keeps its controls in an ordinal, case-sensitive list and upper-cases
  // every name on the way in and on lookup; a script must still be able to create a
  // control as "MyEd" and address it as "myed"/"MYED".
  PlayScript(
    'menu Clear' + #13#10 +
    'menu Edit MyEd 0 0 100 first' + #13#10 +
    'menu Get myed' + #13#10 +
    'set %a #menuRes' + #13#10 +
    'menu Set MYED second' + #13#10 +
    'menu Get MyEd' + #13#10 +
    'set %b #menuRes' + #13#10 +
    'menu Get nosuchname' + #13#10 +
    'set %c #menuRes' + #13#10 +
    'HALT');
  AssertEquals('first', Interp.GetVar('%a'));
  AssertEquals('second', Interp.GetVar('%b'));
  AssertEquals('N/A', Interp.GetVar('%c'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestMenuFontLinesAreHarmlessAndLeaveStateAlone;
begin
  // MENU FONT * is handled inline on the script thread (no GUI hop). It only sets
  // defaults for later creates, so it must not disturb a previously read
  // #menuRes, must stay a silent no-op on bad arguments, and a control created
  // afterwards must still work normally.
  PlayScript(
    'menu Clear' + #13#10 +
    'menu Edit e 0 0 100 keep' + #13#10 +
    'menu Get e' + #13#10 +
    'menu Font Name Courier New' + #13#10 +
    'menu Font Size 14' + #13#10 +
    'menu Font Style BI' + #13#10 +
    'menu Font Color Red' + #13#10 +
    'menu Font BGColor Yellow' + #13#10 +
    'menu Font Align Center' + #13#10 +
    'menu Font Transparent 1' + #13#10 +
    'menu Font' + #13#10 +                  // too few parameters
    'menu Font Size notanumber' + #13#10 +  // invalid -> ignored
    'menu Font Color notacolor' + #13#10 +  // invalid -> ignored
    'set %a #menuRes' + #13#10 +
    'menu Edit e2 0 30 100 later' + #13#10 +
    'menu Get e2' + #13#10 +
    'set %b #menuRes' + #13#10 +
    'HALT');
  AssertEquals('keep', Interp.GetVar('%a'));
  AssertEquals('later', Interp.GetVar('%b'));
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
// ScanBuffs is a port addition: client-gated like FINDITEM, so with no client it is a silent
// no-op -- with or without the optional icon id.
procedure TEuoInterpreterTests.TestScanBuffsIsASilentNoOpWithNoClient;
begin
  PlayScript(
    'SCANBUFFS' + #13#10 +
    'ScanBuffs 7542' + #13#10 +
    'SET %x reached' + #13#10 +
    'HALT');
  AssertEquals('reached', Interp.GetVar('%x'));
end;

////////////////////////////////////////////////////////////////////////////////
// All eight buff variables read N/A without a client, like every other client-dependent #variable.
procedure TEuoInterpreterTests.TestBuffVariablesReadNAWithNoClient;
var
  Names : array[0..7] of String;
  Cnt   : Integer;
begin
  Names[0] := '#BuffCnt';
  Names[1] := '#BuffIndex';
  Names[2] := '#BuffID';
  Names[3] := '#BuffCliloc';
  Names[4] := '#BuffName';
  Names[5] := '#BuffDesc';
  Names[6] := '#BuffTime';
  Names[7] := '#BuffBarOpen';
  for Cnt := 0 to High(Names) do
    AssertEquals(Names[Cnt], 'N/A', Interp.GetVar(Names[Cnt]));
  // #BuffIndex is settable like #FindIndex; without a client the write is simply harmless
  PlayScript(
    'SET #BuffIndex 2' + #13#10 +
    'SET %x done' + #13#10 +
    'HALT');
  AssertEquals('done', Interp.GetVar('%x'));
  AssertEquals('N/A', Interp.GetVar('#BuffName'));
end;

////////////////////////////////////////////////////////////////////////////////
// The additions are appended after every original name, so the original variables keep
// their meaning (and their numbers in the interpreter's dispatch).
procedure TEuoInterpreterTests.TestBuffAdditionsLeaveTheOriginalVariablesAlone;
begin
  AssertEquals('1_50_00', Interp.GetVar('#EUOVer'));
  AssertEquals(REFORGED_VERSION, Interp.GetVar('#ReforgedVer'));
  AssertEquals('-1', Interp.GetVar('#True'));
  AssertEquals('0', Interp.GetVar('#False'));
  AssertEquals(' ', Interp.GetVar('#SPC'));
  AssertEquals('N/A', Interp.GetVar('#NoSuchVariable'));
end;

////////////////////////////////////////////////////////////////////////////////
// PATH is a port addition (the pathfinder; the planner itself is tested in PathPlanTests).
procedure TEuoInterpreterTests.TestPathVariablesBeforeAnyPathCommand;
begin
  AssertEquals('N/A', Interp.GetVar('#PathState'));
  AssertEquals('0', Interp.GetVar('#PathCnt'));
  AssertEquals('0', Interp.GetVar('#PathX'));
  AssertEquals('-1', Interp.GetVar('#PathDir'));
end;

// Registered without RequiresClient, so FIND runs and says why it can't plan: no character to
// start from, or, with PATH FROM, no client folder to read the map from.
procedure TEuoInterpreterTests.TestPathFindNeedsAClient;
begin
  PlayScript(
    'path find 1434 1699' + #13#10 +
    'set %a #PathState' + #13#10 +
    'set %n #PathCnt' + #13#10 +
    'path from 1434 1699 0' + #13#10 +
    'set %b #PathState' + #13#10 +
    'path find 1440 1699' + #13#10 +
    'set %c #PathState' + #13#10 +
    'HALT');
  AssertEquals('noclient', Interp.GetVar('%a'));
  AssertEquals('0', Interp.GetVar('%n'));
  AssertEquals('ok', Interp.GetVar('%b'));
  AssertEquals('nomap', Interp.GetVar('%c'));
end;

procedure TEuoInterpreterTests.TestPathRulesWorkWithoutAClient;
begin
  PlayScript(
    'path set accuracy 2' + #13#10 + 'set %a #PathState' + #13#10 +
    'path set timeout 3s' + #13#10 + 'set %b #PathState' + #13#10 +
    'path block 10 10' + #13#10 + 'set %c #PathState' + #13#10 +
    'path block 10 10 20 20 1' + #13#10 + 'set %d #PathState' + #13#10 +
    'path unblock 15 15' + #13#10 + 'set %e #PathState' + #13#10 +
    'path avoid 1 2 3 4 500' + #13#10 + 'set %f #PathState' + #13#10 +
    'path link 1 2 0 3 4 0' + #13#10 + 'set %g #PathState' + #13#10 +
    'path clear links' + #13#10 + 'set %h #PathState' + #13#10 +
    'path set difs on' + #13#10 + 'set %i #PathState' + #13#10 +
    'HALT');
  AssertEquals('ok', Interp.GetVar('%a'));
  AssertEquals('ok', Interp.GetVar('%b'));
  AssertEquals('ok', Interp.GetVar('%c'));
  AssertEquals('ok', Interp.GetVar('%d'));
  AssertEquals('ok', Interp.GetVar('%e'));
  AssertEquals('ok', Interp.GetVar('%f'));
  AssertEquals('ok', Interp.GetVar('%g'));
  AssertEquals('ok', Interp.GetVar('%h'));
  AssertEquals('ok', Interp.GetVar('%i'));
end;

procedure TEuoInterpreterTests.TestPathBadArgumentsLandInPathState;
begin
  PlayScript(
    'path set bogus 1' + #13#10 + 'set %a #PathState' + #13#10 +
    'path set accuracy -1' + #13#10 + 'set %b #PathState' + #13#10 +
    'path link 1 2 3' + #13#10 + 'set %c #PathState' + #13#10 +
    'path get 1' + #13#10 + 'set %d #PathState' + #13#10 +
    'path frobnicate' + #13#10 + 'set %e #PathState' + #13#10 +
    'path find abc 10' + #13#10 + 'set %f #PathState' + #13#10 +
    'set %x reached' + #13#10 +
    'HALT');
  AssertEquals('error: unknown path option: bogus', Interp.GetVar('%a'));
  AssertTrue(Pos('error:', Interp.GetVar('%b')) = 1);
  AssertTrue(Pos('error:', Interp.GetVar('%c')) = 1);
  AssertEquals('error: no step 1 (1..0)', Interp.GetVar('%d'));
  AssertEquals('error: unknown path command: frobnicate', Interp.GetVar('%e'));
  AssertTrue(Pos('error:', Interp.GetVar('%f')) = 1);
  AssertEquals('the script goes on', 'reached', Interp.GetVar('%x'));
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
