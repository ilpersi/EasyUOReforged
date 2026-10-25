unit EuoFindTests;

{
  Tests for easyuo\eufind.pas -- the search behind the editor's Find/Replace
  window: direction and wrap-around, match case / whole word / regex, the
  Selection and All-scripts scopes, match counting, Replace / Replace All
  (with the prompt's answers counted), the search history and the highlight
  markup's handling of empty regex matches. Everything runs against real,
  never-shown TSynEdits, as EuoCompleteTests does.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, SynEdit, SynEditTypes, eufind;

type
  TEuoFindTests = class(TTestCase)
  private
    FEds     : TList;
    FAnswers : array of TSynReplaceAction;
    FAsked   : Integer;
    function  NewEd(const Text : String) : TSynEdit;
    function  Settings(const Find : String) : TFindSettings;
    procedure Select(Ed : TSynEdit; BX, BY, EX, EY : Integer);
    procedure AssertSel(const Msg : String; Ed : TSynEdit; BX, BY, EX, EY : Integer);
    procedure AnswerReplace(Sender : TObject; const ASearch, AReplace : String;
                Line, Column : Integer; var ReplaceAction : TSynReplaceAction);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestForwardBackwardAndWrap;
    procedure TestNoWrapStopsAtTheEnd;
    procedure TestMatchCase;
    procedure TestWholeWord;
    procedure TestRegexAndDollarReplace;
    procedure TestInvalidRegex;
    procedure TestZeroLengthRegexMovesOn;
    procedure TestSelectionScope;
    procedure TestAllScripts;
    procedure TestCountIndex;
    procedure TestReplaceCurrent;
    procedure TestReplaceCurrentKeepsTheRange;
    procedure TestReplaceAll;
    procedure TestReplaceAllCountsPromptAnswers;
    procedure TestHistory;
    procedure TestSynOptions;
    procedure TestHighlightSkipsEmptyMatches;
  end;

implementation

type
  // reaches TEuoHighlightAll's protected search, which otherwise only runs on paint
  THighlightProbe = class(TEuoHighlightAll);

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.SetUp;
begin
  FEds:=TList.Create;
  FAsked:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TearDown;
var
  i : Integer;
begin
  for i:=0 to FEds.Count-1 do
    TSynEdit(FEds[i]).Free;
  FEds.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindTests.NewEd(const Text : String) : TSynEdit;
begin
  Result:=TSynEdit.Create(nil);
  FEds.Add(Result);
  Result.Lines.Text:=Text;
  Result.LogicalCaretXY:=Point(1,1);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoFindTests.Settings(const Find : String) : TFindSettings;
begin
  Result:=Default(TFindSettings);
  Result.FindText:=Find;
  Result.WrapAround:=True;
  Result.Scope:=fsScript;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.Select(Ed : TSynEdit; BX, BY, EX, EY : Integer);
begin
  Ed.BlockBegin:=Point(BX,BY);
  Ed.BlockEnd:=Point(EX,EY);
  Ed.LogicalCaretXY:=Point(EX,EY);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.AssertSel(const Msg : String; Ed : TSynEdit; BX, BY, EX, EY : Integer);
begin
  AssertEquals(Msg+': start',Format('%d,%d',[BX,BY]),Format('%d,%d',[Ed.BlockBegin.X,Ed.BlockBegin.Y]));
  AssertEquals(Msg+': end',Format('%d,%d',[EX,EY]),Format('%d,%d',[Ed.BlockEnd.X,Ed.BlockEnd.Y]));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.AnswerReplace(Sender : TObject; const ASearch, AReplace : String;
  Line, Column : Integer; var ReplaceAction : TSynReplaceAction);
begin
  ReplaceAction:=FAnswers[FAsked];
  Inc(FAsked);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestForwardBackwardAndWrap;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
begin
  Ed:=NewEd('set %a #findid'+LineEnding+'finditem %a'+LineEnding+'set %b #FINDID');
  S:=Settings('findid');
  ClearState(St);

  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('first',Ed,9,1,15,1);
  AssertEquals('the selection is the match','findid',Ed.SelText);
  AssertFalse(Hit.Wrapped);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('second, ignoring case',Ed,9,3,15,3);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('wrapped to the top',Ed,9,1,15,1);
  AssertTrue('wrapped',Hit.Wrapped);

  S.Backwards:=True;
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('backwards wraps to the bottom',Ed,9,3,15,3);
  AssertTrue('wrapped',Hit.Wrapped);
  AssertEquals('backwards leaves the caret at the start',9,Ed.LogicalCaretXY.X);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('backwards',Ed,9,1,15,1);
  AssertFalse(Hit.Wrapped);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestNoWrapStopsAtTheEnd;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
begin
  Ed:=NewEd('x'+LineEnding+'y');
  S:=Settings('x');
  S.WrapAround:=False;
  ClearState(St);
  Ed.LogicalCaretXY:=Point(1,2);
  AssertFalse('nothing after the caret',FindNext([Ed],0,S,St,Hit));
  AssertEquals('caret left alone',2,Ed.LogicalCaretXY.Y);
  AssertFalse(Ed.SelAvail);

  S.WrapAround:=True;
  AssertTrue('found from the top',FindNext([Ed],0,S,St,Hit));
  AssertSel('wrapped',Ed,1,1,2,1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestMatchCase;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('set %a #findid'+LineEnding+'set %b #FINDID');
  S:=Settings('FINDID');
  S.MatchCase:=True;
  ClearState(St);
  AssertEquals(1,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('only the upper-case one',Ed,9,2,15,2);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestWholeWord;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('set %i 1'+LineEnding+'set %item 2'+LineEnding+'for %i 1 5');
  S:=Settings('%i');
  S.WholeWord:=True;
  ClearState(St);
  AssertEquals('not inside %item',2,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('first',Ed,5,1,7,1);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('skips %item',Ed,5,3,7,3);

  Ed:=NewEd('set %a #findid'+LineEnding+'set %b #findidx');
  S:=Settings('findid');
  S.WholeWord:=True;
  AssertEquals('a sigil is a word boundary, a letter is not',1,CountMatches([Ed],0,S,St,Idx));
  S.FindText:='#findid';
  AssertEquals('the sigil can be part of the word',1,CountMatches([Ed],0,S,St,Idx));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestRegexAndDollarReplace;
var
  C   : Boolean;
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('set %hp 10'+LineEnding+'set %mana 20'+LineEnding+'display %hp');
  S:=Settings('^set (%\w+)');
  S.RegExpr:=True;
  S.ReplaceText:='var $1';
  ClearState(St);
  AssertEquals(2,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('first',Ed,1,1,8,1);
  AssertEquals(2,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('var %hp 10',Ed.Lines[0]);
  AssertEquals('var %mana 20',Ed.Lines[1]);
  AssertEquals('display %hp',Ed.Lines[2]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestInvalidRegex;
var
  S   : TFindSettings;
  Msg : String;
begin
  S:=Settings('set (');
  AssertTrue('plain text is never invalid',CheckPattern(S,Msg));
  S.RegExpr:=True;
  AssertFalse(CheckPattern(S,Msg));
  AssertTrue('a message for the status line',Msg<>'');
  AssertEquals('without the engine''s prefixes',0,Pos('TRegExpr',Msg));
  AssertEquals(0,Pos(':',Msg));
  S.FindText:='set (%\w+)';
  AssertTrue(CheckPattern(S,Msg));
  AssertEquals('',Msg);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestZeroLengthRegexMovesOn;
var
  C   : Boolean;
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('a'+LineEnding+'b'+LineEnding+'c');
  S:=Settings('^');
  S.RegExpr:=True;
  ClearState(St);
  AssertEquals(3,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertEquals('moved off the match at the caret',2,Ed.LogicalCaretXY.Y);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertEquals(3,Ed.LogicalCaretXY.Y);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertEquals('wrapped to the top',1,Ed.LogicalCaretXY.Y);
  AssertTrue(Hit.Wrapped);

  // SynEdit's own replace loop over empty matches ends, too. It passes over
  // an empty line (its FixRange moves a start there on to the next line), so
  // commenting out a block with ^ -> "; " leaves the block's empty lines be.
  Ed:=NewEd('a'+LineEnding+''+LineEnding+'c');
  S.ReplaceText:='; ';
  AssertEquals(2,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('; a',Ed.Lines[0]);
  AssertEquals('',Ed.Lines[1]);
  AssertEquals('; c',Ed.Lines[2]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestSelectionScope;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('set %a 1'+LineEnding+'set %b 2'+LineEnding+'set %c 3'+LineEnding+'set %d 4');
  S:=Settings('set');
  S.Scope:=fsSelection;
  ClearState(St);
  AssertFalse('no selection, no range',FindNext([Ed],0,S,St,Hit));
  AssertEquals(0,CountMatches([Ed],0,S,St,Idx));

  Select(Ed,1,2,9,3);
  AssertEquals('only inside the selection',2,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('starts at the top of the range',Ed,1,2,4,2);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('the match did not become the range',Ed,1,3,4,3);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('wraps inside the range',Ed,1,2,4,2);
  AssertTrue(Hit.Wrapped);
  AssertEquals(2,CountMatches([Ed],0,S,St,Idx));
  AssertEquals(1,Idx);

  Select(Ed,1,4,9,4);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('a new selection is a new range',Ed,1,4,4,4);
  AssertEquals(1,CountMatches([Ed],0,S,St,Idx));

  Ed.LogicalCaretXY:=Point(1,1);
  AssertTrue('a click elsewhere keeps the range',FindNext([Ed],0,S,St,Hit));
  AssertSel('still the last range',Ed,1,4,4,4);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestAllScripts;
var
  E0, E1, E2 : TSynEdit;
  S          : TFindSettings;
  St         : TFindState;
  Hit        : TFindHit;
begin
  E0:=NewEd('a x');
  E1:=NewEd('b');
  E2:=NewEd('x c');
  S:=Settings('x');
  S.Scope:=fsAllScripts;
  ClearState(St);

  AssertTrue(FindNext([E0,E1,E2],1,S,St,Hit));
  AssertEquals('the next script with a match',2,Hit.Index);
  AssertFalse(Hit.Wrapped);
  AssertSel('selected there',E2,1,1,2,1);

  AssertTrue(FindNext([E0,E1,E2],2,S,St,Hit));
  AssertEquals('round to the first script',0,Hit.Index);
  AssertTrue(Hit.Wrapped);
  AssertSel('selected there',E0,3,1,4,1);

  S.WrapAround:=False;
  AssertFalse('no wrap: the last script ends it',FindNext([E0,E1,E2],2,S,St,Hit));

  E1.LogicalCaretXY:=Point(1,1);
  S.Backwards:=True;
  AssertTrue(FindNext([E0,E1,E2],1,S,St,Hit));
  AssertEquals('backwards: the script before',0,Hit.Index);
  AssertFalse(Hit.Wrapped);

  S.Scope:=fsScript;
  S.WrapAround:=True;
  AssertFalse('Script scope stays in its own script',FindNext([E0,E1,E2],1,S,St,Hit));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestCountIndex;
var
  E0, E1 : TSynEdit;
  S      : TFindSettings;
  St     : TFindState;
  Hit    : TFindHit;
  Idx    : Integer;
begin
  E0:=NewEd('x x'+LineEnding+'x');
  E1:=NewEd('x');
  S:=Settings('x');
  ClearState(St);
  AssertEquals(3,CountMatches([E0,E1],0,S,St,Idx));
  AssertEquals('nothing selected',0,Idx);
  AssertTrue(FindNext([E0,E1],0,S,St,Hit));
  AssertTrue(FindNext([E0,E1],0,S,St,Hit));
  AssertEquals(3,CountMatches([E0,E1],0,S,St,Idx));
  AssertEquals('second of three',2,Idx);

  S.Scope:=fsAllScripts;
  E1.LogicalCaretXY:=Point(1,1);
  AssertTrue(FindNext([E0,E1],1,S,St,Hit));
  AssertEquals(4,CountMatches([E0,E1],1,S,St,Idx));
  AssertEquals('after the three in the first script',4,Idx);

  Select(E0,1,1,4,1);
  CountMatches([E0,E1],0,S,St,Idx);
  AssertEquals('a selection that is not a match',0,Idx);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestReplaceCurrent;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
begin
  Ed:=NewEd('set %a 1'+LineEnding+'set %a 2');
  S:=Settings('%a');
  S.ReplaceText:='%b';
  ClearState(St);
  AssertFalse('nothing selected yet',ReplaceCurrent(Ed,S,St));
  AssertEquals('set %a 1',Ed.Lines[0]);

  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertTrue(ReplaceCurrent(Ed,S,St));
  AssertEquals('set %b 1',Ed.Lines[0]);
  AssertEquals('the replacement stays selected','%b',Ed.SelText);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('the next one',Ed,5,2,7,2);
  AssertTrue(ReplaceCurrent(Ed,S,St));
  AssertEquals('set %b 2',Ed.Lines[1]);

  Ed.Undo;
  AssertEquals('one undo per replacement','set %a 2',Ed.Lines[1]);
  AssertEquals('set %b 1',Ed.Lines[0]);

  Select(Ed,1,1,4,1);
  AssertFalse('a selection that is not a match is left alone',ReplaceCurrent(Ed,S,St));
  AssertEquals('set %b 1',Ed.Lines[0]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestReplaceCurrentKeepsTheRange;
var
  Ed  : TSynEdit;
  S   : TFindSettings;
  St  : TFindState;
  Hit : TFindHit;
  Idx : Integer;
begin
  Ed:=NewEd('x x x'+LineEnding+'x');
  S:=Settings('x');
  S.ReplaceText:='yyy';
  S.Scope:=fsSelection;
  ClearState(St);
  Select(Ed,1,1,6,1);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertTrue(ReplaceCurrent(Ed,S,St));
  AssertEquals('yyy x x',Ed.Lines[0]);
  AssertEquals('the range grew with the line',2,CountMatches([Ed],0,S,St,Idx));
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('the next x',Ed,5,1,6,1);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('the last x in the range',Ed,7,1,8,1);
  AssertTrue(FindNext([Ed],0,S,St,Hit));
  AssertSel('wrapped, line 2 is outside',Ed,5,1,6,1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestReplaceAll;
var
  C  : Boolean;
  Ed : TSynEdit;
  S  : TFindSettings;
  St : TFindState;
begin
  Ed:=NewEd('x x'+LineEnding+'x');
  Ed.LogicalCaretXY:=Point(1,2);
  S:=Settings('x');
  S.ReplaceText:='yy';
  ClearState(St);
  AssertEquals('the whole script, wherever the caret is',3,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('yy yy',Ed.Lines[0]);
  AssertEquals('yy',Ed.Lines[1]);
  Ed.Undo;
  AssertEquals('one undo for all of it','x x',Ed.Lines[0]);
  AssertEquals('x',Ed.Lines[1]);

  // Find Next first: the old dialog's Replace All then only replaced that one match
  Ed:=NewEd('x'+LineEnding+'x'+LineEnding+'x'+LineEnding+'x');
  Select(Ed,1,2,2,2);
  AssertEquals(4,ReplaceAllIn(Ed,S,St,C));

  Ed:=NewEd('x'+LineEnding+'x'+LineEnding+'x'+LineEnding+'x');
  S.Scope:=fsSelection;
  Select(Ed,1,2,2,3);
  AssertEquals('only inside the selection',2,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('x',Ed.Lines[0]);
  AssertEquals('yy',Ed.Lines[1]);
  AssertEquals('yy',Ed.Lines[2]);
  AssertEquals('x',Ed.Lines[3]);
  AssertSel('the range is selected again',Ed,1,2,3,3);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestReplaceAllCountsPromptAnswers;
var
  C  : Boolean;
  Ed : TSynEdit;
  S  : TFindSettings;
  St : TFindState;
begin
  Ed:=NewEd('x x x x x');
  Ed.OnReplaceText:=AnswerReplace;
  S:=Settings('x');
  S.ReplaceText:='y';
  S.PromptOnReplace:=True;
  ClearState(St);
  SetLength(FAnswers,3);
  FAnswers[0]:=raSkip;
  FAnswers[1]:=raReplace;
  FAnswers[2]:=raReplaceAll;
  AssertEquals('skipped one, replaced one, then the other three',4,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('x y y y y',Ed.Lines[0]);
  AssertFalse(C);
  AssertEquals('no more prompts after Yes to All',3,FAsked);
  AssertTrue('the editor''s own handler is back',TMethod(Ed.OnReplaceText).Data=Pointer(Self));

  Ed:=NewEd('x x x');
  Ed.OnReplaceText:=AnswerReplace;
  FAsked:=0;
  SetLength(FAnswers,2);
  FAnswers[0]:=raReplace;
  FAnswers[1]:=raCancel;
  AssertEquals('cancelled after one',1,ReplaceAllIn(Ed,S,St,C));
  AssertEquals('y x x',Ed.Lines[0]);
  AssertTrue('Cancel is reported',C);

  S.PromptOnReplace:=False;
  FAsked:=0;
  AssertEquals('no prompt',2,ReplaceAllIn(Ed,S,St,C));
  AssertEquals(0,FAsked);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestHistory;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    AddToHistory(L,'a');
    AddToHistory(L,'b');
    AddToHistory(L,'a');
    AssertEquals('most recent first, no duplicates','a,b',L.CommaText);
    AddToHistory(L,'A');
    AssertEquals('case matters','A,a,b',L.CommaText);
    AddToHistory(L,'');
    AssertEquals('an empty search is not kept',3,L.Count);
    for i:=1 to 30 do
      AddToHistory(L,'s'+IntToStr(i));
    AssertEquals(MaxHistory,L.Count);
    AssertEquals('s30',L[0]);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoFindTests.TestSynOptions;
var
  S : TFindSettings;
begin
  S:=Settings('x');
  AssertTrue(SynOptions(S)=[]);
  S.MatchCase:=True;
  S.WholeWord:=True;
  S.RegExpr:=True;
  S.Backwards:=True;
  S.WrapAround:=False;
  S.PromptOnReplace:=True;
  AssertTrue(SynOptions(S)=[ssoMatchCase,ssoWholeWord,ssoRegExpr,ssoBackwards]);
end;

////////////////////////////////////////////////////////////////////////////////
// SynEdit's own highlight markup finds an empty match (^, x*) again and again
// for ever; TEuoHighlightAll steps over it and paints nothing for it.
procedure TEuoFindTests.TestHighlightSkipsEmptyMatches;
var
  Ed  : TSynEdit;
  M   : THighlightProbe;
  Idx : Integer;

  function Painted(const Pattern : String; Options : TSynSearchOptions; Backward : Boolean = False) : Integer;
  begin
    SetFindHighlight(Ed,Pattern,Options);
    M.FindInitialize;
    Idx:=0;
    M.FindMatches(Point(1,1),Point(9,3),Idx,-1,Backward);
    Result:=Idx;
  end;

begin
  Ed:=NewEd('set %a 1'+LineEnding+''+LineEnding+'set %b 2');
  SetFindHighlight(Ed,'set',[]);
  M:=THighlightProbe(Ed.MarkupByClass[TEuoHighlightAll]);
  AssertNotNull('added on first use',M);
  AssertEquals(2,Painted('set',[]));
  AssertEquals('only empty matches: nothing, and it ends',0,Painted('^',[ssoRegExpr]));
  AssertEquals(0,Painted('^$',[ssoRegExpr]));
  AssertEquals('empty and real matches mixed',2,Painted('\d*',[ssoRegExpr]));
  AssertEquals('backwards ends too',True,Painted('x*',[ssoRegExpr],True)>=0);
  SetFindHighlight(Ed,'',[]);
  AssertTrue('cleared, the same markup stays',Ed.MarkupByClass[TEuoHighlightAll]=M);
end;

initialization
  RegisterTest(TEuoFindTests);
end.
