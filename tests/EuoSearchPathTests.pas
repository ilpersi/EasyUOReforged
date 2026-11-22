unit EuoSearchPathTests;

{
  Tests for parser\EuoSearchPath.pas, the folders CALL and SQL OPEN search, and for CALL using them through
  TEuoInterpreter.SearchPath / SearchPathLast. Each test works in its own folder under the temp
  folder; EUOPATH is emptied for every test and put back after, so the machine's own value
  never shows.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoSearchPath, EuoInterpreter;

type
  TEuoSearchPathTests = class(TTestCase)
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
    procedure TestSplitSearchPath;
    procedure TestJoinSearchPath;
    procedure TestTheOriginalLookupIsUnchanged;
    procedure TestCurPathIsSearchedFirstAndInFull;
    procedure TestFoldersAreSearchedOneAfterTheOther;
    procedure TestRelativeFolderStartsFromCurPath;
    procedure TestAbsoluteNameSearchesNoFolder;
    procedure TestMissingAndRepeatedFoldersAreSkipped;
    procedure TestSqlExtensions;
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
procedure TEuoSearchPathTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euosearchpath-'+IntToStr(GetProcessID)+PathDelim;
  RemoveTree(Dir);
  ForceDirectories(Dir+'cur');
  ForceDirectories(Dir+'a');
  ForceDirectories(Dir+'b');
  ForceDirectories(Dir+'c');
  OldEnv:=EnvEuoPath;
  SetEnv('');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.TearDown;
begin
  SetEnv(OldEnv);
  RemoveTree(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.MakeFile(const RelPath : String; const Text : String);
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
procedure TEuoSearchPathTests.SetEnv(const Value : String);
var
  Name, V : UnicodeString;
begin
  Name:=EuoPathEnvVar;
  if Value='' then SetEnvironmentVariableW(PWideChar(Name),nil)
  else begin
    V:=UTF8Decode(Value);
    SetEnvironmentVariableW(PWideChar(Name),PWideChar(V));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// ResolveSearchName for CALL (CallExts) with #CurPath = Dir\cur\, the result without Dir in front.
function TEuoSearchPathTests.Resolve(const Name : String; const Folders : array of String) : String;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    for i:=Low(Folders) to High(Folders) do L.Add(Folders[i]);
    Result:=ResolveSearchName(Name,Dir+'cur\',L,CallExts);
  finally
    L.Free;
  end;
  if Copy(Result,1,Length(Dir))=Dir then Delete(Result,1,Length(Dir));
end;

////////////////////////////////////////////////////////////////////////////////
// SplitSearchPath's entries joined with '|'.
function TEuoSearchPathTests.Split(const Text : String) : String;
var
  L : TStringList;
  i : Integer;
begin
  L:=TStringList.Create;
  try
    SplitSearchPath(Text,L);
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
procedure TEuoSearchPathTests.TestSplitSearchPath;
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
procedure TEuoSearchPathTests.TestJoinSearchPath;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Add(' C:\a ');
    L.Add('');
    L.Add('C:\My;Scripts');
    L.Add('lib');
    AssertEquals('C:\a;"C:\My;Scripts";lib',JoinSearchPath(L));
    AssertEquals('it splits back the same','C:\a|C:\My;Scripts|lib',Split(JoinSearchPath(L)));
    L.Clear;
    AssertEquals('',JoinSearchPath(L));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// What the original CallProc found, it still finds: the name as written, then .txt, then .euo.
procedure TEuoSearchPathTests.TestTheOriginalLookupIsUnchanged;
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
  AssertEquals('no folder list at all',Dir+'cur\two.txt',ResolveSearchName('two',Dir+'cur\',nil,CallExts));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.TestCurPathIsSearchedFirstAndInFull;
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
procedure TEuoSearchPathTests.TestFoldersAreSearchedOneAfterTheOther;
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
procedure TEuoSearchPathTests.TestRelativeFolderStartsFromCurPath;
begin
  MakeFile('cur\lib\r.euo');
  MakeFile('a\s.euo');
  AssertEquals('cur\lib\r.euo',Resolve('r',['lib']));
  AssertEquals('..\ leaves #CurPath','cur\..\a\s.euo',Resolve('s',['..\a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.TestAbsoluteNameSearchesNoFolder;
begin
  MakeFile('a\abs.euo');
  AssertEquals('an absolute name as written, then .euo','a\abs.euo',Resolve(Dir+'a\abs',[Dir+'b']));
  AssertEquals('missing where it says: no folder is searched','',Resolve(Dir+'b\abs',[Dir+'a']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.TestMissingAndRepeatedFoldersAreSkipped;
begin
  MakeFile('b\m.euo');
  AssertEquals('b\m.euo',Resolve('m',[Dir+'nothere',Dir+'a',Dir+'A\',Dir+'cur',Dir+'b']));
  AssertEquals('an empty entry is no folder','',Resolve('m',['','  ']));
  AssertEquals('an empty name searches no folder','',Resolve('',[Dir+'b']));
end;

////////////////////////////////////////////////////////////////////////////////
// SQL OPEN's list: the name, then .db, then .sqlite, folder by folder as for CALL.
procedure TEuoSearchPathTests.TestSqlExtensions;
var
  L : TStringList;

  function Db(const Name : String) : String;
  begin
    Result:=ResolveSearchName(Name,Dir+'cur\',L,SqlExts);
    if Copy(Result,1,Length(Dir))=Dir then Delete(Result,1,Length(Dir));
  end;

begin
  L:=TStringList.Create;
  try
    L.Add(Dir+'a');
    MakeFile('cur\data.sqlite');
    MakeFile('a\data.db');
    MakeFile('cur\both.db');
    MakeFile('cur\both.sqlite');
    MakeFile('a\only.sqlite');
    MakeFile('cur\script.txt');
    AssertEquals('#CurPath in full first: its .sqlite before a list folder''s .db','cur\data.sqlite',Db('data'));
    AssertEquals('.db before .sqlite','cur\both.db',Db('both'));
    AssertEquals('from a list folder','a\only.sqlite',Db('only'));
    AssertEquals('the name as written','cur\data.sqlite',Db('data.sqlite'));
    AssertEquals('CALL''s .txt is not tried','',Db('script'));
    AssertEquals('and SQL''s are not tried for CALL','',Resolve('data',[Dir+'a']));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSearchPathTests.TestEnvFoldersComeBetweenTheTwoLists;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    SearchFolders('C:\list1;C:\list2','D:\last',L);
    AssertEquals('without EUOPATH','C:\list1|C:\list2|D:\last',StringReplace(Trim(L.Text),LineEnding,'|',[rfReplaceAll]));
    SetEnv('E:\env1; "E:\env;2"');
    AssertEquals('read as it is set','E:\env1; "E:\env;2"',EnvEuoPath);
    L.Clear;
    SearchFolders('C:\list1','D:\last',L);
    AssertEquals('the saved list, EUOPATH, then the last folders',
      'C:\list1|E:\env1|E:\env;2|D:\last',StringReplace(Trim(L.Text),LineEnding,'|',[rfReplaceAll]));
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// CALL itself, played line by line as EuoHostHooksTests plays scripts. #CurPath is the test
// program's folder, which has none of these files.
procedure TEuoSearchPathTests.TestCallUsesTheFolders;
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
    Interp.SearchPath:=Dir+'a';
    AssertEquals('SearchPath','list',CallOf(Tag+'list'));
    SetEnv(Dir+'b');
    AssertEquals('EUOPATH','env',CallOf(Tag+'env'));
    AssertEquals('the call''s parameter arrives','x',Interp.GetVar('%arg'));
    AssertEquals('none',CallOf(Tag+'last'));
    Interp.SearchPathLast:=Dir+'c';
    AssertEquals('SearchPathLast','last',CallOf(Tag+'last'));
    AssertEquals('SearchPath comes before SearchPathLast','list',CallOf(Tag+'both'));
    AssertEquals('Clear leaves the host''s folders alone',Dir+'a',Interp.SearchPath);
    Interp.SearchPath:='';
    Interp.SearchPathLast:='';
    SetEnv('');
    AssertEquals('none',CallOf(Tag+'both'));
  finally
    Interp.Free;
  end;
end;

initialization
  RegisterTest(TEuoSearchPathTests);

end.
