unit EuoOutlineTests;

{
  Tests for EuoOutline.pas -- the index behind the editor's outline panel: which lines are
  subs, labels and MENU windows, where each one's range ends (code folding's rules), which
  subs no GOSUB reaches, which entry the caret is in, and the rows a filter and the A-Z
  order leave. See EuoOutline.pas's header comment for the rules.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoOutline;

type
  TEuoOutlineTests = class(TTestCase)
  private
    function  Build(const Src : array of String) : TEuoOutline;
    // the entries as 'Text@Line-LastLine^Parent', Line 0-based, '!' for an unused sub
    function  Dump(const Items : TEuoOutline) : String;
    function  RowsText(const Items : TEuoOutline; const Rows : TEuoOutlineRows) : String;
  published
    procedure TestEmptyScript;
    procedure TestSubsEndAtTheirReturn;
    procedure TestNextSubEndsAnUnclosedSub;
    procedure TestBracedSubEndsAtItsBrace;
    procedure TestEarlyReturnDoesNotEndTheSub;
    procedure TestLabelsNestInTheirSub;
    procedure TestLabelForms;
    procedure TestContinuationLinesAddNothing;
    procedure TestMenuWindows;
    procedure TestUnusedSubs;
    procedure TestRunTimeGosubNamesDoNotCount;
    procedure TestLaterSubOfTheSameNameWins;
    procedure TestItemAtFollowsTheCaret;
    procedure TestRowsInScriptOrder;
    procedure TestRowsFilterKeepsTheSub;
    procedure TestRowsSortedByName;
    procedure TestSelfTestScript;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineTests.Build(const Src : array of String) : TEuoOutline;
var
  SL  : TStringList;
  Cnt : Integer;
begin
  SL:=TStringList.Create;
  try
    for Cnt:=Low(Src) to High(Src) do
      SL.Add(Src[Cnt]);
    EuoBuildOutline(SL,Result);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineTests.Dump(const Items : TEuoOutline) : String;
var
  Cnt : Integer;
begin
  Result:='';
  for Cnt:=0 to High(Items) do
  begin
    if Result<>'' then Result:=Result+' | ';
    Result:=Result+Items[Cnt].Text+'@'+IntToStr(Items[Cnt].Line)+'-'+IntToStr(Items[Cnt].LastLine)+
      '^'+IntToStr(Items[Cnt].Parent);
    if Items[Cnt].Unused then Result:=Result+'!';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoOutlineTests.RowsText(const Items : TEuoOutline; const Rows : TEuoOutlineRows) : String;
var
  Cnt : Integer;
begin
  Result:='';
  for Cnt:=0 to High(Rows) do
  begin
    if Result<>'' then Result:=Result+' | ';
    if Rows[Cnt].Depth>0 then Result:=Result+'  ';
    Result:=Result+Items[Rows[Cnt].Item].Text;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestEmptyScript;
begin
  AssertEquals(0,Length(Build([])));
  AssertEquals(0,Length(Build(['set %a 1','halt'])));
  AssertEquals(-1,EuoOutlineItemAt(Build(['set %a 1']),0));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestSubsEndAtTheirReturn;
begin
  AssertEquals('sub one@3-5^-1 | sub two@7-9^-1!',
    Dump(Build(['gosub one',     // 0
                'halt',          // 1
                '',              // 2
                'sub one',       // 3
                '  set %a 1',    // 4
                'return',        // 5
                '',              // 6
                'sub two',       // 7
                '  set %b 2',    // 8
                'return'])));    // 9
end;

////////////////////////////////////////////////////////////////////////////////
// Subs do not nest: the next SUB is where the code of one without a RETURN stops, and the
// last one runs to the end of the script.
procedure TEuoOutlineTests.TestNextSubEndsAnUnclosedSub;
begin
  AssertEquals('sub one@0-2^-1! | sub two@3-5^-1!',
    Dump(Build(['sub one','  set %a 1','','sub two','  set %b 2',''])));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestBracedSubEndsAtItsBrace;
begin
  AssertEquals('sub one@0-3^-1! | after:@4-5^-1',
    Dump(Build(['sub one','{','  set %a 1','}','after:','halt'])));
end;

////////////////////////////////////////////////////////////////////////////////
// A RETURN inside braces, or as the one-line body of an IF, leaves the sub open (EuoBlocks).
procedure TEuoOutlineTests.TestEarlyReturnDoesNotEndTheSub;
begin
  AssertEquals('sub one@0-8^-1! | inner:@7-8^0',
    Dump(Build(['sub one',        // 0
                'if %a = 1',      // 1
                '  return',       // 2
                'if %b = 1',      // 3
                '{',              // 4
                '  return',       // 5
                '}',              // 6
                'inner:',         // 7
                'return'])));     // 8
end;

////////////////////////////////////////////////////////////////////////////////
// A label in a sub's range is its entry and runs to the next entry beside it; one between
// subs (or before them) is at the top level and runs to the next sub.
procedure TEuoOutlineTests.TestLabelsNestInTheirSub;
begin
  AssertEquals('main:@0-3^-1 | sub work@4-10^-1 | first:@5-7^1 | second:@8-10^1 | between:@11-12^-1',
    Dump(Build(['main:',          // 0
                '  gosub work',   // 1
                '  goto main',    // 2
                '',               // 3
                'sub work',       // 4
                'first:',         // 5
                '  set %a 1',     // 6
                '  goto second',  // 7
                'second:',        // 8
                '  set %b 1',     // 9
                'return',         // 10
                'between:',       // 11
                'halt'])));       // 12
end;

////////////////////////////////////////////////////////////////////////////////
// GoToProc's test: the command (cut at a space, a tab or ';') ends with ':'. The text keeps
// the case and indentation-free spelling of the script.
procedure TEuoOutlineTests.TestLabelForms;
var
  O : TEuoOutline;
begin
  O:=Build(['  Loop1:','loop2: ; comment','loop3:;x','  :','set:x 1','loop4: set %a 1']);
  AssertEquals('Loop1:@0-0^-1 | loop2:@1-1^-1 | loop3:@2-4^-1 | loop4:@5-5^-1',Dump(O));
  AssertEquals('Loop1',O[0].Name);
  AssertTrue(O[0].Kind=eokLabel);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestContinuationLinesAddNothing;
begin
  AssertEquals('sub one@0-3^-1!',
    Dump(Build(['sub one','set %a 1','+ notalabel:','return'])));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestMenuWindows;
var
  O : TEuoOutline;
begin
  O:=Build(['gosub showmenu',                 // 0
            'halt',                           // 1
            'sub showmenu',                   // 2
            'menu clear',                     // 3
            'menu Window Title My  Script %v',// 4
            'menu window size 200 100',       // 5
            'menu show',                      // 6
            'menu form opts 1 2 3 4 Options', // 7
            'return',                         // 8
            'menu window title',              // 9
            'menu form',                      // 10
            'halt']);                         // 11
  AssertEquals('sub showmenu@2-8^-1 | menu My Script %v@4-6^0 | menu form opts@7-8^0 | menu window@9-11^-1',Dump(O));
  AssertTrue(O[1].Kind=eokMenu);
  AssertEquals('My Script %v',O[1].Name);
  AssertEquals('opts',O[2].Name);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestUnusedSubs;
var
  O : TEuoOutline;
begin
  O:=Build(['gosub ONE',
            'if %a',
            '  gosub two 1 2',
            '; gosub three',
            'halt',
            'sub one',
            'return',
            'sub Two',
            'return',
            'sub three',
            'return',
            'sub',
            'return']);
  AssertEquals('sub one@5-6^-1 | sub Two@7-8^-1 | sub three@9-10^-1! | sub@11-12^-1!',Dump(O));
end;

////////////////////////////////////////////////////////////////////////////////
// The names Ctrl+click can't follow (EuoStaticJumpName) don't make a sub used.
procedure TEuoOutlineTests.TestRunTimeGosubNamesDoNotCount;
var
  O : TEuoOutline;
begin
  O:=Build(['gosub %next',
            'gosub a . %b',
            'gosub c',
            '+ d',
            'goto e',
            'halt',
            'sub a',
            'return',
            'sub c',
            'return',
            'sub e',
            'return']);
  AssertTrue('a',O[0].Unused);
  AssertTrue('c',O[1].Unused);
  AssertTrue('e (only a goto)',O[2].Unused);
end;

////////////////////////////////////////////////////////////////////////////////
// GOSUB runs the last sub of a name, so the earlier one is never reached.
procedure TEuoOutlineTests.TestLaterSubOfTheSameNameWins;
begin
  AssertEquals('sub twin@2-3^-1! | sub TWIN@4-5^-1',
    Dump(Build(['gosub twin','halt','sub twin','return','sub TWIN','return'])));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestItemAtFollowsTheCaret;
var
  O : TEuoOutline;
begin
  O:=Build(['set %a 1',       // 0
            'main:',          // 1
            '  gosub work',   // 2
            'halt',           // 3
            'sub work',       // 4
            '  set %a 1',     // 5
            'inner:',         // 6
            '  set %b 1',     // 7
            'return',         // 8
            '',               // 9
            'sub other',      // 10
            'return']);       // 11
  AssertEquals('before any entry',-1,EuoOutlineItemAt(O,0));
  AssertEquals('main:',0,EuoOutlineItemAt(O,1));
  AssertEquals('main: runs to the sub',0,EuoOutlineItemAt(O,3));
  AssertEquals('the sub line',1,EuoOutlineItemAt(O,4));
  AssertEquals('the sub before its label',1,EuoOutlineItemAt(O,5));
  AssertEquals('the label',2,EuoOutlineItemAt(O,6));
  AssertEquals('the label to the return',2,EuoOutlineItemAt(O,8));
  AssertEquals('between subs',-1,EuoOutlineItemAt(O,9));
  AssertEquals('the next sub',3,EuoOutlineItemAt(O,11));
  AssertEquals('past the end',-1,EuoOutlineItemAt(O,12));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestRowsInScriptOrder;
var
  O : TEuoOutline;
begin
  O:=Build(['start:','sub b','b2:','b1:','return','sub a','return']);
  AssertEquals('start: | sub b |   b2: |   b1: | sub a',RowsText(O,EuoOutlineRows(O,[],False)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutlineTests.TestRowsFilterKeepsTheSub;
var
  O     : TEuoOutline;
  Match : array of Boolean;
begin
  O:=Build(['start:','sub b','b2:','b1:','return','sub a','return']);
  // start:, sub b, b2:, b1:, sub a
  SetLength(Match,5);
  Match[3]:=True;   // b1:
  AssertEquals('sub b |   b1:',RowsText(O,EuoOutlineRows(O,Match,False)));
  Match[3]:=False;
  Match[1]:=True;   // sub b alone: its labels stay out
  Match[4]:=True;
  AssertEquals('sub b | sub a',RowsText(O,EuoOutlineRows(O,Match,False)));
  Match[1]:=False;
  Match[4]:=False;
  AssertEquals('',RowsText(O,EuoOutlineRows(O,Match,False)));
end;

////////////////////////////////////////////////////////////////////////////////
// By name, ignoring case, beside each other only; the same name keeps the script order.
procedure TEuoOutlineTests.TestRowsSortedByName;
var
  O : TEuoOutline;
begin
  O:=Build(['Zeta:','sub b','b2:','B1:','return','sub A','return','alpha:','sub b','return']);
  AssertEquals('sub A | alpha: | sub b |   B1: |   b2: | sub b | Zeta:',
    RowsText(O,EuoOutlineRows(O,[],True)));
  AssertEquals('the earlier of two equal names comes first',1,EuoOutlineRows(O,[],True)[2].Item);
end;

////////////////////////////////////////////////////////////////////////////////
// A real script: one entry per sub line, every sub in a sub's range only through its labels,
// and the ranges in order.
procedure TEuoOutlineTests.TestSelfTestScript;
var
  SL       : TStringList;
  O        : TEuoOutline;
  FN       : String;
  Cnt, N   : Integer;
  Last     : Integer;
begin
  SL:=TStringList.Create;
  try
    FN:=ExtractFilePath(ParamStr(0))+'..\tools\EUOSelfTest\EUOSelfTest.euo';
    AssertTrue('fixture missing: '+FN,FileExists(FN));
    SL.LoadFromFile(FN);
    EuoBuildOutline(SL,O);

    N:=0;
    for Cnt:=0 to SL.Count-1 do
      if LowerCase(Copy(TrimLeft(SL[Cnt]),1,4))='sub ' then Inc(N);
    AssertTrue('the script has subs',N>100);

    Last:=-1;
    for Cnt:=0 to High(O) do
    begin
      AssertTrue('in line order at '+O[Cnt].Text,O[Cnt].Line>Last);
      Last:=O[Cnt].Line;
      AssertTrue('a range at '+O[Cnt].Text,O[Cnt].LastLine>=O[Cnt].Line);
      if O[Cnt].Kind=eokSub then
      begin
        Dec(N);
        AssertEquals('a sub is top level',-1,O[Cnt].Parent);
      end
      else if O[Cnt].Parent>=0 then
        AssertTrue('inside its sub: '+O[Cnt].Text,
          O[Cnt].LastLine<=O[O[Cnt].Parent].LastLine);
    end;
    AssertEquals('one entry per sub line',0,N);
  finally
    SL.Free;
  end;
end;

initialization
  RegisterTest(TEuoOutlineTests);
end.
