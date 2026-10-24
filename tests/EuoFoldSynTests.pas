unit EuoFoldSynTests;

{
  Tests for easyuo\eufoldsyn.pas's TSynEUOSyn -- the fold highlighter that wraps
  the editor's TSynUniSyn coloring (see that unit's header comment).

  - Fold levels: lines are scanned the way SynEdit scans them (ResetRange or
    SetRange(previous line's range), SetLine, NextToEol, GetRange), and each
    stored range's fold-stack size / per-line minimum gives that line's
    opening and closing counts.
  - Fold lengths: one real (never shown) TSynEdit, to check what
    TSynCustomFoldHighlighter.FoldLineLength makes of those levels -- in
    particular that a sub ended implicitly by the next SUB keeps that line
    visible.
  - Coloring parity: every token of a real script comes out of the wrapper
    with the same text, position and attribute as out of a bare TSynUniSyn
    built by the same BuildEUOHighlighter -- folding must not change colors.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, SynEdit, SynEditHighlighter,
  SynEditHighlighterFoldBase, SynUniHighlighter, eusyntax, eufoldsyn;

type
  TEuoFoldSynTests = class(TTestCase)
  private
    FHL : TSynEUOSyn;
    function  FoldTrace(const Src : array of String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBraceBlocksFoldFromTheBraceLine;
    procedure TestSubFoldsToItsOwnReturn;
    procedure TestBracedSubClosesBothFolds;
    procedure TestNextSubEndsAnOpenSub;
    procedure TestRepeatUntilFolds;
    procedure TestHeaderContinuationDoesNotEatTheBraceBlock;
    procedure TestPendingIsPartOfTheRange;
    procedure TestFoldLineLengthInARealEditor;
    procedure TestEarlyReturnInBracesInARealEditor;
    procedure TestEverySelfTestSubFoldsToItsReturn;
    procedure TestColoringMatchesPlainTSynUniSyn;
  end;

implementation

type
  // TSynEditBase keeps TextBuffer protected; Lazarus's own SynEdit tests
  // (components/synedit/test/testbase.pas) re-publish it the same way.
  TTestSynEdit = class(TSynEdit)
  public
    property TextBuffer;
  end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.SetUp;
begin
  FHL:=TSynEUOSyn.Create(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TearDown;
begin
  FHL.Free;
end;

////////////////////////////////////////////////////////////////////////////////
// One "<opens>/<closes>" token per line.
function TEuoFoldSynTests.FoldTrace(const Src : array of String) : String;
var
  Ranges         : array of TSynCustomHighlighterRange;
  Cnt            : Integer;
  EndLvl, MinLvl : Integer;
  PrevEnd        : Integer;
begin
  Result:='';
  SetLength(Ranges,Length(Src));
  PrevEnd:=0;
  for Cnt:=0 to High(Src) do
  begin
    if Cnt=0 then FHL.ResetRange
    else FHL.SetRange(Ranges[Cnt-1]);
    FHL.SetLine(Src[Cnt],Cnt);
    FHL.NextToEol;
    Ranges[Cnt]:=TSynCustomHighlighterRange(FHL.GetRange);

    EndLvl:=Ranges[Cnt].CodeFoldStackSize;
    MinLvl:=Ranges[Cnt].MinimumCodeFoldBlockLevel;
    if Result<>'' then Result:=Result+' ';
    Result:=Result+IntToStr(EndLvl-MinLvl)+'/'+IntToStr(PrevEnd-MinLvl);
    PrevEnd:=EndLvl;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestBraceBlocksFoldFromTheBraceLine;
begin
  AssertEquals('0/0 1/0 0/0 0/1 0/0 1/0 0/0 0/1',
    FoldTrace(['if #charghost = YES', '{', 'gosub res', '}', 'else', '{', 'gosub heal', '}']));
  AssertEquals('1/0 1/0 0/0 0/1 0/1',
    FoldTrace(['{', '  {', '    set %a 1', '  } ; inner', '}']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestSubFoldsToItsOwnReturn;
begin
  AssertEquals('1/0 0/0 0/0 0/0 0/1 0/0',
    FoldTrace(['sub check', '  if %1 = 0', '    return #false', '  set %x %1', 'return #true', 'halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestBracedSubClosesBothFolds;
begin
  AssertEquals('1/0 1/0 0/0 0/2',
    FoldTrace(['sub braced', '{', '  set %a 1', '}']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestNextSubEndsAnOpenSub;
begin
  AssertEquals('1/0 0/0 1/1 0/0 0/1',
    FoldTrace(['sub main', '  goto main', 'sub work', '  wait 1', 'return']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestRepeatUntilFolds;
begin
  AssertEquals('1/0 0/0 0/1',
    FoldTrace(['repeat', '  wait 1', 'until #true']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestHeaderContinuationDoesNotEatTheBraceBlock;
begin
  AssertEquals('1/0 0/0 0/0 1/0 0/1 0/1',
    FoldTrace(['sub s', 'if %a = 1', '+ && %b = 2', '{', '}', 'return']));
end;

////////////////////////////////////////////////////////////////////////////////
// Two lines with identical fold levels but a different Pending must store
// different ranges, or SynEdit would stop rescanning too early after an edit
// that turns "set" into "if" (and miss that the next RETURN no longer ends
// the sub).
procedure TEuoFoldSynTests.TestPendingIsPartOfTheRange;
var
  RIf, RSet : Pointer;
begin
  FHL.ResetRange;
  FHL.SetLine('if %a = 1',0);
  FHL.NextToEol;
  RIf:=FHL.GetRange;

  FHL.ResetRange;
  FHL.SetLine('set %a 1',0);
  FHL.NextToEol;
  RSet:=FHL.GetRange;

  AssertTrue(RIf<>RSet);
  AssertEquals(TSynCustomHighlighterRange(RIf).CodeFoldStackSize,
               TSynCustomHighlighterRange(RSet).CodeFoldStackSize);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestFoldLineLengthInARealEditor;
var
  Ed : TTestSynEdit;
begin
  Ed:=TTestSynEdit.Create(nil);
  try
    Ed.Highlighter:=FHL;
    Ed.Lines.Text:=
      'sub main'+LineEnding+          // 0
      '  goto main'+LineEnding+       // 1
      'sub work'+LineEnding+          // 2
      '  if %a = 1'+LineEnding+       // 3
      '  {'+LineEnding+               // 4
      '    wait 1'+LineEnding+        // 5
      '  }'+LineEnding+               // 6
      'return'+LineEnding+            // 7
      'halt';                         // 8
    FHL.CurrentLines:=Ed.TextBuffer;
    FHL.ScanAllRanges;

    AssertEquals('sub main hides only its body, not "sub work"',1,FHL.FoldLineLength(0,0));
    AssertEquals('sub work hides through its RETURN',5,FHL.FoldLineLength(2,0));
    AssertEquals('the brace block hides through its closing brace',2,FHL.FoldLineLength(4,0));
    AssertEquals('no fold opens on the IF line itself',0,FHL.FoldBlockOpeningCount(3));
  finally
    Ed.Highlighter:=nil;
    Ed.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// EUOSelfTest.euo's sub st_vg_journal: the RETURN inside the first brace block
// must not end the sub's fold -- it runs to the sub's own RETURN.
procedure TEuoFoldSynTests.TestEarlyReturnInBracesInARealEditor;
var
  Ed  : TTestSynEdit;
  Cnt : Integer;
  Dbg : String;
begin
  Ed:=TTestSynEdit.Create(nil);
  try
    Ed.Highlighter:=FHL;
    Ed.Lines.Text:=
      'sub st_vg_journal'+LineEnding+                              // 0
      '  gosub st_case 1.70 journal_variables'+LineEnding+         // 1
      '  if %st_run = 0'+LineEnding+                               // 2
      '  {'+LineEnding+                                            // 3
      '    return'+LineEnding+                                     // 4
      '  }'+LineEnding+                                            // 5
      '  st_rp_6:'+LineEnding+                                     // 6
      '  scanJournal 1'+LineEnding+                                // 7
      '  if %st_again = 1'+LineEnding+                             // 8
      '  {'+LineEnding+                                            // 9
      '    goto st_rp_6'+LineEnding+                               // 10
      '  }'+LineEnding+                                            // 11
      'return'+LineEnding+                                         // 12
      ''+LineEnding+                                               // 13
      'sub st_vg_lastaction'+LineEnding+                           // 14
      '  gosub st_case 1.80 x'+LineEnding+                         // 15
      'return';                                                    // 16
    FHL.CurrentLines:=Ed.TextBuffer;
    FHL.ScanAllRanges;

    Dbg:='';
    for Cnt:=0 to Ed.Lines.Count-1 do
      Dbg:=Dbg+' '+IntToStr(FHL.FoldBlockEndLevel(Cnt))+'/'+IntToStr(FHL.FoldBlockMinLevel(Cnt));
    AssertEquals('sub hides through its own RETURN'+Dbg,12,FHL.FoldLineLength(0,0));
    AssertEquals('first brace block'+Dbg,2,FHL.FoldLineLength(3,0));
    AssertEquals('second brace block'+Dbg,2,FHL.FoldLineLength(9,0));
    AssertEquals('next sub'+Dbg,2,FHL.FoldLineLength(14,0));
  finally
    Ed.Highlighter:=nil;
    Ed.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Every SUB in EUOSelfTest.euo (all written as "sub ... return" at column 0)
// opens a fold that ends exactly on the column-0 RETURN closing it.
procedure TEuoFoldSynTests.TestEverySelfTestSubFoldsToItsReturn;
var
  Ed        : TTestSynEdit;
  Cnt, Last : Integer;
  Subs      : Integer;
  FN, Where : String;
begin
  FN:=ExtractFilePath(ParamStr(0))+'..\tools\EUOSelfTest\EUOSelfTest.euo';
  AssertTrue('fixture missing: '+FN,FileExists(FN));
  Ed:=TTestSynEdit.Create(nil);
  try
    Ed.Highlighter:=FHL;
    Ed.Lines.LoadFromFile(FN);
    FHL.CurrentLines:=Ed.TextBuffer;
    FHL.ScanAllRanges;

    Subs:=0;
    for Cnt:=0 to Ed.Lines.Count-1 do
      if Copy(Ed.Lines[Cnt],1,4)='sub ' then
      begin
        Inc(Subs);
        Where:='line '+IntToStr(Cnt+1)+' "'+Ed.Lines[Cnt]+'"';
        AssertEquals(Where+' opens one fold',1,FHL.FoldBlockOpeningCount(Cnt));
        Last:=Cnt+FHL.FoldLineLength(Cnt,0);
        AssertEquals(Where+' fold ends on line '+IntToStr(Last+1)+' "'+Ed.Lines[Last]+'"',
          'return',Copy(Ed.Lines[Last],1,6));
      end;
    AssertTrue('found the subs',Subs>50);
  finally
    Ed.Highlighter:=nil;
    Ed.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFoldSynTests.TestColoringMatchesPlainTSynUniSyn;
var
  Plain     : TSynUniSyn;
  Src       : TStringList;
  Cnt       : Integer;
  PRange    : Pointer;
  FRange    : Pointer;
  PA, FA    : TSynHighlighterAttributes;
  Where, FN : String;
  Tokens    : Integer;
begin
  FN:=ExtractFilePath(ParamStr(0))+'..\tools\EUOSelfTest\EUOSelfTest.euo';
  AssertTrue('fixture missing: '+FN,FileExists(FN));
  Plain:=TSynUniSyn.Create(nil);
  Src:=TStringList.Create;
  try
    BuildEUOHighlighter(Plain);
    Src.LoadFromFile(FN);
    Src.Add('set %a $FF , -12 , "str" ; comment');
    Src.Add('set !ns *pers #charposx {');

    Plain.ResetRange;
    FHL.ResetRange;
    PRange:=nil;
    FRange:=nil;
    Tokens:=0;
    for Cnt:=0 to Src.Count-1 do
    begin
      if Cnt>0 then
      begin
        Plain.SetRange(PRange);
        FHL.SetRange(FRange);
      end;
      Plain.SetLine(Src[Cnt],Cnt);
      FHL.SetLine(Src[Cnt],Cnt);
      repeat
        Where:='line '+IntToStr(Cnt+1)+' token '+IntToStr(Tokens);
        AssertEquals(Where+' eol',Plain.GetEol,FHL.GetEol);
        if Plain.GetEol then Break;
        AssertEquals(Where+' text',Plain.GetToken,FHL.GetToken);
        AssertEquals(Where+' pos',Plain.GetTokenPos,FHL.GetTokenPos);
        AssertEquals(Where+' kind',Plain.GetTokenKind,FHL.GetTokenKind);
        PA:=Plain.GetTokenAttribute;
        FA:=FHL.GetTokenAttribute;
        AssertEquals(Where+' attr assigned',Assigned(PA),Assigned(FA));
        if Assigned(PA) then
        begin
          AssertEquals(Where+' attr name',PA.StoredName,FA.StoredName);
          AssertEquals(Where+' fore',Integer(PA.Foreground),Integer(FA.Foreground));
          AssertEquals(Where+' back',Integer(PA.Background),Integer(FA.Background));
          AssertTrue(Where+' style',PA.Style=FA.Style);
        end;
        Inc(Tokens);
        Plain.Next;
        FHL.Next;
      until False;
      PRange:=Plain.GetRange;
      FRange:=FHL.GetRange;
    end;
    AssertTrue('scanned some tokens',Tokens>1000);
  finally
    Src.Free;
    Plain.Free;
  end;
end;

initialization
  RegisterTest(TEuoFoldSynTests);
end.
