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
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter, EuoJournalSearch, ReforgedVersion;

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
    procedure TestPathWalkingNeedsAClient;
    procedure TestPathWalkerOptions;
    procedure TestPathCheckNeedsAClient;
    procedure TestMountVariablesReadNAWithNoClient;
    procedure TestAlwaysRunExampleRunsWithoutAClient;

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
    procedure TestStrOriginalOperationsUnchanged;
    procedure TestStrReplace;
    procedure TestStrReplaceWithNothing;
    procedure TestStrReplaceMissingParametersAndGlue;
    procedure TestStrPart;
    procedure TestStrPartEmptyFields;
    procedure TestStrPartNoSuchField;
    procedure TestStrPartAgreesWithCount;
    procedure TestStrPartOnPropertyAndJournalText;
    procedure TestStrPartReplacesHandWrittenSubs;
    procedure TestStrTrim;
    procedure TestStrJoin;
    procedure TestStrConcat;
    procedure TestDeleteVarRemovesUserVariable;

    procedure TestNameSpaceLocalIsolatesFromDefaultStd;
    procedure TestNameSpaceGlobalSingletonIsSharedAcrossInterpreterInstances;

    procedure TestWaitForAlreadyTrueReturnsAtOnce;
    procedure TestWaitForTimesOutInTicks;
    procedure TestWaitForTimesOutInSeconds;
    procedure TestWaitForDefaultAndUnreadableTimeoutAreTwoSeconds;
    procedure TestWaitForTimeoutZeroChecksOnce;
    procedure TestWaitForTimeoutFromAVariable;
    procedure TestWaitForReadsTheConditionAgainWhileWaiting;
    procedure TestWaitForAgreesWithIf;
    procedure TestWaitForAndBindsTighterThanOr;
    procedure TestWaitForNestedConditionWaitsAndTimesOut;
    procedure TestWaitForNestedConditionOverContinuationLines;
    procedure TestWaitForContinuationGoesOnAfterItsLastLine;
    procedure TestWaitForLeavesResultAlone;
    procedure TestWaitForBareWordIsANoOp;
    procedure TestWaitResReadsNAUntilAWaitForAndAfterClear;
    procedure TestWaitForAsAnIfBody;
    procedure TestWaitForInLoopsKeepsTheLoopGoing;
    procedure TestSubAndLabelNamedWaitForStillWork;
    procedure TestFindJournalWithNoClientIsANoOp;
    procedure TestJFoundReadsNAAfterClear;
    procedure TestSubAndLabelNamedFindJournalStillWork;
    procedure TestBareStarReachesACommandAsAWord;
    procedure TestFindJournalMatchAgreesWithIn;
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
// #MountID, #MountType and #FindLayer are port additions appended after #PathDir: known names (the
// editor's tree and FindItem read them), N/A without a client, and the variables before them keep
// their meaning. Reading them with a client is tested in CstDbModernBuildTests.
procedure TEuoInterpreterTests.TestMountVariablesReadNAWithNoClient;
begin
  AssertEquals('N/A', Interp.GetVar('#MountID'));
  AssertEquals('N/A', Interp.GetVar('#MountType'));
  AssertEquals('N/A', Interp.GetVar('#FindLayer'));
  AssertEquals('-1', Interp.GetVar('#PathDir'));
  AssertEquals('0', Interp.GetVar('#PathCnt'));
  AssertEquals('-1', Interp.GetVar('#True'));
  PlayScript(
    'set %a #MountID' + #13#10 +
    'set %b #FindLayer' + #13#10 +
    'HALT');
  AssertEquals('N/A', Interp.GetVar('%a'));
  AssertEquals('N/A', Interp.GetVar('%b'));
end;

////////////////////////////////////////////////////////////////////////////////
// The Always Run example on the path command's docs page (commands/path/index.md, "Running"), as
// printed there. Without a client the toggle gets no answer: after its second of tries, nothing is
// switched, the walk says noclient, and the script reaches its halt.
procedure TEuoInterpreterTests.TestAlwaysRunExampleRunsWithoutAClient;
begin
  PlayScript(
    'gosub ToggleAlwaysRun' + #13#10 +
    'set %switched #false' + #13#10 +
    'if %run = on' + #13#10 +
    '  set %switched #true        ; it was off: switch it back off after the walk' + #13#10 +
    'if %run = off' + #13#10 +
    '  gosub ToggleAlwaysRun      ; it was on already: switch it back on, and leave it on' + #13#10 +
    'path go 2505 552' + #13#10 +
    'if %switched = #true' + #13#10 +
    '{' + #13#10 +
    '  gosub ToggleAlwaysRun' + #13#10 +
    '  if %run = on' + #13#10 +
    '    gosub ToggleAlwaysRun    ; it had been switched off meanwhile: off again' + #13#10 +
    '}' + #13#10 +
    'set %done yes' + #13#10 +
    'halt' + #13#10 +
    '' + #13#10 +
    'sub ToggleAlwaysRun' + #13#10 +
    '  set %next #JIndex + 1' + #13#10 +
    '  set %run none' + #13#10 +
    '  set %tries 0' + #13#10 +
    '  event macro 32 0' + #13#10 +
    '  repeat' + #13#10 +
    '    wait 1' + #13#10 +
    '    set %tries %tries + 1' + #13#10 +
    '    while %next <= #JIndex' + #13#10 +
    '    {' + #13#10 +
    '      scanjournal %next' + #13#10 +
    '      if Always_Run_is_now_on in #Journal' + #13#10 +
    '        set %run on' + #13#10 +
    '      if Always_Run_is_now_off in #Journal' + #13#10 +
    '        set %run off' + #13#10 +
    '      set %next %next + 1' + #13#10 +
    '    }' + #13#10 +
    '  until %run <> none || %tries >= 20' + #13#10 +
    'return', 2000);
  AssertEquals('reached the halt', 'yes', Interp.GetVar('%done'));
  AssertEquals('no answer without a client', 'none', Interp.GetVar('%run'));
  AssertEquals('a second of tries', '20', Interp.GetVar('%tries'));
  AssertEquals('nothing to put back', '0', Interp.GetVar('%switched'));
  AssertEquals('noclient', Interp.GetVar('#PathState'));
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

// GO, WALK and STEP say why they can't walk and never stop the script; STOP always answers stopped.
procedure TEuoInterpreterTests.TestPathWalkingNeedsAClient;
begin
  PlayScript(
    'path go 1434 1699' + #13#10 + 'set %a #PathState' + #13#10 +
    'path walk' + #13#10 + 'set %b #PathState' + #13#10 +
    'path step' + #13#10 + 'set %c #PathState' + #13#10 +
    'path stop' + #13#10 + 'set %d #PathState' + #13#10 +
    'path go abc 10' + #13#10 + 'set %e #PathState' + #13#10 +
    'path go 10 10 0 -1' + #13#10 + 'set %f #PathState' + #13#10 +
    'set %x reached' + #13#10 +
    'HALT');
  AssertEquals('noclient', Interp.GetVar('%a'));
  AssertEquals('noclient', Interp.GetVar('%b'));
  AssertEquals('noclient', Interp.GetVar('%c'));
  AssertEquals('stopped', Interp.GetVar('%d'));
  AssertEquals('error: path go {x} {y} [z] [accuracy] [timeout]', Interp.GetVar('%e'));
  AssertEquals('error: path go {x} {y} [z] [accuracy] [timeout]', Interp.GetVar('%f'));
  AssertEquals('reached', Interp.GetVar('%x'));
end;

procedure TEuoInterpreterTests.TestPathWalkerOptions;
begin
  PlayScript(
    'path set mode steps' + #13#10 + 'set %a #PathState' + #13#10 +
    'path set mode client' + #13#10 + 'set %b #PathState' + #13#10 +
    'path set mode auto' + #13#10 + 'set %c #PathState' + #13#10 +
    'path set mode fly' + #13#10 + 'set %d #PathState' + #13#10 +
    'path set mobiles ignore' + #13#10 + 'set %e #PathState' + #13#10 +
    'path set mobiles maybe' + #13#10 + 'set %f #PathState' + #13#10 +
    'path set doors off' + #13#10 + 'set %g #PathState' + #13#10 +
    'path set doors all' + #13#10 + 'set %p #PathState' + #13#10 +
    'path set doors maybe' + #13#10 + 'set %q #PathState' + #13#10 +
    'path set doorcost 80' + #13#10 + 'set %h #PathState' + #13#10 +
    'path set lead 12' + #13#10 + 'set %i #PathState' + #13#10 +
    'path set lead 0' + #13#10 + 'set %j #PathState' + #13#10 +
    'path set blocktime 30s' + #13#10 + 'set %k #PathState' + #13#10 +
    'path clear learned' + #13#10 + 'set %l #PathState' + #13#10 +
    'path set log walk.log' + #13#10 + 'set %m #PathState' + #13#10 +
    'path set log off' + #13#10 + 'set %n #PathState' + #13#10 +
    'path set log' + #13#10 + 'set %o #PathState' + #13#10 +
    'path set check 8' + #13#10 + 'set %r #PathState' + #13#10 +
    'path set check 0' + #13#10 + 'set %s #PathState' + #13#10 +
    'path set check -1' + #13#10 + 'set %t #PathState' + #13#10 +
    'HALT');
  AssertEquals('ok', Interp.GetVar('%a'));
  AssertEquals('ok', Interp.GetVar('%b'));
  AssertEquals('ok', Interp.GetVar('%c'));
  AssertEquals('error: path set mode auto|client|steps', Interp.GetVar('%d'));
  AssertEquals('ok', Interp.GetVar('%e'));
  AssertEquals('error: path set mobiles block|ignore', Interp.GetVar('%f'));
  AssertEquals('ok', Interp.GetVar('%g'));
  AssertEquals('ok', Interp.GetVar('%p'));
  AssertEquals('error: path set doors on|off|all', Interp.GetVar('%q'));
  AssertEquals('ok', Interp.GetVar('%h'));
  AssertEquals('ok', Interp.GetVar('%i'));
  AssertEquals('error: path set lead needs a number of 1 or more', Interp.GetVar('%j'));
  AssertEquals('ok', Interp.GetVar('%k'));
  AssertEquals('ok', Interp.GetVar('%l'));
  AssertEquals('ok', Interp.GetVar('%m'));
  AssertEquals('ok', Interp.GetVar('%n'));
  AssertEquals('error: path set log {file}|off', Interp.GetVar('%o'));
  AssertEquals('ok', Interp.GetVar('%r'));
  AssertEquals('ok', Interp.GetVar('%s'));
  AssertEquals('error: path set check needs a number of 0 or more', Interp.GetVar('%t'));
end;

// PATH CHECK asks the client itself: without one it says noclient, once its arguments are right.
procedure TEuoInterpreterTests.TestPathCheckNeedsAClient;
begin
  PlayScript(
    'path check 10 10' + #13#10 + 'set %a #PathState' + #13#10 +
    'path check 10 10 5 3' + #13#10 + 'set %b #PathState' + #13#10 +
    'path check 1' + #13#10 + 'set %c #PathState' + #13#10 +
    'path check' + #13#10 + 'set %d #PathState' + #13#10 +
    'path check 10 10 5 8' + #13#10 + 'set %e #PathState' + #13#10 +
    'path check 10 x' + #13#10 + 'set %f #PathState' + #13#10 +
    'path check 10 10 5 3 9' + #13#10 + 'set %g #PathState' + #13#10 +
    'set %h #PathCnt' + #13#10 +
    'HALT');
  AssertEquals('noclient', Interp.GetVar('%a'));
  AssertEquals('noclient', Interp.GetVar('%b'));
  AssertEquals('no plan: no step 1', 'error: no step 1 (1..0)', Interp.GetVar('%c'));
  AssertEquals('error: path check {n} | {x} {y} [z] [dir]', Interp.GetVar('%d'));
  AssertEquals('error: path check {n} | {x} {y} [z] [dir]', Interp.GetVar('%e'));
  AssertEquals('error: path check {n} | {x} {y} [z] [dir]', Interp.GetVar('%f'));
  AssertEquals('error: path check {n} | {x} {y} [z] [dir]', Interp.GetVar('%g'));
  AssertEquals('#PathCnt left alone', '0', Interp.GetVar('%h'));
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
// The operations from before REPLACE/PART/TRIM/JOIN/CONCAT sit in the same procedure,
// so their results and quirks are pinned here.
procedure TEuoInterpreterTests.TestStrOriginalOperationsUnchanged;
begin
  PlayScript(
    'STR POS Hello LL' + #13#10 + 'SET %pos #StrRes' + #13#10 +
    'STR POS Hello ll' + #13#10 + 'SET %posCase #StrRes' + #13#10 +
    'STR POS Hello z' + #13#10 + 'SET %posNone #StrRes' + #13#10 +
    'STR POS _a_b_ _ 3' + #13#10 + 'SET %posN #StrRes' + #13#10 +
    'STR COUNT _a_b_ _' + #13#10 + 'SET %count #StrRes' + #13#10 +
    'STR COUNT Hello z' + #13#10 + 'SET %countNone #StrRes' + #13#10 +
    'STR COUNT aaa aa' + #13#10 + 'SET %countOverlap #StrRes' + #13#10 +
    'STR INS Hello I 3' + #13#10 + 'SET %ins #StrRes' + #13#10 +
    'STR DEL Hello 3 2' + #13#10 + 'SET %del #StrRes' + #13#10 +
    'STR' + #13#10 + 'SET %noOp #StrRes' + #13#10 +
    'STR LEN' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'STR LEFT Hello' + #13#10 + 'SET %noCount #StrRes' + #13#10 +
    'STR FOO a b c d' + #13#10 + 'SET %unknown #StrRes' + #13#10 +
    'HALT');
  AssertEquals('3', Interp.GetVar('%pos'));
  AssertEquals('3', Interp.GetVar('%posCase'));
  AssertEquals('0', Interp.GetVar('%posNone'));
  AssertEquals('5', Interp.GetVar('%posN'));
  AssertEquals('3', Interp.GetVar('%count'));
  AssertEquals('0', Interp.GetVar('%countNone'));
  AssertEquals('1', Interp.GetVar('%countOverlap'));
  AssertEquals('HeIllo', Interp.GetVar('%ins'));
  AssertEquals('Heo', Interp.GetVar('%del'));
  // STR with no words at all exits before its operation is read, and leaves #StrRes reset.
  AssertEquals('N/A', Interp.GetVar('%noOp'));
  AssertEquals('N/A', Interp.GetVar('%noText'));
  AssertEquals('N/A', Interp.GetVar('%noCount'));
  AssertEquals('N/A', Interp.GetVar('%unknown'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrReplace;
begin
  PlayScript(
    'STR REPLACE a_b_c _ - ' + #13#10 + 'SET %all #StrRes' + #13#10 +
    'STR REPLACE Hello_WORLD_hello HELLO Bye' + #13#10 + 'SET %case #StrRes' + #13#10 +
    'STR REPLACE abc X Y' + #13#10 + 'SET %absent #StrRes' + #13#10 +
    'STR REPLACE a_b _ __' + #13#10 + 'SET %grow #StrRes' + #13#10 +
    'STR REPLACE aaa aa x' + #13#10 + 'SET %overlap #StrRes' + #13#10 +
    'STR REPLACE abab ab abab' + #13#10 + 'SET %contains #StrRes' + #13#10 +
    'STR REPLACE _a_b_ _ -' + #13#10 + 'SET %ends #StrRes' + #13#10 +
    'STR REPLACE a b c d' + #13#10 + 'SET %extra #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR REPLACE Hello %empty x' + #13#10 + 'SET %emptySearch #StrRes' + #13#10 +
    'STR REPLACE %empty a x' + #13#10 + 'SET %emptyText #StrRes' + #13#10 +
    'STR REPLACE a_b _ #SPC' + #13#10 + 'SET %toSpace #StrRes' + #13#10 +
    'STR REPLACE %toSpace #SPC _' + #13#10 + 'SET %fromSpace #StrRes' + #13#10 +
    'STR REPLACE a.b #DOT _' + #13#10 + 'SET %dot #StrRes' + #13#10 +
    'STR REPLACE a;b #SMC _' + #13#10 + 'SET %smc #StrRes' + #13#10 +
    'HALT');
  AssertEquals('a-b-c', Interp.GetVar('%all'));
  AssertEquals('Bye_WORLD_Bye', Interp.GetVar('%case'));
  AssertEquals('abc', Interp.GetVar('%absent'));
  AssertEquals('a__b', Interp.GetVar('%grow'));
  AssertEquals('xa', Interp.GetVar('%overlap'));
  AssertEquals('abababab', Interp.GetVar('%contains'));
  AssertEquals('-a-b-', Interp.GetVar('%ends'));
  AssertEquals('a', Interp.GetVar('%extra'));
  AssertEquals('Hello', Interp.GetVar('%emptySearch'));
  AssertEquals('', Interp.GetVar('%emptyText'));
  AssertEquals('a b', Interp.GetVar('%toSpace'));
  AssertEquals('a_b', Interp.GetVar('%fromSpace'));
  AssertEquals('a_b', Interp.GetVar('%dot'));
  AssertEquals('a_b', Interp.GetVar('%smc'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrReplaceWithNothing;
begin
  PlayScript(
    'STR REPLACE a_b_c _' + #13#10 + 'SET %missing #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR REPLACE a_b_c _ %empty' + #13#10 + 'SET %emptyVar #StrRes' + #13#10 +
    'STR REPLACE ___ _' + #13#10 + 'SET %nothingLeft #StrRes' + #13#10 +
    'HALT');
  AssertEquals('abc', Interp.GetVar('%missing'));
  AssertEquals('abc', Interp.GetVar('%emptyVar'));
  AssertEquals('', Interp.GetVar('%nothingLeft'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrReplaceMissingParametersAndGlue;
begin
  PlayScript(
    'STR REPLACE' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'STR REPLACE abc' + #13#10 + 'SET %noSearch #StrRes' + #13#10 +
    'SET %comma ,' + #13#10 +
    'SET %s a,b' + #13#10 +
    // A lone comma is glued away unless it's the last word: as the last word it's a search...
    'STR REPLACE %s ,' + #13#10 + 'SET %commaLast #StrRes' + #13#10 +
    'STR REPLACE %s %comma' + #13#10 + 'SET %commaVarLast #StrRes' + #13#10 +
    // ...anywhere else the words merge, and too few remain.
    'STR REPLACE %s , _' + #13#10 + 'SET %commaThenWith #StrRes' + #13#10 +
    'STR REPLACE %s %comma _' + #13#10 + 'SET %commaVarThenWith #StrRes' + #13#10 +
    // A lone dot is glued too, unless it's the last word.
    'SET %d a.b' + #13#10 +
    'STR REPLACE %d .' + #13#10 + 'SET %dotLast #StrRes' + #13#10 +
    'STR REPLACE %d . _' + #13#10 + 'SET %dotThenWith #StrRes' + #13#10 +
    'HALT');
  AssertEquals('N/A', Interp.GetVar('%noText'));
  AssertEquals('N/A', Interp.GetVar('%noSearch'));
  AssertEquals('ab', Interp.GetVar('%commaLast'));
  AssertEquals('ab', Interp.GetVar('%commaVarLast'));
  AssertEquals('N/A', Interp.GetVar('%commaThenWith'));
  AssertEquals('N/A', Interp.GetVar('%commaVarThenWith'));
  AssertEquals('ab', Interp.GetVar('%dotLast'));
  AssertEquals('N/A', Interp.GetVar('%dotThenWith'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrPart;
begin
  PlayScript(
    'SET %s one_Two_three' + #13#10 +
    'STR PART %s _ 1' + #13#10 + 'SET %f1 #StrRes' + #13#10 +
    'STR PART %s _ 2' + #13#10 + 'SET %f2 #StrRes' + #13#10 +
    'STR PART %s _ 3' + #13#10 + 'SET %f3 #StrRes' + #13#10 +
    'STR PART aXbxc x 3' + #13#10 + 'SET %case #StrRes' + #13#10 +
    'STR PART a::b::c :: 2' + #13#10 + 'SET %long #StrRes' + #13#10 +
    'STR PART ABCmake:DEF MAKE: 2' + #13#10 + 'SET %word #StrRes' + #13#10 +
    'STR PART Hello _ 1' + #13#10 + 'SET %noSep #StrRes' + #13#10 +
    'SET %n 2' + #13#10 +
    'STR PART %s _ %n' + #13#10 + 'SET %var #StrRes' + #13#10 +
    'STR PART a;b #SMC 2' + #13#10 + 'SET %smc #StrRes' + #13#10 +
    'STR PART a.b #DOT 2' + #13#10 + 'SET %dot #StrRes' + #13#10 +
    'HALT');
  AssertEquals('one', Interp.GetVar('%f1'));
  AssertEquals('Two', Interp.GetVar('%f2'));
  AssertEquals('three', Interp.GetVar('%f3'));
  AssertEquals('c', Interp.GetVar('%case'));
  AssertEquals('b', Interp.GetVar('%long'));
  AssertEquals('DEF', Interp.GetVar('%word'));
  AssertEquals('Hello', Interp.GetVar('%noSep'));
  AssertEquals('Two', Interp.GetVar('%var'));
  AssertEquals('b', Interp.GetVar('%smc'));
  AssertEquals('b', Interp.GetVar('%dot'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrPartEmptyFields;
begin
  PlayScript(
    'STR PART _a_b _ 1' + #13#10 + 'SET %startEmpty #StrRes' + #13#10 +
    'STR PART _a_b _ 2' + #13#10 + 'SET %startA #StrRes' + #13#10 +
    'STR PART a_b_ _ 3' + #13#10 + 'SET %endEmpty #StrRes' + #13#10 +
    'STR PART a__b _ 2' + #13#10 + 'SET %midEmpty #StrRes' + #13#10 +
    'STR PART a__b _ 3' + #13#10 + 'SET %midB #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR PART %empty _ 1' + #13#10 + 'SET %emptyText #StrRes' + #13#10 +
    'STR PART Hello %empty 1' + #13#10 + 'SET %emptySep #StrRes' + #13#10 +
    'HALT');
  AssertEquals('', Interp.GetVar('%startEmpty'));
  AssertEquals('a', Interp.GetVar('%startA'));
  AssertEquals('', Interp.GetVar('%endEmpty'));
  AssertEquals('', Interp.GetVar('%midEmpty'));
  AssertEquals('b', Interp.GetVar('%midB'));
  AssertEquals('', Interp.GetVar('%emptyText'));
  AssertEquals('Hello', Interp.GetVar('%emptySep'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrPartNoSuchField;
begin
  PlayScript(
    'STR PART a_b _ 3' + #13#10 + 'SET %past #StrRes' + #13#10 +
    'STR PART a_b _ 0' + #13#10 + 'SET %zero #StrRes' + #13#10 +
    'STR PART a_b _ -1' + #13#10 + 'SET %negative #StrRes' + #13#10 +
    'STR PART a_b _ x' + #13#10 + 'SET %notNumber #StrRes' + #13#10 +
    'STR PART a_b _' + #13#10 + 'SET %noN #StrRes' + #13#10 +
    'STR PART a_b' + #13#10 + 'SET %noSep #StrRes' + #13#10 +
    'STR PART' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'STR PART Hello _ 2' + #13#10 + 'SET %pastNoSep #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR PART Hello %empty 2' + #13#10 + 'SET %pastEmptySep #StrRes' + #13#10 +
    'STR PART %empty _ 2' + #13#10 + 'SET %pastEmptyText #StrRes' + #13#10 +
    // A lone comma merges the words around it, as for REPLACE.
    'STR PART a,b , 2' + #13#10 + 'SET %comma #StrRes' + #13#10 +
    'HALT');
  AssertEquals('N/A', Interp.GetVar('%past'));
  AssertEquals('N/A', Interp.GetVar('%zero'));
  AssertEquals('N/A', Interp.GetVar('%negative'));
  AssertEquals('N/A', Interp.GetVar('%notNumber'));
  AssertEquals('N/A', Interp.GetVar('%noN'));
  AssertEquals('N/A', Interp.GetVar('%noSep'));
  AssertEquals('N/A', Interp.GetVar('%noText'));
  AssertEquals('N/A', Interp.GetVar('%pastNoSep'));
  AssertEquals('N/A', Interp.GetVar('%pastEmptySep'));
  AssertEquals('N/A', Interp.GetVar('%pastEmptyText'));
  AssertEquals('N/A', Interp.GetVar('%comma'));
end;

////////////////////////////////////////////////////////////////////////////////
// STR COUNT + 1 is the number of fields: its last field exists and the one after doesn't.
procedure TEuoInterpreterTests.TestStrPartAgreesWithCount;
const
  Texts : array[0..7] of String = ('a_b_c','_a_b','a_b_','a__b','___','Hello','_','a_b_c_d_e');
var
  Cnt : Integer;
begin
  for Cnt:=0 to High(Texts) do
  begin
    PlayScript(
      'STR COUNT ' + Texts[Cnt] + ' _' + #13#10 +
      'SET %n #StrRes + 1' + #13#10 +
      'SET %past %n + 1' + #13#10 +
      'STR PART ' + Texts[Cnt] + ' _ %n' + #13#10 + 'SET %last #StrRes' + #13#10 +
      'STR PART ' + Texts[Cnt] + ' _ %past' + #13#10 + 'SET %beyond #StrRes' + #13#10 +
      'HALT');
    AssertTrue(Texts[Cnt] + ': the last field exists', Interp.GetVar('%last') <> 'N/A');
    AssertEquals(Texts[Cnt] + ': the one after does not', 'N/A', Interp.GetVar('%beyond'));
    Interp.Clear;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// #Property holds real spaces and ends each line in $; #Journal reads spaces as _.
// Neither can be set from a script, so a variable holds the same shape.
procedure TEuoInterpreterTests.TestStrPartOnPropertyAndJournalText;
begin
  PlayScript(
    'SET %p Tinker , #SPC , Tools$Uses , #SPC , Remaining: , #SPC , 25$Blessed$' + #13#10 +
    'STR PART %p $ 1' + #13#10 + 'SET %name #StrRes' + #13#10 +
    'STR PART %p $ 3' + #13#10 + 'SET %line3 #StrRes' + #13#10 +
    'STR PART %p $ 4' + #13#10 + 'SET %afterLast #StrRes' + #13#10 +
    'STR PART %p $ 5' + #13#10 + 'SET %past #StrRes' + #13#10 +
    'STR PART %name #SPC 1' + #13#10 + 'SET %word1 #StrRes' + #13#10 +
    'STR PART %name _ 2' + #13#10 + 'SET %underscoreIsNotASpace #StrRes' + #13#10 +
    // Between two markers: everything after the colon, up to the end of its line.
    'STR PART %p : 2' + #13#10 +
    'STR PART #StrRes $ 1' + #13#10 + 'SET %rawUses #StrRes' + #13#10 +
    'STR TRIM %rawUses' + #13#10 + 'SET %uses #StrRes' + #13#10 +
    'STR REPLACE %name #SPC _' + #13#10 + 'SET %likeJournal #StrRes' + #13#10 +
    'SET %j You_must_wait' + #13#10 +
    'STR PART %j _ 3' + #13#10 + 'SET %jWord #StrRes' + #13#10 +
    'STR PART %j #SPC 2' + #13#10 + 'SET %spaceIsNotAnUnderscore #StrRes' + #13#10 +
    'STR REPLACE %j _ #SPC' + #13#10 + 'SET %readable #StrRes' + #13#10 +
    'HALT');
  AssertEquals('Tinker Tools', Interp.GetVar('%name'));
  AssertEquals('Blessed', Interp.GetVar('%line3'));
  AssertEquals('', Interp.GetVar('%afterLast'));
  AssertEquals('N/A', Interp.GetVar('%past'));
  AssertEquals('Tinker', Interp.GetVar('%word1'));
  AssertEquals('N/A', Interp.GetVar('%underscoreIsNotASpace'));
  AssertEquals(' 25', Interp.GetVar('%rawUses'));
  AssertEquals('25', Interp.GetVar('%uses'));
  AssertEquals('Tinker_Tools', Interp.GetVar('%likeJournal'));
  AssertEquals('wait', Interp.GetVar('%jWord'));
  AssertEquals('N/A', Interp.GetVar('%spaceIsNotAnUnderscore'));
  AssertEquals('You must wait', Interp.GetVar('%readable'));
end;

////////////////////////////////////////////////////////////////////////////////
// What the hand-written subs of real scripts got, written here by hand, from the same inputs.
procedure TEuoInterpreterTests.TestStrPartReplacesHandWrittenSubs;
begin
  PlayScript(
    // A version check taking #EUOVer apart at _ (two calls of a "string before underscore" sub).
    'STR PART 1_50_00 _ 1' + #13#10 + 'SET %major #StrRes' + #13#10 +
    'STR PART 1_50_00 _ 2' + #13#10 + 'SET %minor #StrRes' + #13#10 +
    'STR PART 1_50_00 _ 3' + #13#10 + 'SET %build #StrRes' + #13#10 +
    // A lookup in a stored list: after name^, up to the next |.
    'SET %global one^1|two^2|three^3|' + #13#10 +
    'STR PART %global two^ 2' + #13#10 +
    'STR PART #StrRes | 1' + #13#10 + 'SET %lookup #StrRes' + #13#10 +
    // Splitting into numbered variables, in a FOR.
    'SET %list a_b_c' + #13#10 +
    'STR COUNT %list _' + #13#10 +
    'SET %n #StrRes + 1' + #13#10 +
    'FOR %i 1 %n' + #13#10 +
    '{' + #13#10 +
    '  STR PART %list _ %i' + #13#10 +
    '  SET %map . %i #StrRes' + #13#10 +
    '}' + #13#10 +
    // Removing a set of characters, one at a time.
    'SET %bad ?!/' + #13#10 +
    'SET %name a?b!c/d?' + #13#10 +
    'STR LEN %bad' + #13#10 +
    'SET %n #StrRes' + #13#10 +
    'FOR %i 1 %n' + #13#10 +
    '{' + #13#10 +
    '  STR MID %bad %i 1' + #13#10 +
    '  STR REPLACE %name #StrRes' + #13#10 +
    '  SET %name #StrRes' + #13#10 +
    '}' + #13#10 +
    'HALT', 200);
  AssertEquals('1', Interp.GetVar('%major'));
  AssertEquals('50', Interp.GetVar('%minor'));
  AssertEquals('00', Interp.GetVar('%build'));
  AssertEquals('2', Interp.GetVar('%lookup'));
  AssertEquals('a', Interp.GetVar('%map1'));
  AssertEquals('b', Interp.GetVar('%map2'));
  AssertEquals('c', Interp.GetVar('%map3'));
  AssertEquals('abcd', Interp.GetVar('%name'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrTrim;
begin
  PlayScript(
    'STR TRIM __hello_world__' + #13#10 + 'SET %underscores #StrRes' + #13#10 +
    'SET %s #SPC , _ , #SPC , a , #SPC , b , _ , #SPC' + #13#10 +
    'STR TRIM %s' + #13#10 + 'SET %mixed #StrRes' + #13#10 +
    'STR TRIM Hello' + #13#10 + 'SET %nothing #StrRes' + #13#10 +
    'STR TRIM ____' + #13#10 + 'SET %allGone #StrRes' + #13#10 +
    'STR TRIM _a_' + #13#10 + 'SET %short #StrRes' + #13#10 +
    'STR TRIM /a/b/ /' + #13#10 + 'SET %named #StrRes' + #13#10 +
    'STR TRIM _/a/_ /' + #13#10 + 'SET %namedOnly #StrRes' + #13#10 +
    'STR TRIM $/a$b/$ $/' + #13#10 + 'SET %namedTwo #StrRes' + #13#10 +
    'STR TRIM xXHelloXx X' + #13#10 + 'SET %case #StrRes' + #13#10 +
    'STR TRIM HelloxX x' + #13#10 + 'SET %caseKept #StrRes' + #13#10 +
    'STR TRIM %s #SPC' + #13#10 + 'SET %spaceOnly #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR TRIM _a_ %empty' + #13#10 + 'SET %emptyChars #StrRes' + #13#10 +
    'STR TRIM %empty' + #13#10 + 'SET %emptyText #StrRes' + #13#10 +
    'STR TRIM' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'HALT');
  AssertEquals('hello_world', Interp.GetVar('%underscores'));
  AssertEquals('a b', Interp.GetVar('%mixed'));
  AssertEquals('Hello', Interp.GetVar('%nothing'));
  AssertEquals('', Interp.GetVar('%allGone'));
  AssertEquals('a', Interp.GetVar('%short'));
  AssertEquals('a/b', Interp.GetVar('%named'));
  AssertEquals('_/a/_', Interp.GetVar('%namedOnly'));
  AssertEquals('a$b', Interp.GetVar('%namedTwo'));
  AssertEquals('Hello', Interp.GetVar('%case'));
  AssertEquals('Hello', Interp.GetVar('%caseKept'));
  AssertEquals('_ a b_', Interp.GetVar('%spaceOnly'));
  AssertEquals('_a_', Interp.GetVar('%emptyChars'));
  AssertEquals('', Interp.GetVar('%emptyText'));
  AssertEquals('N/A', Interp.GetVar('%noText'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrJoin;
begin
  PlayScript(
    'STR JOIN _ a b c' + #13#10 + 'SET %three #StrRes' + #13#10 +
    'STR JOIN _ OnlyOne' + #13#10 + 'SET %one #StrRes' + #13#10 +
    'STR JOIN _' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'STR JOIN' + #13#10 + 'SET %noSep #StrRes' + #13#10 +
    'STR JOIN :: a b' + #13#10 + 'SET %long #StrRes' + #13#10 +
    'STR JOIN #SPC Sir Robin' + #13#10 + 'SET %spc #StrRes' + #13#10 +
    'STR JOIN #DOT file txt' + #13#10 + 'SET %dot #StrRes' + #13#10 +
    'STR JOIN #SMC a b' + #13#10 + 'SET %smc #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR JOIN %empty a b' + #13#10 + 'SET %emptySep #StrRes' + #13#10 +
    'STR JOIN _ a %empty c' + #13#10 + 'SET %emptyMiddle #StrRes' + #13#10 +
    'STR PART %emptyMiddle _ 3' + #13#10 + 'SET %readBack #StrRes' + #13#10 +
    'STR COUNT %emptyMiddle _' + #13#10 + 'SET %readBackCount #StrRes' + #13#10 +
    // A lone comma merges the words around it, here the operation word itself.
    'STR JOIN , a b' + #13#10 + 'SET %comma #StrRes' + #13#10 +
    'HALT');
  AssertEquals('a_b_c', Interp.GetVar('%three'));
  AssertEquals('OnlyOne', Interp.GetVar('%one'));
  AssertEquals('N/A', Interp.GetVar('%noText'));
  AssertEquals('N/A', Interp.GetVar('%noSep'));
  AssertEquals('a::b', Interp.GetVar('%long'));
  AssertEquals('Sir Robin', Interp.GetVar('%spc'));
  AssertEquals('file.txt', Interp.GetVar('%dot'));
  AssertEquals('a;b', Interp.GetVar('%smc'));
  AssertEquals('ab', Interp.GetVar('%emptySep'));
  AssertEquals('a__c', Interp.GetVar('%emptyMiddle'));
  AssertEquals('c', Interp.GetVar('%readBack'));
  AssertEquals('2', Interp.GetVar('%readBackCount'));
  AssertEquals('N/A', Interp.GetVar('%comma'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoInterpreterTests.TestStrConcat;
begin
  PlayScript(
    'STR CONCAT a B c' + #13#10 + 'SET %three #StrRes' + #13#10 +
    'STR CONCAT OnlyOne' + #13#10 + 'SET %one #StrRes' + #13#10 +
    'STR CONCAT' + #13#10 + 'SET %noText #StrRes' + #13#10 +
    'STR LEFT Hello 0' + #13#10 + 'SET %empty #StrRes' + #13#10 +
    'STR CONCAT a %empty b' + #13#10 + 'SET %emptyMiddle #StrRes' + #13#10 +
    'STR CONCAT %empty' + #13#10 + 'SET %allEmpty #StrRes' + #13#10 +
    'STR CONCAT Sir #SPC Robin' + #13#10 + 'SET %spc #StrRes' + #13#10 +
    'STR CONCAT a , b c' + #13#10 + 'SET %glued #StrRes' + #13#10 +
    'SET %x 12' + #13#10 +
    'STR CONCAT %x 34' + #13#10 + 'SET %numbers #StrRes' + #13#10 +
    'HALT');
  AssertEquals('aBc', Interp.GetVar('%three'));
  AssertEquals('OnlyOne', Interp.GetVar('%one'));
  AssertEquals('N/A', Interp.GetVar('%noText'));
  AssertEquals('ab', Interp.GetVar('%emptyMiddle'));
  AssertEquals('', Interp.GetVar('%allEmpty'));
  AssertEquals('Sir Robin', Interp.GetVar('%spc'));
  AssertEquals('abc', Interp.GetVar('%glued'));
  AssertEquals('1234', Interp.GetVar('%numbers'));
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
////////////////////////////////////////////////////////////////////////////////
// WAITFOR (port addition). Timing bounds leave room for a GetTickCount step on the low side and
// for a busy machine on the high side.
procedure TEuoInterpreterTests.TestWaitForAlreadyTrueReturnsAtOnce;
var
  T : QWord;
begin
  T := GetTickCount64;
  PlayScript('waitfor 1 = 1 5s' + #13#10 + 'HALT');
  AssertEquals('-1', Interp.GetVar('#WaitRes'));
  AssertTrue('must not wait', GetTickCount64 - T < 1000);
end;

procedure TEuoInterpreterTests.TestWaitForTimesOutInTicks;
var
  T, E : QWord;
begin
  T := GetTickCount64;
  PlayScript('waitfor 1 = 2 4' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('4 ticks are 200 ms, waited ' + IntToStr(E), (E >= 170) and (E < 2000));
end;

procedure TEuoInterpreterTests.TestWaitForTimesOutInSeconds;
var
  T, E : QWord;
begin
  T := GetTickCount64;
  PlayScript('waitfor 1 = 2 1s' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('1s, waited ' + IntToStr(E), (E >= 960) and (E < 3000));
end;

procedure TEuoInterpreterTests.TestWaitForDefaultAndUnreadableTimeoutAreTwoSeconds;
var
  T, E : QWord;
begin
  T := GetTickCount64;
  PlayScript('waitfor 1 = 2' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('omitted, waited ' + IntToStr(E), (E >= 1960) and (E < 4000));

  Interp.Clear;
  T := GetTickCount64;
  PlayScript('waitfor 1 = 2 %unset' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('unreadable, waited ' + IntToStr(E), (E >= 1960) and (E < 4000));
end;

procedure TEuoInterpreterTests.TestWaitForTimeoutZeroChecksOnce;
var
  T : QWord;
begin
  T := GetTickCount64;
  PlayScript('waitfor 1 = 2 0' + #13#10 + 'set %f #WaitRes' + #13#10 +
             'waitfor 1 = 1 0' + #13#10 + 'set %t #WaitRes' + #13#10 + 'HALT');
  AssertEquals('0', Interp.GetVar('%f'));
  AssertEquals('-1', Interp.GetVar('%t'));
  AssertTrue('must not wait', GetTickCount64 - T < 1000);
end;

procedure TEuoInterpreterTests.TestWaitForTimeoutFromAVariable;
var
  T, E : QWord;
begin
  T := GetTickCount64;
  PlayScript('set %t 4' + #13#10 + 'waitfor 1 = 2 %t' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('4 ticks, waited ' + IntToStr(E), (E >= 170) and (E < 1900));
end;

// #SCnt2 counts tenths of a second, so this condition only comes true while waiting.
procedure TEuoInterpreterTests.TestWaitForReadsTheConditionAgainWhileWaiting;
var
  T, E : QWord;
begin
  T := GetTickCount64;
  PlayScript('set #scnt2 0' + #13#10 + 'waitfor #scnt2 >= 3 20s' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('-1', Interp.GetVar('#WaitRes'));
  AssertTrue('about 300 ms, waited ' + IntToStr(E), (E >= 150) and (E < 5000));
end;

// Each condition goes through IF and through WAITFOR followed by a timeout, and both must answer
// what the table says.
procedure TEuoInterpreterTests.TestWaitForAgreesWithIf;
const
  Cases : array[0..21] of array[0..1] of String = (
    ('%a = 5', '-1'),
    ('%a <> 5', '0'),
    ('%a < 6', '-1'),
    ('%a >= 6', '0'),
    ('%b = ABC', '-1'),
    ('%a < %b', '0'),
    ('b in %b', '-1'),
    ('z in %b', '0'),
    ('z notin %b', '-1'),
    ('%a = 5 && %b = abc', '-1'),
    ('%a = 5 && %b = zzz', '0'),
    ('%a = 6 || %b = abc', '-1'),
    ('%a = 6 || %b = zzz', '0'),
    ('! ( %a = 5 )', '0'),
    ('%t', '-1'),
    ('%f', '0'),
    ('%a = 5 && %b = abc && 1 = 1 && 2 = 2 && 3 = 3 && 4 = 4', '-1'),
    ('%a = 6 || %a = 7 || %a = 8 || %a = 9 || %a = 5', '-1'),
    ('( %a = 6 || %b = abc ) && ( %a = 5 || %b = zzz )', '-1'),
    ('( ( %a = 6 || %b = abc ) && ( %a = 7 || %b = zzz ) ) || %a = 9', '0'),
    ('( ( ( %a = 6 || %a = 5 ) && %b = abc ) || %a = 9 ) && ! ( %a = 9 )', '-1'),
    ('( ( ( %a = 6 || %a = 7 ) && %b = abc ) || %a = 5 ) && ( %b = abc || ( %a = 9 && %a = 8 ) )', '-1'));
var
  Cnt : Integer;
begin
  for Cnt := Low(Cases) to High(Cases) do
  begin
    Interp.Clear;
    PlayScript(
      'set %a 5' + #13#10 + 'set %b abc' + #13#10 + 'set %t #true' + #13#10 + 'set %f #false' + #13#10 +
      'set %if 0' + #13#10 +
      'if ' + Cases[Cnt][0] + #13#10 +
      '  set %if -1' + #13#10 +
      'waitfor ' + Cases[Cnt][0] + ' 0' + #13#10 +
      'HALT');
    AssertEquals('if ' + Cases[Cnt][0], Cases[Cnt][1], Interp.GetVar('%if'));
    AssertEquals('waitfor ' + Cases[Cnt][0], Cases[Cnt][1], Interp.GetVar('#WaitRes'));
  end;
end;

procedure TEuoInterpreterTests.TestWaitForAndBindsTighterThanOr;
begin
  PlayScript(
    'waitfor 1 = 2 && 1 = 2 || 1 = 1 0' + #13#10 + 'set %a #WaitRes' + #13#10 +
    'waitfor 1 = 1 || 1 = 2 && 1 = 2 0' + #13#10 + 'set %b #WaitRes' + #13#10 +
    'waitfor ( 1 = 1 || 1 = 2 ) && 1 = 2 0' + #13#10 + 'set %c #WaitRes' + #13#10 +
    'HALT');
  AssertEquals('(F && F) || T', '-1', Interp.GetVar('%a'));
  AssertEquals('T || (F && F)', '-1', Interp.GetVar('%b'));
  AssertEquals('(T || F) && F', '0', Interp.GetVar('%c'));
end;

procedure TEuoInterpreterTests.TestWaitForNestedConditionWaitsAndTimesOut;
var
  T, E : QWord;
begin
  // One inner branch turns true during the wait.
  T := GetTickCount64;
  PlayScript('set #scnt2 0' + #13#10 +
             'waitfor ( ( 1 = 2 || #scnt2 >= 3 ) && 2 = 2 ) || 3 = 4 20s' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('-1', Interp.GetVar('#WaitRes'));
  AssertTrue('about 300 ms, waited ' + IntToStr(E), (E >= 150) and (E < 5000));

  // Stays false: the timeout after the closing parenthesis is the one that counts, not the default.
  Interp.Clear;
  T := GetTickCount64;
  PlayScript('waitfor ( ( 1 = 2 || 1 = 3 ) && 2 = 2 ) || 3 = 4 4' + #13#10 + 'HALT');
  E := GetTickCount64 - T;
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertTrue('4 ticks, waited ' + IntToStr(E), (E >= 170) and (E < 1900));
end;

procedure TEuoInterpreterTests.TestWaitForNestedConditionOverContinuationLines;
begin
  PlayScript(
    'set #scnt2 0' + #13#10 +
    'waitfor ( ( 1 = 2 || #scnt2 >= 2 )' + #13#10 +
    '+ && 2 = 2 )' + #13#10 +
    '+ || 3 = 4 20s' + #13#10 +
    'set %after 1' + #13#10 +
    'HALT');
  AssertEquals('-1', Interp.GetVar('#WaitRes'));
  AssertEquals('1', Interp.GetVar('%after'));
end;

// Polling parses the line again: that must not lose the place after the continuation lines.
procedure TEuoInterpreterTests.TestWaitForContinuationGoesOnAfterItsLastLine;
begin
  PlayScript(
    'waitfor 1 =' + #13#10 +
    '+ 2 3' + #13#10 +
    'set %after 1' + #13#10 +
    'HALT');
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertEquals('1', Interp.GetVar('%after'));
end;

procedure TEuoInterpreterTests.TestWaitForLeavesResultAlone;
begin
  PlayScript('set #result keep' + #13#10 + 'waitfor 1 = 1 0' + #13#10 + 'waitfor 1 = 2 0' + #13#10 + 'HALT');
  AssertEquals('keep', Interp.GetVar('#Result'));
end;

procedure TEuoInterpreterTests.TestWaitForBareWordIsANoOp;
begin
  PlayScript('waitfor' + #13#10 + 'set %x reached' + #13#10 + 'HALT');
  AssertEquals('reached', Interp.GetVar('%x'));
  AssertEquals('N/A', Interp.GetVar('#WaitRes'));
end;

procedure TEuoInterpreterTests.TestWaitResReadsNAUntilAWaitForAndAfterClear;
begin
  AssertEquals('N/A', Interp.GetVar('#WaitRes'));
  PlayScript('waitfor 1 = 1 0' + #13#10 + 'HALT');
  AssertEquals('-1', Interp.GetVar('#WaitRes'));
  Interp.Clear;
  AssertEquals('N/A', Interp.GetVar('#WaitRes'));
end;

procedure TEuoInterpreterTests.TestWaitForAsAnIfBody;
begin
  PlayScript(
    'if 1 = 1' + #13#10 +
    '  waitfor 1 = 2 2' + #13#10 +
    'else' + #13#10 +
    '  set %else ran' + #13#10 +
    'set %after 1' + #13#10 +
    'if 1 = 2' + #13#10 +
    '  waitfor 1 = 1 0' + #13#10 +
    'HALT');
  AssertEquals('0', Interp.GetVar('#WaitRes'));
  AssertEquals('N/A', Interp.GetVar('%else'));
  AssertEquals('1', Interp.GetVar('%after'));
end;

// A one-line FOR body: LineInfo aims NextLine at the loop's head before the command runs, and
// polling must put that back, or the loop ends after one pass.
procedure TEuoInterpreterTests.TestWaitForInLoopsKeepsTheLoopGoing;
begin
  PlayScript(
    'for %i 1 3' + #13#10 +
    '  waitfor 1 = 2 2' + #13#10 +
    'set %n 0' + #13#10 +
    'while %n < 3' + #13#10 +
    '{' + #13#10 +
    '  waitfor 1 = 2 2' + #13#10 +
    '  set %n %n + 1' + #13#10 +
    '}' + #13#10 +
    'set %after 1' + #13#10 +
    'HALT');
  AssertEquals('three passes of the FOR', '4', Interp.GetVar('%i'));
  AssertEquals('three passes of the WHILE', '3', Interp.GetVar('%n'));
  AssertEquals('1', Interp.GetVar('%after'));
end;

procedure TEuoInterpreterTests.TestSubAndLabelNamedWaitForStillWork;
var
  T : QWord;
begin
  T := GetTickCount64;
  PlayScript(
    'gosub waitfor 7' + #13#10 +
    'set %res #result' + #13#10 +
    'goto waitfor' + #13#10 +
    'set %skipped yes' + #13#10 +
    'waitfor:' + #13#10 +
    'set %label reached' + #13#10 +
    'HALT' + #13#10 +
    'sub waitfor' + #13#10 +
    '  set %sub %1' + #13#10 +
    'return done');
  AssertEquals('7', Interp.GetVar('%sub'));
  AssertEquals('done', Interp.GetVar('%res'));
  AssertEquals('N/A', Interp.GetVar('%skipped'));
  AssertEquals('reached', Interp.GetVar('%label'));
  AssertEquals('none of these lines is the command', 'N/A', Interp.GetVar('#WaitRes'));
  AssertTrue('nothing waits', GetTickCount64 - T < 1000);
end;

////////////////////////////////////////////////////////////////////////////////
// FINDJOURNAL (port addition). The search itself is in EuoJournalSearchTests; here what the
// interpreter adds that can run without a client.
type
  TOneJournalLine = class(TObject)
  public
    Line : String;
    function Entry(Index : Cardinal; out Txt : String; out Col : Cardinal) : Boolean;
  end;

function TOneJournalLine.Entry(Index : Cardinal; out Txt : String; out Col : Cardinal) : Boolean;
begin
  Txt := Line;
  Col := 0;
  Result := Index = 0;
end;

procedure TEuoInterpreterTests.TestFindJournalWithNoClientIsANoOp;
var
  T : QWord;
begin
  T := GetTickCount64;
  PlayScript('findjournal 1000 * 3s fizzles' + #13#10 + 'set %after yes' + #13#10 + 'HALT');
  AssertEquals('it goes on', 'yes', Interp.GetVar('%after'));
  AssertEquals('N/A', Interp.GetVar('#JFound'));
  AssertTrue('nothing waits', GetTickCount64 - T < 1000);
end;

procedure TEuoInterpreterTests.TestJFoundReadsNAAfterClear;
begin
  AssertEquals('N/A', Interp.GetVar('#JFound'));
  Interp.Clear;
  AssertEquals('N/A', Interp.GetVar('#JFound'));
end;

procedure TEuoInterpreterTests.TestSubAndLabelNamedFindJournalStillWork;
begin
  PlayScript(
    'gosub findjournal 7' + #13#10 +
    'set %res #result' + #13#10 +
    'goto findjournal' + #13#10 +
    'set %skipped yes' + #13#10 +
    'findjournal:' + #13#10 +
    'set %label reached' + #13#10 +
    'HALT' + #13#10 +
    'sub findjournal' + #13#10 +
    '  set %sub %1' + #13#10 +
    'return done');
  AssertEquals('7', Interp.GetVar('%sub'));
  AssertEquals('done', Interp.GetVar('%res'));
  AssertEquals('N/A', Interp.GetVar('%skipped'));
  AssertEquals('reached', Interp.GetVar('%label'));
end;

// The wildcard has to arrive as the word '*': not read as a global variable (IsVar), and not as an
// operator, since FINDJOURNAL never calls Eval. A sub's parameters are ParseLine's words as well.
procedure TEuoInterpreterTests.TestBareStarReachesACommandAsAWord;
begin
  PlayScript(
    'gosub look 1000 * 0 *' + #13#10 +
    'HALT' + #13#10 +
    'sub look' + #13#10 +
    '  set %count %0' + #13#10 +
    '  set %color %2' + #13#10 +
    '  set %text %4' + #13#10 +
    'return');
  AssertEquals('4', Interp.GetVar('%count'));
  AssertEquals('*', Interp.GetVar('%color'));
  AssertEquals('*', Interp.GetVar('%text'));
end;

// The same text and line through the real IN and through JournalSearch. The line is what #Journal
// would read for 'You must wait'; a text with a real space is built with #spc.
procedure TEuoInterpreterTests.TestFindJournalMatchAgreesWithIn;
const
  Texts : array[0..6] of String =
    ('must', 'MUST', 'you_must_wait', 'You_Must', 'must_not', 'wait_', 'You must');
var
  Cnt       : Integer;
  InResult  : Boolean;
  Found     : Boolean;
  TextWords : String;
  Search    : TOneJournalLine;
begin
  Search := TOneJournalLine.Create;
  try
    Search.Line := 'You must wait';
    for Cnt := 0 to High(Texts) do
    begin
      TextWords := Texts[Cnt];
      if Pos(' ', TextWords) > 0 then
        TextWords := StringReplace(TextWords, ' ', ' , #spc , ', []);
      Interp.Clear;
      PlayScript(
        'set %t ' + TextWords + #13#10 +
        'set %hit no' + #13#10 +
        'if %t in You_must_wait' + #13#10 +
        '  set %hit yes' + #13#10 +
        'HALT');
      InResult := Interp.GetVar('%hit') = 'yes';
      AssertEquals('the script read the text: ' + Texts[Cnt], Texts[Cnt], Interp.GetVar('%t'));
      Found := JournalSearch(1, 1000, 0, Search.Entry, True, 0, [Texts[Cnt]]) > 0;
      AssertEquals(Texts[Cnt], InResult, Found);
    end;
  finally
    Search.Free;
  end;
end;

initialization
  RegisterTest(TEuoInterpreterTests);
end.
