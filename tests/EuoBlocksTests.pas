unit EuoBlocksTests;

{
  Tests for EuoBlocks.pas -- the script block rules shared by the editor's code
  folding (easyuo\eufoldsyn.pas) and Edit > Format Script. Pure string-in/
  string-out, no interpreter involved (see EuoBlocks.pas's header comment for
  which interpreter procedures each rule is read off).
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoBlocks;

type
  TEuoBlocksTests = class(TTestCase)
  private
    procedure CheckFormat(const Src, Expected : array of String; IndentWidth : Integer = 2);
    function  Trace(const Src : array of String) : String;
    function  FormatFile(const FN : String; Src, Dst : TStringList) : Boolean;
  published
    procedure TestLineCmdMatchesGetCmd;
    procedure TestBracedIfElse;
    procedure TestOneLineIfBody;
    procedure TestCommentOrBlankLineIsTheBody;
    procedure TestHeaderContinuationKeepsTheBodyPending;
    procedure TestContinuationLines;
    procedure TestNestedBlocks;
    procedure TestBraceUnderAOneLineBodyHeader;
    procedure TestSubWithEarlyReturn;
    procedure TestEarlyReturnInsideBraces;
    procedure TestBracedSub;
    procedure TestSubBraceMustBeTheVeryNextLine;
    procedure TestNextSubEndsAnUnclosedSub;
    procedure TestRepeatUntil;
    procedure TestLabelsAndCommentsKeepTheCurrentLevel;
    procedure TestStrayClosersAreHarmless;
    procedure TestOnlyLeadingAndTrailingWhitespaceChanges;
    procedure TestIndentWidth;
    procedure TestDstMayBeSrc;
    procedure TestStepTraceSubs;
    procedure TestStepTraceBracesAndRepeat;
    procedure TestRealScriptsOnlyWhitespaceChanges;
    procedure TestSelfTestIsAlreadyInHouseStyle;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.CheckFormat(const Src, Expected : array of String; IndentWidth : Integer);
var
  SL, Res : TStringList;
  Cnt     : Integer;
begin
  SL:=TStringList.Create;
  Res:=TStringList.Create;
  try
    for Cnt:=Low(Src) to High(Src) do SL.Add(Src[Cnt]);
    EuoFormatLines(SL,IndentWidth,Res);
    AssertEquals('line count',Length(Expected),Res.Count);
    for Cnt:=Low(Expected) to High(Expected) do
      AssertEquals('line '+IntToStr(Cnt+1),Expected[Cnt],Res[Cnt]);
  finally
    Res.Free;
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// One token per line: <Closes><Opens>, Opens as - none, B brace, b sub brace,
// S sub, R repeat -- applied to a stack the same way eufoldsyn.pas applies them
// to SynEdit's fold blocks.
function TEuoBlocksTests.Trace(const Src : array of String) : String;
const
  KindChar : array[TEuoBlockKind] of Char = ('-','B','b','S','R');
var
  Stack   : array of TEuoBlockKind;
  Pending : TEuoBodyPending;
  Step    : TEuoLineStep;
  Cnt     : Integer;
begin
  Result:='';
  SetLength(Stack,0);
  Pending:=ebpNone;
  for Cnt:=Low(Src) to High(Src) do
  begin
    Step:=EuoBlockStep(Src[Cnt],Pending,Stack);
    SetLength(Stack,Length(Stack)-Step.Closes);
    if Step.Opens<>ebkNone then
    begin
      SetLength(Stack,Length(Stack)+1);
      Stack[High(Stack)]:=Step.Opens;
    end;
    Pending:=Step.Pending;
    if Result<>'' then Result:=Result+' ';
    Result:=Result+IntToStr(Step.Closes)+KindChar[Step.Opens];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoBlocksTests.FormatFile(const FN : String; Src, Dst : TStringList) : Boolean;
begin
  Result:=FileExists(FN);
  if not Result then Exit;
  Src.LoadFromFile(FN);
  EuoFormatLines(Src,2,Dst);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestLineCmdMatchesGetCmd;
begin
  AssertEquals('IF',EuoLineCmd('  if %a = 1'));
  AssertEquals('SUB',EuoLineCmd(#9'sub'#9'foo'));
  AssertEquals('{',EuoLineCmd('{;comment'));
  AssertEquals('}',EuoLineCmd('} ; end'));
  AssertEquals('}ELSE',EuoLineCmd('}else'));
  AssertEquals('',EuoLineCmd('; comment'));
  AssertEquals('',EuoLineCmd('   '));
  AssertEquals('RETURN',EuoLineCmd('Return #true'));
  AssertEquals('MAINLOOP:',EuoLineCmd('mainloop:'));
  AssertEquals('+',EuoLineCmd('+ && %b'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestBracedIfElse;
begin
  CheckFormat(
    ['if #charghost = YES', '{', 'gosub res', 'wait 5', '}', 'else', '{', 'gosub heal', '}'],
    ['if #charghost = YES', '{', '  gosub res', '  wait 5', '}', 'else', '{', '  gosub heal', '}']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestOneLineIfBody;
begin
  CheckFormat(
    ['if %a = 1', 'set %b 2', 'set %c 3', 'else', 'set %c 4'],
    ['if %a = 1', '  set %b 2', 'set %c 3', 'else', '  set %c 4']);
  // ONHOTKEY and CMPPIX skip their next line (or brace block) like IF does
  CheckFormat(
    ['onhotkey F9', 'set %hk 1', 'cmppix 1 f', '{', 'set %p 1', '}', 'set %z 1'],
    ['onhotkey F9', '  set %hk 1', 'cmppix 1 f', '{', '  set %p 1', '}', 'set %z 1']);
  // a one-line body that is itself a header: its own body goes one deeper
  CheckFormat(
    ['for %i 1 3', 'if %i = 2', 'set %x 1', 'set %y 2'],
    ['for %i 1 3', '  if %i = 2', '    set %x 1', 'set %y 2']);
end;

////////////////////////////////////////////////////////////////////////////////
// The interpreter skips exactly one physical line, so a comment or a blank line
// right under a header IS its body and the statement after it always runs.
procedure TEuoBlocksTests.TestCommentOrBlankLineIsTheBody;
begin
  CheckFormat(
    ['if %a = 1', '; set %b 2', 'set %c 3'],
    ['if %a = 1', '  ; set %b 2', 'set %c 3']);
  CheckFormat(
    ['if %a = 1', '   ', 'set %c 3'],
    ['if %a = 1', '', 'set %c 3']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestHeaderContinuationKeepsTheBodyPending;
begin
  CheckFormat(
    ['if %a = 1', '+ && %b = 2', 'set %c 3', 'set %d 4'],
    ['if %a = 1', '  + && %b = 2', '  set %c 3', 'set %d 4']);
  CheckFormat(
    ['while %a < 3', '+ && %b = 2', '{', 'set %a %a + 1', '}'],
    ['while %a < 3', '  + && %b = 2', '{', '  set %a %a + 1', '}']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestContinuationLines;
begin
  CheckFormat(
    ['sub s', 'set %q select', '+ * from t', '+ where 1', 'return'],
    ['sub s', '  set %q select', '    + * from t', '    + where 1', 'return']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestNestedBlocks;
begin
  CheckFormat(
    ['for %i 1 10', '{', 'while %j < 3', '{', 'if %j = 2', '{', 'break', '}', 'set %j %j + 1', '}', '}'],
    ['for %i 1 10', '{', '  while %j < 3', '  {', '    if %j = 2', '    {', '      break', '    }',
     '    set %j %j + 1', '  }', '}']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestBraceUnderAOneLineBodyHeader;
begin
  CheckFormat(
    ['if %a = 1', 'if %b = 1', '{', 'set %c 1', '}', 'set %d 1'],
    ['if %a = 1', '  if %b = 1', '  {', '    set %c 1', '  }', 'set %d 1']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestSubWithEarlyReturn;
begin
  CheckFormat(
    ['sub check', 'if %1 = 0', 'return #false', 'set %x %1', 'return #true', '', 'sub next', 'return'],
    ['sub check', '  if %1 = 0', '    return #false', '  set %x %1', 'return #true', '', 'sub next', 'return']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestEarlyReturnInsideBraces;
begin
  CheckFormat(
    ['sub check', 'if %1 = 0', '{', 'set %r 1', 'return', '}', 'set %r 2', 'return'],
    ['sub check', '  if %1 = 0', '  {', '    set %r 1', '    return', '  }', '  set %r 2', 'return']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestBracedSub;
begin
  CheckFormat(
    ['sub braced', '{', 'set %a 1', 'if %a = 1', '{', 'return', '}', '}', 'set %after 1'],
    ['sub braced', '{', '  set %a 1', '  if %a = 1', '  {', '    return', '  }', '}', 'set %after 1']);
end;

////////////////////////////////////////////////////////////////////////////////
// ScanForBlock looks at the very next line only: with a blank line in between
// the braces are an ordinary block inside the sub, and the sub runs on to RETURN.
procedure TEuoBlocksTests.TestSubBraceMustBeTheVeryNextLine;
begin
  CheckFormat(
    ['sub s', '', '{', 'set %a 1', '}', 'return'],
    ['sub s', '', '  {', '    set %a 1', '  }', 'return']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestNextSubEndsAnUnclosedSub;
begin
  CheckFormat(
    ['sub main', 'repeat', 'gosub work', 'until #false', 'sub work', 'wait 1', 'return'],
    ['sub main', '  repeat', '    gosub work', '  until #false', 'sub work', '  wait 1', 'return']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestRepeatUntil;
begin
  CheckFormat(
    ['repeat', 'set %i %i + 1', 'repeat', 'wait 1', 'until #true', 'until %i >= 3'],
    ['repeat', '  set %i %i + 1', '  repeat', '    wait 1', '  until #true', 'until %i >= 3']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestLabelsAndCommentsKeepTheCurrentLevel;
begin
  CheckFormat(
    ['; header', 'sub loop', 'again:', '; step', 'gosub step', 'goto again', 'return', '; after'],
    ['; header', 'sub loop', '  again:', '  ; step', '  gosub step', '  goto again', 'return', '; after']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestStrayClosersAreHarmless;
begin
  CheckFormat(
    ['}', 'return', 'until #true', 'set %a 1'],
    ['}', 'return', 'until #true', 'set %a 1']);
  CheckFormat(
    ['{', 'set %a 1', '}', '}', 'set %b 1'],
    ['{', '  set %a 1', '}', '}', 'set %b 1']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestOnlyLeadingAndTrailingWhitespaceChanges;
begin
  CheckFormat(
    ['    if %a = 1   ', #9#9'{', #9'set'#9'%b   "x  y"  '#9, '        }'],
    ['if %a = 1', '{', '  set'#9'%b   "x  y"', '}']);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestIndentWidth;
begin
  CheckFormat(['sub s', 'if %a', 'set %b 1', 'return'],
              ['sub s', '    if %a', '        set %b 1', 'return'], 4);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestDstMayBeSrc;
var
  SL : TStringList;
begin
  SL:=TStringList.Create;
  try
    SL.Add('sub s');
    SL.Add('set %a 1');
    SL.Add('return');
    EuoFormatLines(SL,2,SL);
    AssertEquals(3,SL.Count);
    AssertEquals('  set %a 1',SL[1]);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestStepTraceSubs;
begin
  // plain sub: closes on its own RETURN, not on the early one
  AssertEquals('0S 0- 0- 0- 1-', Trace(['sub s', 'if %a', 'return 1', 'set %b', 'return']));
  // braced sub: the closing brace ends both
  AssertEquals('0S 0b 0- 2-', Trace(['sub s', '{', 'set %a 1', '}']));
  // next SUB ends an open sub (and anything still open inside it)
  AssertEquals('0S 0b 2S 1-', Trace(['sub a', '{', 'sub b', 'return']));
  // a RETURN that is the line right after SUB ends that sub
  AssertEquals('0S 1-', Trace(['sub empty', 'return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoBlocksTests.TestStepTraceBracesAndRepeat;
begin
  AssertEquals('0- 0B 0- 1-', Trace(['if %a', '{', 'set %b 1', '}']));
  // a closing brace also closes a REPEAT left open inside it
  AssertEquals('0B 0R 0- 2-', Trace(['{', 'repeat', 'wait 1', '}']));
  // UNTIL looks through braces, but not out of a sub
  AssertEquals('0R 0B 2-', Trace(['repeat', '{', 'until #true']));
  AssertEquals('0R 0S 0-', Trace(['repeat', 'sub s', 'until #true']));
  // continuation lines change nothing
  AssertEquals('0- 0- 0B 1-', Trace(['if %a', '+ && %b', '{', '}']));
end;

////////////////////////////////////////////////////////////////////////////////
// Format must never change anything but leading/trailing whitespace (which the
// interpreter trims away on every read) nor the line count, and must be
// idempotent.
procedure TEuoBlocksTests.TestRealScriptsOnlyWhitespaceChanges;
const
  Files : array[0..1] of String = (
    'euo\all-commands-test.euo',
    '..\tools\EUOSelfTest\EUOSelfTest.euo');
var
  Src, Dst, Again : TStringList;
  FIdx, Cnt       : Integer;
  FN              : String;
begin
  Src:=TStringList.Create;
  Dst:=TStringList.Create;
  Again:=TStringList.Create;
  try
    for FIdx:=Low(Files) to High(Files) do
    begin
      FN:=ExtractFilePath(ParamStr(0))+Files[FIdx];
      AssertTrue('fixture missing: '+FN,FormatFile(FN,Src,Dst));
      AssertEquals(Files[FIdx]+' line count',Src.Count,Dst.Count);
      for Cnt:=0 to Src.Count-1 do
        AssertEquals(Files[FIdx]+' line '+IntToStr(Cnt+1),Trim(Src[Cnt]),Trim(Dst[Cnt]));
      EuoFormatLines(Dst,2,Again);
      AssertEquals(Files[FIdx]+' idempotent',Dst.Text,Again.Text);
    end;
  finally
    Again.Free;
    Dst.Free;
    Src.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// EUOSelfTest.euo is written in the house style the formatter implements.
procedure TEuoBlocksTests.TestSelfTestIsAlreadyInHouseStyle;
var
  Src, Dst : TStringList;
  Cnt      : Integer;
  FN       : String;
begin
  Src:=TStringList.Create;
  Dst:=TStringList.Create;
  try
    FN:=ExtractFilePath(ParamStr(0))+'..\tools\EUOSelfTest\EUOSelfTest.euo';
    AssertTrue('fixture missing: '+FN,FormatFile(FN,Src,Dst));
    for Cnt:=0 to Src.Count-1 do
      AssertEquals('line '+IntToStr(Cnt+1),TrimRight(Src[Cnt]),Dst[Cnt]);
  finally
    Dst.Free;
    Src.Free;
  end;
end;

initialization
  RegisterTest(TEuoBlocksTests);
end.
