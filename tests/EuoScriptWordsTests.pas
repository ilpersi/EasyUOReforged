unit EuoScriptWordsTests;

{
  EuoScriptWords: ParseLine's continuation join, '.'/',' glue with its substitution hook, IsVar
  and the TParList fill, as the MENU designer calls them. ParseLine itself, which calls the same
  code, stays pinned by EuoInterpreterTests and the golden corpus.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoTokens, EuoScriptWords;

type
  TEuoScriptWordsTests = class(TTestCase)
  private
    Values : TStringList;
    function Subst(Str : String) : String;
    function Glue(const Line : String; WithSubst, KeepFirstArg : Boolean) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIsVar;
    procedure TestJoinContinuation;
    procedure TestJoinAtLastLine;
    procedure TestDotGlue;
    procedure TestDotAtEdgesStays;
    procedure TestCommaGlue;
    procedure TestConsecutiveCommas;
    procedure TestNoSubstitutionWithoutHook;
    procedure TestArrayIdiom;
    procedure TestKeepFirstArg;
    procedure TestCommaAfterSubstitution;
    procedure TestSubstitutedDotIsNotGlued;
    procedure TestWordsToParList;
    procedure TestScanLineWordsColumns;
    procedure TestScanLineWordsStopsAtAComment;
    procedure TestScanLineWordsAgreesWithParameterize;
  end;

implementation

procedure TEuoScriptWordsTests.SetUp;
begin
  Values:=TStringList.Create;
  Values.Values['%i']:='3';
  Values.Values['%list3']:='third';
  Values.Values['%a']:='A';
  Values.Values['%b']:='B';
  Values.Values['#dot']:='.';
  Values.Values['#comma']:=',';
end;

procedure TEuoScriptWordsTests.TearDown;
begin
  Values.Free;
end;

function TEuoScriptWordsTests.Subst(Str : String) : String;
begin
  if Values.IndexOfName(Str)>=0 then Result:=Values.Values[Str]
  else Result:='N/A';
end;

// The line split on single spaces, glued, and joined back with '|'.
function TEuoScriptWordsTests.Glue(const Line : String; WithSubst, KeepFirstArg : Boolean) : String;
var
  Words : TStringList;
begin
  Words:=TStringList.Create;
  try
    Words.Delimiter:=' ';
    Words.StrictDelimiter:=True;
    Words.DelimitedText:=Line;
    if WithSubst then GlueWords(Words,Subst,KeepFirstArg)
    else GlueWords(Words,nil,KeepFirstArg);
    Words.Delimiter:='|';
    Result:=Words.DelimitedText;
  finally
    Words.Free;
  end;
end;

procedure TEuoScriptWordsTests.TestIsVar;
begin
  AssertTrue(IsVar('%a'));
  AssertTrue(IsVar('#true'));
  AssertTrue(IsVar('!x_1'));
  AssertTrue(IsVar('*1'));
  AssertFalse('a lone sigil', IsVar('%'));
  AssertFalse('a dot inside', IsVar('%a.b'));
  AssertFalse('no sigil first', IsVar('a%'));
  AssertFalse('a semicolon', IsVar('#a;'));
end;

procedure TEuoScriptWordsTests.TestJoinContinuation;
var
  L     : TStringList;
  Index : Integer;
begin
  L:=TStringList.Create;
  try
    L.Text:='  menu text t 0 0 a b'#13#10'  + c'#13#10'+d'#13#10'menu show';
    Index:=0;
    AssertEquals('menu text t 0 0 a b cd', JoinContinuation(L,Index));
    AssertEquals('the first line not joined', 3, Index);
  finally
    L.Free;
  end;
end;

procedure TEuoScriptWordsTests.TestJoinAtLastLine;
var
  L     : TStringList;
  Index : Integer;
begin
  L:=TStringList.Create;
  try
    L.Text:='a'#13#10' halt ';
    Index:=1;
    AssertEquals('halt', JoinContinuation(L,Index));
    AssertEquals(2, Index);
  finally
    L.Free;
  end;
end;

procedure TEuoScriptWordsTests.TestDotGlue;
begin
  AssertEquals('menu|text|ab', Glue('menu text a . b', False, False));
  AssertEquals('menu|abc', Glue('menu a . b . c', False, False));
end;

procedure TEuoScriptWordsTests.TestDotAtEdgesStays;
begin
  AssertEquals('.|a', Glue('. a', False, False));
  AssertEquals('a|.', Glue('a .', False, False));
end;

procedure TEuoScriptWordsTests.TestCommaGlue;
begin
  AssertEquals('menu|ab', Glue('menu a , b', False, False));
  AssertEquals('a last comma stays', 'menu|a|,', Glue('menu a ,', False, False));
end;

// Three standalone commas in ParseLine's right-to-left loop: the last two glue into ",b",
// which the first then glues onto "a".
procedure TEuoScriptWordsTests.TestConsecutiveCommas;
begin
  AssertEquals('a,b', Glue('a , , , b', False, False));
end;

procedure TEuoScriptWordsTests.TestNoSubstitutionWithoutHook;
begin
  AssertEquals('display|%a|%b', Glue('display %a %b', False, False));
end;

// "%list . %i": %i first, then the glue, then the glued %list3.
procedure TEuoScriptWordsTests.TestArrayIdiom;
begin
  AssertEquals('display|third', Glue('display %list . %i', True, False));
end;

procedure TEuoScriptWordsTests.TestKeepFirstArg;
begin
  AssertEquals('set|%a|B', Glue('set %a %b', True, True));
  AssertEquals('set|A|B', Glue('set %a %b', True, False));
end;

procedure TEuoScriptWordsTests.TestCommaAfterSubstitution;
begin
  AssertEquals('the comma is discarded', 'x|AB', Glue('x %a , %b', True, False));
  AssertEquals('a substituted comma glues', 'x|aB', Glue('x a #comma %b', True, False));
end;

// The '.' pass has already passed a word when it substitutes it.
procedure TEuoScriptWordsTests.TestSubstitutedDotIsNotGlued;
begin
  AssertEquals('x|a|.|b', Glue('x a #dot b', True, False));
end;

procedure TEuoScriptWordsTests.TestWordsToParList;
var
  Words : TStringList;
  P     : TParList;
begin
  Words:=TStringList.Create;
  P:=TParList.Create;
  try
    Words.CommaText:='menu,12,-5,abc,$FF';
    WordsToParList(Words,P);
    AssertEquals(Cardinal(5), P.Count);
    AssertEquals('MENU', P[0].StrU);
    AssertTrue(P[1].IntValid and P[1].CardValid);
    AssertEquals(12, P[1].Int);
    AssertTrue(P[2].IntValid);
    AssertFalse(P[2].CardValid);
    AssertFalse(P[3].IntValid);
    AssertEquals(255, P[4].Int);
  finally
    P.Free;
    Words.Free;
  end;
end;

// The words of ScanLineWords, joined by '|'.
function ScanJoined(const Line : String) : String;
var
  W : TEuoWords;
  i : Integer;
begin
  ScanLineWords(Line,W);
  Result:='';
  for i:=0 to High(W) do
  begin
    if i>0 then Result:=Result+'|';
    Result:=Result+W[i].Text;
  end;
end;

// TEuoInterpreter.Parameterize's split as the original writes it (private to the interpreter):
// the oracle ScanLineWords must agree with.
function ParameterizeJoined(Str : String) : String;
var
  sBuf : String;
  Cnt1 : Integer;
begin
  Result:='';
  Str:=Trim(Str)+' ';
  for Cnt1:=1 to Length(Str) do
    if Str[Cnt1]=#9 then Str[Cnt1]:=#32;
  repeat
    Cnt1:=Pos(#32,Str);
    if Cnt1<1 then Break;
    sBuf:=Copy(Str,1,Cnt1-1);
    Delete(Str,1,Cnt1);
    if sBuf='' then Continue;
    if sBuf[1]=';' then Break;
    if Result<>'' then Result:=Result+'|';
    Result:=Result+sBuf;
  until False;
end;

procedure TEuoScriptWordsTests.TestScanLineWordsColumns;
var
  W : TEuoWords;
begin
  AssertTrue(ScanLineWords('  gosub'#9'  mySub  1', W));
  AssertEquals(3, Length(W));
  AssertEquals('gosub', W[0].Text);
  AssertEquals(3, W[0].Start);
  AssertEquals('mySub', W[1].Text);
  AssertEquals(11, W[1].Start);
  AssertEquals('1', W[2].Text);
  AssertEquals(18, W[2].Start);
end;

procedure TEuoScriptWordsTests.TestScanLineWordsStopsAtAComment;
var
  W : TEuoWords;
begin
  AssertFalse('a ; word ends the line', ScanLineWords('set %a 1 ;comment here', W));
  AssertEquals(3, Length(W));
  AssertTrue('a ; inside a word does not', ScanLineWords('set %a b;c', W));
  AssertEquals('b;c', W[2].Text);
  AssertTrue('an empty line', ScanLineWords('', W));
  AssertEquals(0, Length(W));
  AssertFalse('a whole-line comment', ScanLineWords('  ; only a comment', W));
  AssertEquals(0, Length(W));
end;

procedure TEuoScriptWordsTests.TestScanLineWordsAgreesWithParameterize;
const
  Lines : array[0..10] of String = (
    '', '   ', 'halt', '  set %a 1  ', #9'if'#9'%a'#9'>'#9'1'#9, 'set %a 1 ; c', ';x',
    #1'event'#13, 'a'#13'b c', 'menu text t 1 1 a;b ;c d', '{');
var
  i : Integer;
begin
  for i:=0 to High(Lines) do
    AssertEquals('line '+IntToStr(i), ParameterizeJoined(Lines[i]), ScanJoined(Lines[i]));
end;

initialization
  RegisterTest(TEuoScriptWordsTests);
end.
