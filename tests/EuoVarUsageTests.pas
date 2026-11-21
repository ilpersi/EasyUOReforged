unit EuoVarUsageTests;

{
  Tests for parser\EuoVarUsage.pas -- what the editor's Watches panel lists and marks: the variables
  a script uses (the words the interpreter substitutes), the order the panel shows them in, the
  variable at a column, how a watch list is saved, and which values changed between two pauses.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoVarUsage;

type
  TEuoVarUsageTests = class(TTestCase)
  private
    function Scan(const Src : array of String; const Sys : array of String;
               UseSys : Boolean = True) : String;
    function Join(L : TStrings) : String;
  published
    procedure TestScanKeepsTheWordsTheInterpreterSubstitutes;
    procedure TestScanSkipsComments;
    procedure TestScanJoinsPlusLines;
    procedure TestScanKeepsTheFirstSpelling;
    procedure TestScanDropsConstantsAndUnknownHashNames;
    procedure TestScanWithoutKnownNamesKeepsEveryHashName;
    procedure TestMergeOrderAndSpelling;
    procedure TestVarAt;
    procedure TestWatchesText;
    procedure TestChangesFirstPauseMarksNothing;
    procedure TestChangesBetweenPauses;
    procedure TestChangesRememberAndClear;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
function TEuoVarUsageTests.Join(L : TStrings) : String;
var
  i : Integer;
begin
  Result:='';
  for i:=0 to L.Count-1 do
  begin
    if i>0 then Result:=Result+',';
    Result:=Result+L[i];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoVarUsageTests.Scan(const Src : array of String; const Sys : array of String;
  UseSys : Boolean) : String;
var
  Lines, SysL, Names : TStringList;
  i : Integer;
begin
  Lines:=TStringList.Create;
  SysL:=TStringList.Create;
  Names:=TStringList.Create;
  try
    for i:=Low(Src) to High(Src) do Lines.Add(Src[i]);
    for i:=Low(Sys) to High(Sys) do SysL.Add(Sys[i]);
    if UseSys then EuoScriptVarNames(Lines,SysL,Names)
    else EuoScriptVarNames(Lines,nil,Names);
    Result:=Join(Names);
  finally
    Names.Free;
    SysL.Free;
    Lines.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Only whole words that IsVar accepts: "abc%d", "(%e)" and "%f," are not substituted, so they are
// not listed. Sub parameters (%1) are variables.
procedure TEuoVarUsageTests.TestScanKeepsTheWordsTheInterpreterSubstitutes;
begin
  AssertEquals('%a,%b,#findcnt,!ns,*reg,%g,%h,%1',
    Scan(['set %a 1',
          'set %b %a + #findcnt',
          'msg abc%d (%e) %f, ok',
          'set !ns 2',
          'set *reg 3',
          'gosub foo %g',
          'sub foo',
          'set %h %1',
          'return'],
         ['FindCnt']));
end;

procedure TEuoVarUsageTests.TestScanSkipsComments;
begin
  AssertEquals('%a',
    Scan(['set %a 1 ; %b is in a comment',
          ';%c on a comment line',
          '  ; %d too'],[]));
end;

// JoinContinuation glues a '+' line on without a space: "+ %x" adds the word %x, "+%z" glues %z
// onto the word before it, which the interpreter then does not substitute.
procedure TEuoVarUsageTests.TestScanJoinsPlusLines;
begin
  AssertEquals('%x',Scan(['display ok','+ %x'],[]));
  AssertEquals('',Scan(['set %y','+%z'],[]));
end;

procedure TEuoVarUsageTests.TestScanKeepsTheFirstSpelling;
begin
  AssertEquals('%Count',Scan(['set %Count 1','set %COUNT %count + 1'],[]));
end;

procedure TEuoVarUsageTests.TestScanDropsConstantsAndUnknownHashNames;
begin
  AssertEquals('#findcnt,%a,%b,#CHARPOSX,%c',
    Scan(['if #true = #findcnt',
          'set %a #nosuch',
          'set %b #CHARPOSX',
          'set %c #spc #smc #dot #false'],
         ['FindCnt','True','False','SPC','SMC','DOT','CharPosX']));
end;

procedure TEuoVarUsageTests.TestScanWithoutKnownNamesKeepsEveryHashName;
begin
  AssertEquals('%a,#nosuch',Scan(['set %a #nosuch #true'],[],False));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarUsageTests.TestMergeOrderAndSpelling;
var
  W, R, N : TStringList;
begin
  W:=TStringList.Create;
  R:=TStringList.Create;
  N:=TStringList.Create;
  try
    W.CommaText:='#charposx,%b,!n,*r,%Abc';
    R.CommaText:='%ABC,%LIST3,!N,%C';
    EuoMergeVarNames(W,R,N);
    AssertEquals('%Abc,%b,%C,%LIST3,!n,*r,#charposx',Join(N));
  finally
    N.Free;
    R.Free;
    W.Free;
  end;
  AssertTrue(EuoCompareVarNames('%z','!a')<0);
  AssertTrue(EuoCompareVarNames('*a','#a')<0);
  AssertEquals(0,EuoCompareVarNames('%a','%A'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarUsageTests.TestVarAt;
begin
  AssertEquals('on the sigil','%abc',EuoVarAt('set %abc 1',5));
  AssertEquals('inside','%abc',EuoVarAt('set %abc 1',7));
  AssertEquals('right after it','%abc',EuoVarAt('set %abc 1',9));
  AssertEquals('a word without a sigil','',EuoVarAt('set %abc 1',2));
  AssertEquals('past the end','#findid',EuoVarAt('x #findid',10));
  AssertEquals('an empty line','',EuoVarAt('',1));
  AssertEquals('a sigil alone','',EuoVarAt('%',1));
  AssertEquals('glued to a word','%d',EuoVarAt('abc%d',5));
  AssertEquals('the second of two','!n',EuoVarAt('%a,!n',4));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarUsageTests.TestWatchesText;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    EuoWatchesFromText('  %a #findid  junk %A !n'#9'*r % ',L);
    AssertEquals('%a,#findid,!n,*r',Join(L));
    AssertEquals('%a #findid !n *r',EuoWatchesToText(L));
    L.Clear;
    EuoWatchesFromText('',L);
    AssertEquals(0,L.Count);
    AssertEquals('',EuoWatchesToText(L));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarUsageTests.TestChangesFirstPauseMarksNothing;
var
  C    : TEuoVarChanges;
  N, V : TStringList;
  Old  : String;
begin
  C:=TEuoVarChanges.Create;
  N:=TStringList.Create;
  V:=TStringList.Create;
  try
    N.CommaText:='%a,%b';
    V.CommaText:='1,N/A';
    C.NewRun(N,V);
    AssertEquals(0,C.ChangedCount);
    AssertFalse(C.IsChanged('%a',Old));
    AssertEquals('',Old);
  finally
    V.Free;
    N.Free;
    C.Free;
  end;
end;

procedure TEuoVarUsageTests.TestChangesBetweenPauses;
var
  C    : TEuoVarChanges;
  N, V : TStringList;
  Old  : String;
begin
  C:=TEuoVarChanges.Create;
  N:=TStringList.Create;
  V:=TStringList.Create;
  try
    N.CommaText:='%a,%b';
    V.CommaText:='1,N/A';
    C.NewRun(N,V);

    V.CommaText:='2,N/A';
    C.NewPause(N,V);
    AssertTrue(C.IsChanged('%a',Old));
    AssertEquals('1',Old);
    AssertTrue('names ignore case',C.IsChanged('%A',Old));
    AssertFalse(C.IsChanged('%b',Old));
    AssertEquals(1,C.ChangedCount);

    // a name the baseline does not have was N/A
    N.CommaText:='%a,%b,%new';
    V.Clear;
    V.Add('2');
    V.Add('5');
    V.Add('x=y');
    C.NewPause(N,V);
    AssertFalse('the same as at the last pause',C.IsChanged('%a',Old));
    AssertTrue(C.IsChanged('%b',Old));
    AssertEquals(EuoUnsetValue,Old);
    AssertTrue(C.IsChanged('%new',Old));
    AssertEquals(EuoUnsetValue,Old);

    // a value holding '=' is kept whole
    V[2]:='x=z';
    C.NewPause(N,V);
    AssertTrue(C.IsChanged('%new',Old));
    AssertEquals('x=y',Old);
  finally
    V.Free;
    N.Free;
    C.Free;
  end;
end;

procedure TEuoVarUsageTests.TestChangesRememberAndClear;
var
  C    : TEuoVarChanges;
  N, V : TStringList;
  Old  : String;
begin
  C:=TEuoVarChanges.Create;
  N:=TStringList.Create;
  V:=TStringList.Create;
  try
    N.CommaText:='%a';
    V.CommaText:='1';
    C.NewRun(N,V);
    V.CommaText:='2';
    C.NewPause(N,V);
    C.Remember('%w','7');
    AssertTrue('Remember leaves this pause''s changes',C.IsChanged('%a',Old));

    N.CommaText:='%a,%w';
    V.CommaText:='2,7';
    C.NewPause(N,V);
    AssertFalse('remembered: no change',C.IsChanged('%w',Old));

    V.CommaText:='3,7';
    C.NewPause(N,V);
    AssertEquals(1,C.ChangedCount);
    C.ClearChanges;
    AssertEquals(0,C.ChangedCount);

    // a new run starts over
    V.CommaText:='9,9';
    C.NewRun(N,V);
    AssertEquals(0,C.ChangedCount);
    C.NewPause(N,V);
    AssertEquals(0,C.ChangedCount);
  finally
    V.Free;
    N.Free;
    C.Free;
  end;
end;

initialization
  RegisterTest(TEuoVarUsageTests);
end.
