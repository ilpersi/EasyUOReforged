unit EuoCallPathTests;

{
  Tests for parser\EuoCallPath.pas, the folders CALL searches, and for CALL using them through
  TEuoInterpreter.CallPath / CallPathLast. Each test works in its own folder under the temp
  folder; EUOCALLPATH is emptied for every test and put back after, so the machine's own value
  never shows.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoCallPath, EuoInterpreter;

type
  TEuoCallPathTests = class(TTestCase)
  private
    Dir    : String;    // with a trailing '\'
    OldEnv : String;
    procedure MakeFile(const RelPath : String; const Text : String = 'exit');
    procedure SetEnv(const Value : String);
    function  Resolve(const Name : String; const Folders : array of String) : String;
    function  Split(const Text : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSplitCallPath;
    procedure TestJoinCallPath;
    procedure TestTheOriginalLookupIsUnchanged;
    procedure TestCurPathIsSearchedFirstAndInFull;
    procedure TestFoldersAreSearchedOneAfterTheOther;
    procedure TestRelativeFolderStartsFromCurPath;
    procedure TestAbsoluteNameSearchesNoFolder;
    procedure TestMissingAndRepeatedFoldersAreSkipped;
    procedure TestEnvFoldersComeBetweenTheTwoLists;
    procedure TestCallUsesTheFolders;
  end;

implementation

uses
  Windows;

////////////////////////////////////////////////////////////////////////////////
procedure RemoveTree(const Path : String);
var
  SR : TSearchRec;
begin
  if FindFirst(Path+'*',faAnyFile,SR)=0 then
  begin
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then RemoveTree(Path+SR.Name+PathDelim)
      else SysUtils.DeleteFile(Path+SR.Name);
    until FindNext(SR)<>0;
    SysUtils.FindClose(SR);
  end;
  RemoveDir(ExcludeTrailingPathDelimiter(Path));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euocallpath-'+IntToStr(GetProcessID)+PathDelim;
  RemoveTree(Dir);
  ForceDirectories(Dir+'cur');
  ForceDirectories(Dir+'a');
  ForceDirectories(Dir+'b');
  ForceDirectories(Dir+'c');
  OldEnv:=EnvCallPath;
  SetEnv('');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TearDown;
begin
  SetEnv(OldEnv);
  RemoveTree(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.MakeFile(const RelPath : String; const Text : String);
var
  SL : TStringList;
begin
  ForceDirectories(ExtractFileDir(Dir+RelPath));
  SL:=TStringList.Create;
  try
    SL.Text:=Text;
    SL.SaveToFile(Dir+RelPath);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.SetEnv(const Value : String);
var
  Name, V : UnicodeString;
begin
  Name:=CallPathEnvVar;
  if Value='' then SetEnvironmentVariableW(PWideChar(Name),nil)
  else begin
    V:=UTF8Decode(Value);
    SetEnvironmentVariableW(PWideChar(Name),PWideChar(V));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// ResolveCallName with #CurPath = Dir\cur\, the result without Dir in front.
function TEuoCallPathTests.Resolve(const Name : String; const Folders : array of String) : String;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    for i:=Low(Folders) to High(Folders) do L.Add(Folders[i]);
    Result:=ResolveCallName(Name,Dir+'cur\',L);
  finally
    L.Free;
  end;
  if Copy(Result,1,Length(Dir))=Dir then Delete(Result,1,Length(Dir));
end;

////////////////////////////////////////////////////////////////////////////////
// SplitCallPath's entries joined with '|'.
function TEuoCallPathTests.Split(const Text : String) : String;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    SplitCallPath(Text,L);
    Result:='';
    for i:=0 to L.Count-1 do
    begin
      if i>0 then Result:=Result+'|';
      Result:=Result+L[i];
    end;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestSplitCallPath;
begin
  AssertEquals('C:\a|D:\b',Split('C:\a;D:\b'));
  AssertEquals('spaces around and empty entries go','C:\a|D:\b',Split('  C:\a ; ;;D:\b ;'));
  AssertEquals('quotes go; a ; inside them is part of the folder','C:\My;Scripts|D:\b',Split('"C:\My;Scripts";D:\b'));
  AssertEquals('/ is read as \','C:\x\y\',Split('C:/x/y/'));
  AssertEquals('a relative folder stays relative','lib|..\shared',Split('lib;..\shared'));
  AssertEquals('',Split(''));
  AssertEquals('',Split(' ; '));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestJoinCallPath;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Add(' C:\a ');
    L.Add('');
    L.Add('C:\My;Scripts');
    L.Add('lib');
    AssertEquals('C:\a;"C:\My;Scripts";lib',JoinCallPath(L));
    AssertEquals('it splits back the same','C:\a|C:\My;Scripts|lib',Split(JoinCallPath(L)));
    L.Clear;
    AssertEquals('',JoinCallPath(L));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// What the original CallProc found, it still finds: the name as written, then .txt, then .euo.
procedure TEuoCallPathTests.TestTheOriginalLookupIsUnchanged;
begin
  MakeFile('cur\one');
  MakeFile('cur\one.txt');
  MakeFile('cur\one.euo');
  MakeFile('cur\two.txt');
  MakeFile('cur\two.euo');
  MakeFile('cur\three.euo');
  AssertEquals('the name as written','cur\one',Resolve('one',[]));
  AssertEquals('.txt before .euo','cur\two.txt',Resolve('two',[]));
  AssertEquals('cur\three.euo',Resolve('three',[]));
  AssertEquals('a name with its extension','cur\three.euo',Resolve('three.euo',[]));
  AssertEquals('a relative path is put after #CurPath as written','cur\..\cur\one.txt',Resolve('..\cur\one.txt',[]));
  AssertEquals('not found','',Resolve('none',[]));
  AssertEquals('no folder list at all',Dir+'cur\two.txt',ResolveCallName('two',Dir+'cur\',nil));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestCurPathIsSearchedFirstAndInFull;
begin
  MakeFile('cur\helper.euo');
  MakeFile('a\helper');
  MakeFile('a\helper.txt');
  AssertEquals('#CurPath''s helper.euo wins over a list folder''s helper and helper.txt',
    'cur\helper.euo',Resolve('helper',[Dir+'a']));
  MakeFile('a\only.euo');
  AssertEquals('what #CurPath does not have comes from the folders','a\only.euo',Resolve('only',[Dir+'a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestFoldersAreSearchedOneAfterTheOther;
begin
  MakeFile('a\x.euo');
  MakeFile('b\x');
  AssertEquals('the first folder in full, .euo included, before the next','a\x.euo',
    Resolve('x',[Dir+'a',Dir+'b']));
  AssertEquals('the list''s order counts','b\x',Resolve('x',[Dir+'b',Dir+'a']));
  AssertEquals('a trailing backslash or none','b\x',Resolve('x',[Dir+'b\',Dir+'a']));
  MakeFile('c\y.txt');
  AssertEquals('c\y.txt',Resolve('y',[Dir+'a',Dir+'b',Dir+'c']));
  MakeFile('c\sub\z.euo');
  AssertEquals('a name with a folder in it, from a list folder','c\sub\z.euo',Resolve('sub\z',[Dir+'a',Dir+'c']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestRelativeFolderStartsFromCurPath;
begin
  MakeFile('cur\lib\r.euo');
  MakeFile('a\s.euo');
  AssertEquals('cur\lib\r.euo',Resolve('r',['lib']));
  AssertEquals('..\ leaves #CurPath','cur\..\a\s.euo',Resolve('s',['..\a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestAbsoluteNameSearchesNoFolder;
begin
  MakeFile('a\abs.euo');
  AssertEquals('an absolute name as written, then .euo','a\abs.euo',Resolve(Dir+'a\abs',[Dir+'b']));
  AssertEquals('missing where it says: no folder is searched','',Resolve(Dir+'b\abs',[Dir+'a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestMissingAndRepeatedFoldersAreSkipped;
begin
  MakeFile('b\m.euo');
  AssertEquals('b\m.euo',Resolve('m',[Dir+'nothere',Dir+'a',Dir+'A\',Dir+'cur',Dir+'b']));
  AssertEquals('an empty entry is no folder','',Resolve('m',['','  ']));
  AssertEquals('an empty name searches no folder','',Resolve('',[Dir+'b']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallPathTests.TestEnvFoldersComeBetweenTheTwoLists;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    CallSearchFolders('C:\list1;C:\list2','D:\last',L);
    AssertEquals('without EUOCALLPATH','C:\list1|C:\list2|D:\last',StringReplace(Trim(L.Text),LineEnding,'|',[rfReplaceAll]));
    SetEnv('E:\env1; "E:\env;2"');
    AssertEquals('read as it is set','E:\env1; "E:\env;2"',EnvCallPath);
    L.Clear;
    CallSearchFolders('C:\list1','D:\last',L);
    AssertEquals('the saved list, EUOCALLPATH, then the last folders',
      'C:\list1|E:\env1|E:\env;2|D:\last',StringReplace(Trim(L.Text),LineEnding,'|',[rfReplaceAll]));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// CALL itself, played line by line as EuoHostHooksTests plays scripts. #CurPath is the test
// program's folder, which has none of these files.
procedure TEuoCallPathTests.TestCallUsesTheFolders;
var
  Interp : TEuoInterpreter;
  Tag    : String;

  procedure Play(const Script : String);
  var
    Cnt : Integer;
  begin
    Interp.ScrList.Scr.Text:=Script;
    Interp.NextLine:=0;
    Interp.ResInt:=RES_OK;
    Cnt:=0;
    while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<200) do
    begin
      Interp.PlayLine;
      Inc(Cnt);
    end;
  end;

  function CallOf(const Name : String) : String;
  begin
    Interp.Clear;
    Play('set %from none'+LineEnding+'call '+Name+' x'+LineEnding+'halt');
    Result:=Interp.GetVar('%from');
  end;

begin
  Tag:='cpt'+IntToStr(GetProcessID);
  MakeFile('a\'+Tag+'list.euo','set %from list'+LineEnding+'exit');
  MakeFile('b\'+Tag+'env.txt','set %from env'+LineEnding+'set %arg %1'+LineEnding+'exit');
  MakeFile('c\'+Tag+'last.euo','set %from last'+LineEnding+'exit');
  MakeFile('a\'+Tag+'both.euo','set %from list'+LineEnding+'exit');
  MakeFile('c\'+Tag+'both.euo','set %from last'+LineEnding+'exit');

  Interp:=TEuoInterpreter.Create(0);
  try
    AssertEquals('no folders: not found, the line does nothing','none',CallOf(Tag+'list'));
    Interp.CallPath:=Dir+'a';
    AssertEquals('CallPath','list',CallOf(Tag+'list'));
    SetEnv(Dir+'b');
    AssertEquals('EUOCALLPATH','env',CallOf(Tag+'env'));
    AssertEquals('the call''s parameter arrives','x',Interp.GetVar('%arg'));
    AssertEquals('none',CallOf(Tag+'last'));
    Interp.CallPathLast:=Dir+'c';
    AssertEquals('CallPathLast','last',CallOf(Tag+'last'));
    AssertEquals('CallPath comes before CallPathLast','list',CallOf(Tag+'both'));
    AssertEquals('Clear leaves the host''s folders alone',Dir+'a',Interp.CallPath);
    Interp.CallPath:='';
    Interp.CallPathLast:='';
    SetEnv('');
    AssertEquals('none',CallOf(Tag+'both'));
  finally
    Interp.Free;
  end;
end;

initialization
  RegisterTest(TEuoCallPathTests);

end.
