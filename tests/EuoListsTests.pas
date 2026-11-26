unit EuoListsTests;

{
  Forum item 1 (docs/forum-feature-candidates.md): the LIST command.
  - TEuoListsTests: the list table (EuoLists.pas) on its own.
  - TEuoListScriptTests: the LIST command and #ListRes through the interpreter: every sub-command and its
    N/A cases, values with spaces, the separator as the last word, names built with '.' or from a variable,
    what must not change (a sub or label called list, EXIT, Clear), CALL sharing the lists, and the views
    the editor and EUOCli take (GetListNames, GetListValues, SetListValues, GetVarDump).
  - TEuoListMenuTests: LIST TOMENU / FROMMENU under each MENU logic, read straight from the window's
    controls: list box, combo box and memo, what a name reaches (every control so named in 1.5, the
    registered one in 1.6), values kept exactly, and N/A for any other control.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, fpcunit, testregistry, EuoLists, EuoInterpreter,
  EuoMenuSelect, EuoMenuCommon;

type
  TEuoListsTests = class(TTestCase)
  private
    L : TEuoLists;
    function Joined(const Name : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNeverMadeIsEmpty;
    procedure TestAddGetCountAreOneBased;
    procedure TestInsertSetDelete;
    procedure TestEmptyingAListForgetsIt;
    procedure TestIndexOfAndFindIgnoreCase;
    procedure TestNamesIgnoreCaseAndKeepTheFirstSpelling;
    procedure TestSortAuto;
    procedure TestSortTextNumberDownAndStable;
    procedure TestSplit;
    procedure TestJoin;
    procedure TestClone;
    procedure TestMerge;
    procedure TestIntersect;
    procedure TestSubtract;
    procedure TestSetOperationsLeaveInputsAndMayReplaceOne;
    procedure TestSetValuesAndClear;
  end;

  TEuoListScriptTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    TmpDir : String;
    procedure PlayScript(const Script : String; MaxSteps : Integer = 1000);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestListRes;
    procedure TestMissingWordsOrUnknownWordAreNA;
    procedure TestBadIndexesAreNA;
    procedure TestValuesWithSpaces;
    procedure TestSeparatorIsTheLastWord;
    procedure TestNameFromVariablesAndGlue;
    procedure TestSortWords;
    procedure TestSetOperations;
    procedure TestListsSurviveExitRestart;
    procedure TestClearForgetsLists;
    procedure TestCalledScriptSharesTheLists;
    procedure TestSubAndLabelCalledListStillWork;
    procedure TestHostViews;
    procedure TestVarDumpShowsLists;
  end;

  // The interpreter keeps its MENU objects private, so the window is found by its title among
  // Screen's forms, and its controls are read from its Surface, in the order they were made.
  TEuoListMenuTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    Title  : String;
    procedure Run(Is16 : Boolean; const Script : String);
    function  Window : TEuoMenuForm;
    function  Nth(AClass : TClass; N : Integer) : TControl;
    function  Entries(C : TControl) : String;
    procedure CheckToMenu(Is16 : Boolean);
    procedure CheckMemo(Is16 : Boolean);
    procedure CheckFromMenu(Is16 : Boolean);
    procedure CheckWrongControl(Is16 : Boolean);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestToMenu15;
    procedure TestToMenu16;
    procedure TestMemo15;
    procedure TestMemo16;
    procedure TestFromMenu15;
    procedure TestFromMenu16;
    procedure TestWrongControlIsNA15;
    procedure TestWrongControlIsNA16;
    procedure TestEveryControlOfTheName15;
    procedure TestOnlyTheRegisteredControl16;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
/// TEuoListsTests /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoListsTests.SetUp;
begin
  L:=TEuoLists.Create;
end;

procedure TEuoListsTests.TearDown;
begin
  L.Free;
end;

function TEuoListsTests.Joined(const Name : String) : String;
begin
  Result:=L.Join(Name,'|');
end;

procedure TEuoListsTests.TestNeverMadeIsEmpty;
var
  V : String;
begin
  AssertEquals(0,L.Count('none'));
  AssertFalse(L.Get('none',1,V));
  AssertEquals('',Joined('none'));
  AssertEquals(0,L.IndexOf('none','a',1));
  AssertEquals(0,L.ListCount);
end;

procedure TEuoListsTests.TestAddGetCountAreOneBased;
var
  V : String;
begin
  AssertEquals(1,L.Add('ores','iron'));
  AssertEquals(2,L.Add('ores','gold'));
  AssertEquals(2,L.Count('ores'));
  AssertTrue(L.Get('ores',1,V));
  AssertEquals('iron',V);
  AssertTrue(L.Get('ores',2,V));
  AssertEquals('gold',V);
  AssertFalse('0 is outside',L.Get('ores',0,V));
  AssertFalse('count+1 is outside',L.Get('ores',3,V));
end;

procedure TEuoListsTests.TestInsertSetDelete;
begin
  L.Add('a','x');
  AssertTrue('before the first',L.Insert('a',1,'w'));
  AssertTrue('count+1 appends',L.Insert('a',3,'z'));
  AssertFalse('count+2 is outside',L.Insert('a',5,'no'));
  AssertFalse(L.Insert('a',0,'no'));
  AssertEquals('w|x|z',Joined('a'));
  AssertTrue(L.SetValue('a',2,'X'));
  AssertFalse(L.SetValue('a',4,'no'));
  AssertEquals('w|X|z',Joined('a'));
  AssertTrue(L.Delete('a',1));
  AssertFalse(L.Delete('a',3));
  AssertEquals('X|z',Joined('a'));
  AssertTrue('a list never made can be inserted into at 1',L.Insert('new',1,'v'));
  AssertEquals('v',Joined('new'));
end;

procedure TEuoListsTests.TestEmptyingAListForgetsIt;
begin
  L.Add('a','x');
  AssertEquals(1,L.ListCount);
  L.Delete('a',1);
  AssertEquals(0,L.ListCount);
  L.Add('b','y');
  L.Forget('b');
  AssertEquals(0,L.ListCount);
  AssertEquals(0,L.Count('b'));
end;

procedure TEuoListsTests.TestIndexOfAndFindIgnoreCase;
begin
  L.Add('a','Copper');
  L.Add('a','iron');
  L.Add('a','IRON');
  L.Add('a','verite');
  AssertEquals(2,L.IndexOf('a','Iron',1));
  AssertEquals('from a later position',3,L.IndexOf('a','iron',3));
  AssertEquals(0,L.IndexOf('a','iro',1));
  AssertEquals(0,L.IndexOf('a','iron',5));
  AssertEquals(1,L.FindText('a','ER',1));
  AssertEquals(4,L.FindText('a','er',2));
  AssertEquals(0,L.FindText('a','gold',1));
  AssertEquals(0,L.FindText('a','er',0));
end;

procedure TEuoListsTests.TestNamesIgnoreCaseAndKeepTheFirstSpelling;
var
  N : TStringList;
begin
  L.Add('Loot','a');
  L.Add('LOOT','b');
  L.Add('ores','c');
  AssertEquals(2,L.Count('loot'));
  N:=TStringList.Create;
  try
    L.Names(N);
    AssertEquals('Loot,ores',N.CommaText);
  finally
    N.Free;
  end;
end;

procedure TEuoListsTests.TestSortAuto;
begin
  L.Add('n','10'); L.Add('n','9'); L.Add('n','100'); L.Add('n','-3');
  AssertEquals(4,L.Sort('n',lsAuto,False));
  AssertEquals('every value a whole number: by number','-3|9|10|100',Joined('n'));
  L.Add('t','10'); L.Add('t','9'); L.Add('t','pof');
  L.Sort('t',lsAuto,False);
  AssertEquals('one text: all as text','10|9|pof',Joined('t'));
  L.Add('c','banana'); L.Add('c','Apple'); L.Add('c','cherry');
  L.Sort('c',lsAuto,False);
  AssertEquals('text ignores case','Apple|banana|cherry',Joined('c'));
  AssertEquals('a list never made sorts to nothing',0,L.Sort('none',lsAuto,False));
end;

procedure TEuoListsTests.TestSortTextNumberDownAndStable;
begin
  L.Add('n','10'); L.Add('n','9'); L.Add('n','100');
  L.Sort('n',lsText,False);
  AssertEquals('forced text','10|100|9',Joined('n'));
  L.Sort('n',lsNumber,True);
  AssertEquals('number, down','100|10|9',Joined('n'));
  L.Add('m','b'); L.Add('m','5'); L.Add('m','a'); L.Add('m','-1');
  L.Sort('m',lsNumber,False);
  AssertEquals('number reads a text as 0, equal ones keep their order','-1|b|a|5',Joined('m'));
  L.Add('s','Bob'); L.Add('s','bob'); L.Add('s','alice'); L.Add('s','BOB');
  L.Sort('s',lsText,False);
  AssertEquals('stable','alice|Bob|bob|BOB',Joined('s'));
  L.Sort('s',lsText,True);
  AssertEquals('stable going down too','Bob|bob|BOB|alice',Joined('s'));
end;

procedure TEuoListsTests.TestSplit;
begin
  AssertEquals(3,L.Split('a','iron_gold_agapite','_'));
  AssertEquals('iron|gold|agapite',Joined('a'));
  AssertEquals('empty fields are kept',4,L.Split('a','_x__','_'));
  AssertEquals('|x||',Joined('a'));
  AssertEquals('a longer separator, matched ignoring case',2,L.Split('a','oneANDtwo','and'));
  AssertEquals('one|two',Joined('a'));
  AssertEquals('no separator in the text: one field',1,L.Split('a','alone',','));
  AssertEquals('an empty text: no list',0,L.Split('a','',','));
  AssertEquals(0,L.ListCount);
  AssertEquals('an empty separator is refused',-1,L.Split('b','abc',''));
  AssertEquals(0,L.Count('b'));
end;

procedure TEuoListsTests.TestJoin;
begin
  L.Add('a','x'); L.Add('a','y'); L.Add('a','z');
  AssertEquals('x, y, z',L.Join('a',', '));
  AssertEquals('xyz',L.Join('a',''));
  AssertEquals('',L.Join('none',','));
end;

procedure TEuoListsTests.TestClone;
begin
  L.Add('a','x'); L.Add('a','y');
  L.Add('b','old');
  AssertEquals(2,L.Clone('b','a'));
  AssertEquals('x|y',Joined('b'));
  L.Add('b','z');
  AssertEquals('a copy, not the same list','x|y',Joined('a'));
  AssertEquals('cloning a list never made empties it',0,L.Clone('b','none'));
  AssertEquals(0,L.Count('b'));
end;

procedure TEuoListsTests.TestMerge;
var
  S : TStringList;
begin
  L.Add('a','iron'); L.Add('a','Gold'); L.Add('a','iron');
  L.Add('b','GOLD'); L.Add('b','copper');
  S:=TStringList.Create;
  try
    S.Add('a'); S.Add('b');
    AssertEquals(3,L.Merge('r',S,False));
    AssertEquals('each once, ignoring case, first spelling kept','iron|Gold|copper',Joined('r'));
    AssertEquals(5,L.Merge('r',S,True));
    AssertEquals('keepduplicates: every value in order','iron|Gold|iron|GOLD|copper',Joined('r'));
    S.Clear; S.Add('a');
    AssertEquals('one input: a copy without repeats',2,L.Merge('r',S,False));
    S.Clear; S.Add('none'); S.Add('b');
    AssertEquals('a list never made is empty',2,L.Merge('r',S,False));
  finally
    S.Free;
  end;
end;

procedure TEuoListsTests.TestIntersect;
var
  S : TStringList;
begin
  L.Add('a','iron'); L.Add('a','gold'); L.Add('a','IRON'); L.Add('a','copper'); L.Add('a','verite');
  L.Add('b','Copper'); L.Add('b','iron'); L.Add('b','verite');
  L.Add('c','verite'); L.Add('c','iron');
  S:=TStringList.Create;
  try
    S.Add('a'); S.Add('b');
    AssertEquals(3,L.Intersect('r',S));
    AssertEquals('in both, the first list''s order and spelling, once each','iron|copper|verite',Joined('r'));
    S.Add('c');
    AssertEquals(2,L.Intersect('r',S));
    AssertEquals('iron|verite',Joined('r'));
    S.Add('none');
    AssertEquals('with a list never made: nothing',0,L.Intersect('r',S));
    AssertEquals(0,L.Count('r'));
  finally
    S.Free;
  end;
end;

procedure TEuoListsTests.TestSubtract;
begin
  L.Add('a','iron'); L.Add('a','gold'); L.Add('a','IRON'); L.Add('a','copper');
  L.Add('b','Gold');
  AssertEquals(2,L.Subtract('r','a','b'));
  AssertEquals('not in the other, once each','iron|copper',Joined('r'));
  AssertEquals('minus a list never made: the first without repeats',3,L.Subtract('r','a','none'));
  AssertEquals(0,L.Subtract('r','none','a'));
end;

procedure TEuoListsTests.TestSetOperationsLeaveInputsAndMayReplaceOne;
var
  S : TStringList;
begin
  L.Add('a','x'); L.Add('a','y');
  L.Add('b','y'); L.Add('b','z');
  S:=TStringList.Create;
  try
    S.Add('a'); S.Add('b');
    L.Merge('r',S,False);
    L.Intersect('r2',S);
    L.Subtract('r3','a','b');
    AssertEquals('x|y',Joined('a'));
    AssertEquals('y|z',Joined('b'));
    AssertEquals('the new list may be an input',3,L.Merge('a',S,False));
    AssertEquals('x|y|z',Joined('a'));
    AssertEquals('y|z',Joined('b'));
    AssertEquals('the new list may be the first input',0,L.Subtract('b','b','a'));
    AssertEquals(0,L.Count('b'));
  finally
    S.Free;
  end;
end;

procedure TEuoListsTests.TestSetValuesAndClear;
var
  V : TStringList;
begin
  V:=TStringList.Create;
  try
    V.Add('one'); V.Add(''); V.Add('three words here');
    L.SetValues('x',V);
    AssertEquals(3,L.Count('x'));
    AssertEquals('one||three words here',Joined('x'));
    V.Clear;
    L.SetValues('x',V);
    AssertEquals('no values forgets it',0,L.ListCount);
    L.Add('a','1'); L.Add('b','2');
    L.Clear;
    AssertEquals(0,L.ListCount);
  finally
    V.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoListScriptTests ////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoListScriptTests.SetUp;
begin
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
  TmpDir:=IncludeTrailingPathDelimiter(GetTempDir(False))+'euolisttests'+IntToStr(GetProcessID)+PathDelim;
  ForceDirectories(TmpDir);
end;

procedure TEuoListScriptTests.TearDown;
begin
  Interp.Free;
  DeleteFile(TmpDir+'listcalltest.euo');
  RemoveDir(TmpDir);
end;

procedure TEuoListScriptTests.PlayScript(const Script : String; MaxSteps : Integer);
var
  Cnt : Integer;
begin
  Interp.ScrList.Scr.Text:=Script;
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

procedure TEuoListScriptTests.TestListRes;
begin
  AssertEquals('N/A',Interp.GetVar('#ListRes'));
  PlayScript(
    'list count ores' + #13#10 + 'set %never #ListRes' + #13#10 +
    'list add ores iron gold agapite' + #13#10 + 'set %add #ListRes' + #13#10 +
    'list get ores 2' + #13#10 + 'set %get #ListRes' + #13#10 +
    'list insert ores 1 copper tin' + #13#10 + 'set %ins #ListRes' + #13#10 +
    'list set ores 5 verite' + #13#10 + 'set %set #ListRes' + #13#10 +
    'list delete ores 2' + #13#10 + 'set %del #ListRes' + #13#10 +
    'list indexof ores GOLD' + #13#10 + 'set %idx #ListRes' + #13#10 +
    'list find ores er' + #13#10 + 'set %find #ListRes' + #13#10 +
    'list find ores er 2' + #13#10 + 'set %find2 #ListRes' + #13#10 +
    'list join ores _' + #13#10 + 'set %join #ListRes' + #13#10 +
    'list join ores' + #13#10 + 'set %join0 #ListRes' + #13#10 +
    'list clone copy ores' + #13#10 + 'set %clone #ListRes' + #13#10 +
    'list sort copy' + #13#10 + 'set %sort #ListRes' + #13#10 +
    'list split parts a_b_c _' + #13#10 + 'set %split #ListRes' + #13#10 +
    'list clear ores' + #13#10 + 'set %clear #ListRes' + #13#10 +
    'list count ores' + #13#10 + 'set %after #ListRes' + #13#10 +
    'halt');
  AssertEquals('0',Interp.GetVar('%never'));
  AssertEquals('3',Interp.GetVar('%add'));
  AssertEquals('gold',Interp.GetVar('%get'));
  AssertEquals('5',Interp.GetVar('%ins'));
  AssertEquals('5',Interp.GetVar('%set'));
  AssertEquals('4',Interp.GetVar('%del'));
  // copper iron gold verite
  AssertEquals('3',Interp.GetVar('%idx'));
  AssertEquals('1',Interp.GetVar('%find'));
  AssertEquals('4',Interp.GetVar('%find2'));
  AssertEquals('copper_iron_gold_verite',Interp.GetVar('%join'));
  AssertEquals('copperirongoldverite',Interp.GetVar('%join0'));
  AssertEquals('4',Interp.GetVar('%clone'));
  AssertEquals('4',Interp.GetVar('%sort'));
  AssertEquals('3',Interp.GetVar('%split'));
  AssertEquals('0',Interp.GetVar('%clear'));
  AssertEquals('0',Interp.GetVar('%after'));
end;

procedure TEuoListScriptTests.TestMissingWordsOrUnknownWordAreNA;
begin
  PlayScript(
    'list add keep x' + #13#10 +
    'list' + #13#10 + 'set %alone #ListRes' + #13#10 +
    'list add' + #13#10 + 'set %noName #ListRes' + #13#10 +
    'list add keep' + #13#10 + 'set %noValue #ListRes' + #13#10 +
    'list get keep' + #13#10 + 'set %noIndex #ListRes' + #13#10 +
    'list insert keep 1' + #13#10 + 'set %insNoValue #ListRes' + #13#10 +
    'list set keep 1' + #13#10 + 'set %setNoValue #ListRes' + #13#10 +
    'list frob keep' + #13#10 + 'set %unknown #ListRes' + #13#10 +
    'list sort keep sideways' + #13#10 + 'set %sortWord #ListRes' + #13#10 +
    'list split keep abc' + #13#10 + 'set %splitNoSep #ListRes' + #13#10 +
    'list split keep a b c' + #13#10 + 'set %splitMore #ListRes' + #13#10 +
    'list merge r' + #13#10 + 'set %mergeNone #ListRes' + #13#10 +
    'list merge r keepduplicates' + #13#10 + 'set %mergeOnlyKeep #ListRes' + #13#10 +
    'list subtract r keep' + #13#10 + 'set %subOne #ListRes' + #13#10 +
    'list subtract r keep a b' + #13#10 + 'set %subThree #ListRes' + #13#10 +
    'list tomenu keep' + #13#10 + 'set %toNoCtrl #ListRes' + #13#10 +
    'list tomenu keep box more' + #13#10 + 'set %toMore #ListRes' + #13#10 +
    'list frommenu keep' + #13#10 + 'set %fromNoCtrl #ListRes' + #13#10 +
    'list frommenu keep box more' + #13#10 + 'set %fromMore #ListRes' + #13#10 +
    'list count keep' + #13#10 + 'set %count #ListRes' + #13#10 +
    'halt');
  AssertEquals('N/A',Interp.GetVar('%alone'));
  AssertEquals('N/A',Interp.GetVar('%noName'));
  AssertEquals('N/A',Interp.GetVar('%noValue'));
  AssertEquals('N/A',Interp.GetVar('%noIndex'));
  AssertEquals('N/A',Interp.GetVar('%insNoValue'));
  AssertEquals('N/A',Interp.GetVar('%setNoValue'));
  AssertEquals('N/A',Interp.GetVar('%unknown'));
  AssertEquals('N/A',Interp.GetVar('%sortWord'));
  AssertEquals('N/A',Interp.GetVar('%splitNoSep'));
  AssertEquals('N/A',Interp.GetVar('%splitMore'));
  AssertEquals('N/A',Interp.GetVar('%mergeNone'));
  AssertEquals('N/A',Interp.GetVar('%mergeOnlyKeep'));
  AssertEquals('N/A',Interp.GetVar('%subOne'));
  AssertEquals('N/A',Interp.GetVar('%subThree'));
  AssertEquals('N/A',Interp.GetVar('%toNoCtrl'));
  AssertEquals('N/A',Interp.GetVar('%toMore'));
  AssertEquals('N/A',Interp.GetVar('%fromNoCtrl'));
  AssertEquals('N/A',Interp.GetVar('%fromMore'));
  AssertEquals('nothing changed the list','1',Interp.GetVar('%count'));
end;

procedure TEuoListScriptTests.TestBadIndexesAreNA;
begin
  PlayScript(
    'list add a x y' + #13#10 +
    'list get a 0' + #13#10 + 'set %g0 #ListRes' + #13#10 +
    'list get a 3' + #13#10 + 'set %g3 #ListRes' + #13#10 +
    'list get a -1' + #13#10 + 'set %gneg #ListRes' + #13#10 +
    'list get a two' + #13#10 + 'set %gtext #ListRes' + #13#10 +
    'list insert a 4 z' + #13#10 + 'set %i4 #ListRes' + #13#10 +
    'list insert a 3 z' + #13#10 + 'set %i3 #ListRes' + #13#10 +
    'list set a 9 q' + #13#10 + 'set %s9 #ListRes' + #13#10 +
    'list delete a 0' + #13#10 + 'set %d0 #ListRes' + #13#10 +
    'list indexof a x 0' + #13#10 + 'set %from0 #ListRes' + #13#10 +
    'list find a x abc' + #13#10 + 'set %fromText #ListRes' + #13#10 +
    'list indexof a x 9' + #13#10 + 'set %fromPast #ListRes' + #13#10 +
    'halt');
  AssertEquals('N/A',Interp.GetVar('%g0'));
  AssertEquals('N/A',Interp.GetVar('%g3'));
  AssertEquals('N/A',Interp.GetVar('%gneg'));
  AssertEquals('N/A',Interp.GetVar('%gtext'));
  AssertEquals('N/A',Interp.GetVar('%i4'));
  AssertEquals('count+1 appends','3',Interp.GetVar('%i3'));
  AssertEquals('N/A',Interp.GetVar('%s9'));
  AssertEquals('N/A',Interp.GetVar('%d0'));
  AssertEquals('N/A',Interp.GetVar('%from0'));
  AssertEquals('N/A',Interp.GetVar('%fromText'));
  AssertEquals('a start past the end finds nothing','0',Interp.GetVar('%fromPast'));
end;

procedure TEuoListScriptTests.TestValuesWithSpaces;
begin
  PlayScript(
    'list add names Sir Robin' + #13#10 + 'set %twoWords #ListRes' + #13#10 +
    'list add glued Sir , #SPC , Robin' + #13#10 + 'set %glued #ListRes' + #13#10 +
    'set %n Lady , #SPC , Ann' + #13#10 +
    'list add glued %n' + #13#10 +
    'list get glued 1' + #13#10 + 'set %first #ListRes' + #13#10 +
    'list indexof glued Lady , #SPC , Ann' + #13#10 + 'set %idx #ListRes' + #13#10 +
    'list indexof glued Lady_Ann' + #13#10 + 'set %underscore #ListRes' + #13#10 +
    'list add glued #SPC , lead' + #13#10 +
    'list get glued 3' + #13#10 + 'str len #ListRes' + #13#10 + 'set %leadLen #StrRes' + #13#10 +
    'halt');
  AssertEquals('one value per word','2',Interp.GetVar('%twoWords'));
  AssertEquals('glued with #SPC: one value','1',Interp.GetVar('%glued'));
  AssertEquals('Sir Robin',Interp.GetVar('%first'));
  AssertEquals('2',Interp.GetVar('%idx'));
  AssertEquals('_ is not a space','0',Interp.GetVar('%underscore'));
  AssertEquals('values are never trimmed','5',Interp.GetVar('%leadLen'));
end;

procedure TEuoListScriptTests.TestSeparatorIsTheLastWord;
begin
  PlayScript(
    'set %csv Sir , #SPC , Robin,Lady , #SPC , Ann,Tim' + #13#10 +
    'list split people %csv ,' + #13#10 + 'set %split #ListRes' + #13#10 +
    'list get people 2' + #13#10 + 'set %second #ListRes' + #13#10 +
    'list join people ,' + #13#10 + 'set %comma #ListRes' + #13#10 +
    'list join people .' + #13#10 + 'set %dot #ListRes' + #13#10 +
    'halt');
  AssertEquals('3',Interp.GetVar('%split'));
  AssertEquals('Lady Ann',Interp.GetVar('%second'));
  AssertEquals('Sir Robin,Lady Ann,Tim',Interp.GetVar('%comma'));
  AssertEquals('Sir Robin.Lady Ann.Tim',Interp.GetVar('%dot'));
end;

procedure TEuoListScriptTests.TestNameFromVariablesAndGlue;
begin
  PlayScript(
    'set %i 3' + #13#10 +
    'list add slot . %i sword' + #13#10 +
    'list get SLOT3 1' + #13#10 + 'set %glued #ListRes' + #13#10 +
    'set %which loot' + #13#10 +
    'list add %which gem' + #13#10 +
    'list get loot 1' + #13#10 + 'set %fromVar #ListRes' + #13#10 +
    'halt');
  AssertEquals('sword',Interp.GetVar('%glued'));
  AssertEquals('gem',Interp.GetVar('%fromVar'));
end;

procedure TEuoListScriptTests.TestSortWords;
begin
  PlayScript(
    'list add n 10 9 100' + #13#10 +
    'list sort n' + #13#10 + 'list join n _' + #13#10 + 'set %auto #ListRes' + #13#10 +
    'list sort n text' + #13#10 + 'list join n _' + #13#10 + 'set %text #ListRes' + #13#10 +
    'list sort n number down' + #13#10 + 'list join n _' + #13#10 + 'set %down #ListRes' + #13#10 +
    'list sort n DOWN TEXT' + #13#10 + 'list join n _' + #13#10 + 'set %textDown #ListRes' + #13#10 +
    'halt');
  AssertEquals('9_10_100',Interp.GetVar('%auto'));
  AssertEquals('10_100_9',Interp.GetVar('%text'));
  AssertEquals('100_10_9',Interp.GetVar('%down'));
  AssertEquals('9_100_10',Interp.GetVar('%textDown'));
end;

procedure TEuoListScriptTests.TestSetOperations;
begin
  PlayScript(
    'list add a iron Gold iron' + #13#10 +
    'list add b GOLD copper' + #13#10 +
    'list merge r a b' + #13#10 + 'set %merge #ListRes' + #13#10 +
    'list join r _' + #13#10 + 'set %mergeJ #ListRes' + #13#10 +
    'list merge r a b keepduplicates' + #13#10 + 'set %keep #ListRes' + #13#10 +
    'list merge r a b KEEPDUPLICATES' + #13#10 + 'set %keepCase #ListRes' + #13#10 +
    'list intersect r a b' + #13#10 + 'list join r _' + #13#10 + 'set %inter #ListRes' + #13#10 +
    'list subtract r a b' + #13#10 + 'list join r _' + #13#10 + 'set %sub #ListRes' + #13#10 +
    'list merge a a b' + #13#10 + 'set %intoInput #ListRes' + #13#10 +
    'list count b' + #13#10 + 'set %bCount #ListRes' + #13#10 +
    'halt');
  AssertEquals('3',Interp.GetVar('%merge'));
  AssertEquals('iron_Gold_copper',Interp.GetVar('%mergeJ'));
  AssertEquals('5',Interp.GetVar('%keep'));
  AssertEquals('5',Interp.GetVar('%keepCase'));
  AssertEquals('Gold',Interp.GetVar('%inter'));
  AssertEquals('iron',Interp.GetVar('%sub'));
  AssertEquals('3',Interp.GetVar('%intoInput'));
  AssertEquals('2',Interp.GetVar('%bCount'));
end;

procedure TEuoListScriptTests.TestListsSurviveExitRestart;
begin
  PlayScript(
    'if %pass = 2' + #13#10 +
    '{' + #13#10 +
    '  list count keep' + #13#10 +
    '  set %count #ListRes' + #13#10 +
    '  halt' + #13#10 +
    '}' + #13#10 +
    'set %pass 2' + #13#10 +
    'list add keep x y');
  AssertEquals('2',Interp.GetVar('%pass'));
  AssertEquals('2',Interp.GetVar('%count'));
  AssertTrue(Interp.Restarts>=1);
end;

procedure TEuoListScriptTests.TestClearForgetsLists;
var
  N : TStringList;
begin
  PlayScript('list add keep x' + #13#10 + 'halt');
  AssertEquals('1',Interp.GetVar('#ListRes'));
  Interp.Clear;
  AssertEquals('N/A',Interp.GetVar('#ListRes'));
  N:=TStringList.Create;
  try
    Interp.GetListNames(N);
    AssertEquals(0,N.Count);
  finally
    N.Free;
  end;
  PlayScript('list count keep' + #13#10 + 'halt');
  AssertEquals('0',Interp.GetVar('#ListRes'));
end;

procedure TEuoListScriptTests.TestCalledScriptSharesTheLists;
var
  F : TStringList;
begin
  F:=TStringList.Create;
  try
    F.Text:='list add shared fromcall' + #13#10;
    F.SaveToFile(TmpDir+'listcalltest.euo');
  finally
    F.Free;
  end;
  Interp.SearchPath:=TmpDir;
  PlayScript(
    'list add shared main' + #13#10 +
    'call listcalltest' + #13#10 +
    'list join shared _' + #13#10 + 'set %both #ListRes' + #13#10 +
    'halt');
  AssertEquals('main_fromcall',Interp.GetVar('%both'));
end;

procedure TEuoListScriptTests.TestSubAndLabelCalledListStillWork;
begin
  PlayScript(
    'gosub list' + #13#10 +
    'goto list' + #13#10 +
    'set %skipped yes' + #13#10 +
    'list:' + #13#10 +
    'set %label yes' + #13#10 +
    'halt' + #13#10 +
    'sub list' + #13#10 +
    '  set %sub yes' + #13#10 +
    'return');
  AssertEquals('yes',Interp.GetVar('%sub'));
  AssertEquals('yes',Interp.GetVar('%label'));
  AssertEquals('N/A',Interp.GetVar('%skipped'));
end;

procedure TEuoListScriptTests.TestHostViews;
var
  N, V : TStringList;
begin
  PlayScript('list add Ores iron gold' + #13#10 + 'list add ammo arrow' + #13#10 + 'halt');
  N:=TStringList.Create;
  V:=TStringList.Create;
  try
    Interp.GetListNames(N);
    AssertEquals('ammo,Ores',N.CommaText);
    Interp.GetListValues('ores',V);
    AssertEquals('iron,gold',V.CommaText);
    V.Clear;
    V.Add('copper'); V.Add('two words');
    Interp.SetListValues('ORES',V);
    PlayScript('list get ores 2' + #13#10 + 'halt');
    AssertEquals('a script reads what the host set','two words',Interp.GetVar('#ListRes'));
    V.Clear;
    Interp.SetListValues('ammo',V);
    N.Clear;
    Interp.GetListNames(N);
    AssertEquals('no values forgets the list','Ores',N.CommaText);
  finally
    V.Free;
    N.Free;
  end;
end;

procedure TEuoListScriptTests.TestVarDumpShowsLists;
var
  D : String;
begin
  PlayScript('list add loot iron gold' + #13#10 + 'set %a 1' + #13#10 + 'halt');
  D:=Interp.GetVarDump;
  AssertTrue(D,Pos('list loot (2): iron | gold',D)>0);
  AssertTrue('the variables are still there',Pos('%A: 1',D)>0);
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoListMenuTests //////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TEuoListMenuTests.SetUp;
begin
  Application.Initialize;
  Interp:=TEuoInterpreter.Create(0);
  Title:='EuoListMenuTests'+IntToStr(GetProcessID)+'_'+TestName;
end;

procedure TEuoListMenuTests.TearDown;
begin
  Interp.Free;
end;

// Runs Script under the 1.5 or the 1.6 MENU logic, in a window called Title. The script ends by
// setting %end to reached.
procedure TEuoListMenuTests.Run(Is16 : Boolean; const Script : String);
var
  Head : String;
  Cnt  : Integer;
begin
  if Is16 then Head:='menu reforge mode 1.6' + #13#10 else Head:='';
  Interp.ScrList.Scr.Text:=Head + 'menu Window Title ' + Title + #13#10 + Script;
  Interp.Clear;
  if Is16 then AssertTrue('the script runs under the 1.6 logic',Interp.MenuLogic=mlMenu16)
  else AssertTrue('the script runs under the 1.5 logic',Interp.MenuLogic=mlMenu15);
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<500) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
  AssertEquals('the script reaches its end','reached',Interp.GetVar('%end'));
end;

function TEuoListMenuTests.Window : TEuoMenuForm;
var
  i : Integer;
begin
  for i:=0 to Screen.CustomFormCount-1 do
    if (Screen.CustomForms[i] is TEuoMenuForm) and (Screen.CustomForms[i].Caption=Title) then
      Exit(TEuoMenuForm(Screen.CustomForms[i]));
  Result:=nil;
  Fail('no MENU window called '+Title);
end;

// The N-th (from 0) control on the window that is an AClass, in the order they were made.
function TEuoListMenuTests.Nth(AClass : TClass; N : Integer) : TControl;
var
  W : TEuoMenuForm;
  i : Integer;
begin
  W:=Window;
  for i:=0 to W.Surface.ControlCount-1 do
    if W.Surface.Controls[i].InheritsFrom(AClass) then
    begin
      if N=0 then Exit(W.Surface.Controls[i]);
      Dec(N);
    end;
  Result:=nil;
  Fail('the window has no such '+AClass.ClassName);
end;

// A list or combo box's entries, or a memo's lines, joined by '|'.
function TEuoListMenuTests.Entries(C : TControl) : String;
var
  L : TStrings;
  i : Integer;
begin
  if C is TMemo then Exit(StringReplace(TMemo(C).Text,#13#10,'|',[rfReplaceAll]));
  if C is TListBox then L:=TListBox(C).Items else L:=TComboBox(C).Items;
  Result:='';
  for i:=0 to L.Count-1 do
  begin
    if i>0 then Result:=Result+'|';
    Result:=Result+L[i];
  end;
end;

procedure TEuoListMenuTests.CheckToMenu(Is16 : Boolean);
begin
  Run(Is16,
    'menu List Create townbox 0 0 100 100' + #13#10 +
    'menu List Add townbox old' + #13#10 +
    'menu List Select townbox 1' + #13#10 +
    'menu Combo Create pick 0 110 100' + #13#10 +
    'menu Combo Add pick old' + #13#10 +
    'menu Combo Select pick 1' + #13#10 +
    'menu Combo Create other 0 140 100' + #13#10 +
    'menu Combo Add other x' + #13#10 +
    'list add towns Britain Sir , #SPC , Robin' + #13#10 +
    'list tomenu towns townbox' + #13#10 + 'set %res #ListRes' + #13#10 +
    'list tomenu towns pick' + #13#10 + 'set %res2 #ListRes' + #13#10 +
    'menu Get townbox' + #13#10 + 'set %sel #MenuRes' + #13#10 +
    'menu Get pick' + #13#10 + 'set %sel2 #MenuRes' + #13#10 +
    'list tomenu never other' + #13#10 + 'set %empty #ListRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('#ListRes: the values that went in','2',Interp.GetVar('%res'));
  AssertEquals('2',Interp.GetVar('%res2'));
  AssertEquals('the list box holds the values, exactly','Britain|Sir Robin',Entries(Nth(TListBox,0)));
  AssertEquals('the combo box too','Britain|Sir Robin',Entries(Nth(TComboBox,0)));
  AssertEquals('nothing is selected in the list box','0',Interp.GetVar('%sel'));
  AssertEquals('nothing is selected in the combo box','0',Interp.GetVar('%sel2'));
  AssertEquals('a list never made empties the control','0',Interp.GetVar('%empty'));
  AssertEquals('',Entries(Nth(TComboBox,1)));
end;

procedure TEuoListMenuTests.CheckMemo(Is16 : Boolean);
begin
  Run(Is16,
    'menu Memo notes 0 0 100 100 old$text' + #13#10 +
    'list add n first x$y last' + #13#10 +
    'list tomenu n notes' + #13#10 + 'set %res #ListRes' + #13#10 +
    'menu Get notes' + #13#10 + 'set %got #MenuRes' + #13#10 +
    'list frommenu back notes' + #13#10 + 'set %back #ListRes' + #13#10 +
    'list get back 2' + #13#10 + 'set %second #ListRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('3',Interp.GetVar('%res'));
  AssertEquals('one value per line, a $ kept','first|x$y|last',Entries(Nth(TMemo,0)));
  AssertEquals('menu Get folds the lines to $','first$x$y$last',Interp.GetVar('%got'));
  AssertEquals('3',Interp.GetVar('%back'));
  AssertEquals('frommenu keeps the value with a $ whole','x$y',Interp.GetVar('%second'));
end;

procedure TEuoListMenuTests.CheckFromMenu(Is16 : Boolean);
begin
  Run(Is16,
    'menu List Create box 0 0 50 50' + #13#10 +
    'menu List Add box one' + #13#10 +
    'menu List Add box two words' + #13#10 +
    'menu List Select box 2' + #13#10 +
    'menu Combo Create pick 0 60 50' + #13#10 +
    'menu Combo Add pick red' + #13#10 +
    'menu Memo notes 0 90 100 50 a' + #13#10 +
    'menu Set notes a$$b$' + #13#10 +
    'list add keep x' + #13#10 +
    'list frommenu keep box' + #13#10 + 'set %res #ListRes' + #13#10 +
    'list join keep _' + #13#10 + 'set %box #ListRes' + #13#10 +
    'menu Get box' + #13#10 + 'set %sel #MenuRes' + #13#10 +
    'list frommenu c pick' + #13#10 + 'set %c #ListRes' + #13#10 +
    'list frommenu m notes' + #13#10 + 'set %m #ListRes' + #13#10 +
    'list join m _' + #13#10 + 'set %mj #ListRes' + #13#10 +
    'menu List Clear box' + #13#10 +
    'list frommenu keep box' + #13#10 + 'set %empty #ListRes' + #13#10 +
    'list count keep' + #13#10 + 'set %gone #ListRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('the entries replace the list','2',Interp.GetVar('%res'));
  AssertEquals('one_two words',Interp.GetVar('%box'));
  AssertEquals('reading leaves the selection alone','2',Interp.GetVar('%sel'));
  AssertEquals('1',Interp.GetVar('%c'));
  AssertEquals('a memo''s lines: an empty one kept, none after the last line break','3',Interp.GetVar('%m'));
  AssertEquals('a__b',Interp.GetVar('%mj'));
  AssertEquals('an empty control gives 0','0',Interp.GetVar('%empty'));
  AssertEquals('and the list is gone','0',Interp.GetVar('%gone'));
end;

procedure TEuoListMenuTests.CheckWrongControl(Is16 : Boolean);
begin
  Run(Is16,
    'menu Edit ed 0 0 50 text' + #13#10 +
    'menu Check chk 0 30 50 20 1 c' + #13#10 +
    'menu Text lbl 0 60 label' + #13#10 +
    'menu Button btn 0 90 50 20 B' + #13#10 +
    'list add v a b' + #13#10 +
    'list add keep x' + #13#10 +
    'list tomenu v ed' + #13#10 + 'set %ed #ListRes' + #13#10 +
    'list tomenu v chk' + #13#10 + 'set %chk #ListRes' + #13#10 +
    'list tomenu v lbl' + #13#10 + 'set %lbl #ListRes' + #13#10 +
    'list tomenu v btn' + #13#10 + 'set %btn #ListRes' + #13#10 +
    'list tomenu v nothing' + #13#10 + 'set %none #ListRes' + #13#10 +
    'list frommenu keep ed' + #13#10 + 'set %fed #ListRes' + #13#10 +
    'list frommenu keep nothing' + #13#10 + 'set %fnone #ListRes' + #13#10 +
    'list count keep' + #13#10 + 'set %kept #ListRes' + #13#10 +
    'menu Get ed' + #13#10 + 'set %edtext #MenuRes' + #13#10 +
    'menu Get chk' + #13#10 + 'set %chkstate #MenuRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('an edit','N/A',Interp.GetVar('%ed'));
  AssertEquals('a check box','N/A',Interp.GetVar('%chk'));
  AssertEquals('a text','N/A',Interp.GetVar('%lbl'));
  AssertEquals('a button','N/A',Interp.GetVar('%btn'));
  AssertEquals('no control','N/A',Interp.GetVar('%none'));
  AssertEquals('frommenu, an edit','N/A',Interp.GetVar('%fed'));
  AssertEquals('frommenu, no control','N/A',Interp.GetVar('%fnone'));
  AssertEquals('the list is kept','1',Interp.GetVar('%kept'));
  AssertEquals('the edit is untouched','text',Interp.GetVar('%edtext'));
  AssertEquals('the check box is untouched','-1',Interp.GetVar('%chkstate'));
  AssertEquals('the text is untouched','label',TLabel(Nth(TLabel,0)).Caption);
end;

procedure TEuoListMenuTests.TestToMenu15;
begin
  CheckToMenu(False);
end;

procedure TEuoListMenuTests.TestToMenu16;
begin
  CheckToMenu(True);
end;

procedure TEuoListMenuTests.TestMemo15;
begin
  CheckMemo(False);
end;

procedure TEuoListMenuTests.TestMemo16;
begin
  CheckMemo(True);
end;

procedure TEuoListMenuTests.TestFromMenu15;
begin
  CheckFromMenu(False);
end;

procedure TEuoListMenuTests.TestFromMenu16;
begin
  CheckFromMenu(True);
end;

procedure TEuoListMenuTests.TestWrongControlIsNA15;
begin
  CheckWrongControl(False);
end;

procedure TEuoListMenuTests.TestWrongControlIsNA16;
begin
  CheckWrongControl(True);
end;

// Under 1.5 a name reaches every control so named, as MENU LIST ADD and MENU SET do; frommenu
// reads the first list box, combo box or memo of the name.
procedure TEuoListMenuTests.TestEveryControlOfTheName15;
begin
  Run(False,
    'menu Edit box 0 0 50 keep' + #13#10 +
    'menu List Create box 0 30 50 50' + #13#10 +
    'menu List Create box 60 30 50 50' + #13#10 +
    'menu Memo box 0 90 50 50 old' + #13#10 +
    'list add v a b' + #13#10 +
    'list tomenu v box' + #13#10 + 'set %res #ListRes' + #13#10 +
    'list frommenu back box' + #13#10 + 'list join back _' + #13#10 + 'set %back #ListRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('2',Interp.GetVar('%res'));
  AssertEquals('the first list box','a|b',Entries(Nth(TListBox,0)));
  AssertEquals('the second list box','a|b',Entries(Nth(TListBox,1)));
  AssertEquals('the memo','a|b',Entries(Nth(TMemo,0)));
  AssertEquals('the edit of that name is untouched','keep',TEdit(Nth(TEdit,0)).Text);
  AssertEquals('frommenu skips the edit','a_b',Interp.GetVar('%back'));
end;

// Under 1.6 only the control registered under the name: a second one of the same name was refused.
procedure TEuoListMenuTests.TestOnlyTheRegisteredControl16;
begin
  Run(True,
    'menu List Create box 0 0 50 50' + #13#10 +
    'menu List Create box 60 0 50 50' + #13#10 +
    'list add v a b' + #13#10 +
    'list tomenu v box' + #13#10 + 'set %res #ListRes' + #13#10 +
    'set %end reached' + #13#10 + 'halt');
  AssertEquals('2',Interp.GetVar('%res'));
  AssertEquals('the registered list box','a|b',Entries(Nth(TListBox,0)));
  AssertEquals('the refused one is untouched','',Entries(Nth(TListBox,1)));
end;

initialization
  RegisterTest(TEuoListsTests);
  RegisterTest(TEuoListScriptTests);
  RegisterTest(TEuoListMenuTests);
end.
