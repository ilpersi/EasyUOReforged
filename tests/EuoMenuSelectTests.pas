unit EuoMenuSelectTests;

{
  Which MENU logic a script runs under (EuoMenuSelect, and its use in TEuoInterpreter.Clear).
  The rules and the evidence behind them are in docs/menu-1.6-analysis.md, sections 6.2-6.3:
  "menu reforge mode" decides; otherwise a 1.6-only sub-command in real code selects 1.6; the
  files a script CALLs count only with "menu reforge includecall #true". The interpreter tests
  also pin what each logic does with #MenuButton/#MenuRes between runs, the notice for a 1.6
  line under an automatically chosen 1.5 logic, and that changing logic takes the 1.5 window
  down.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, fpcunit, testregistry, EuoMenuSelect, EuoInterpreter;

type
  // Stands in for TEuoInterpreter.ResolveCallFile: names map to files, and every name asked
  // for is recorded.
  TFakeCalls = class(TObject)
    Map   : TStringList;
    Asked : TStringList;
    constructor Create;
    destructor  Destroy; override;
    function    Resolve(const Name : String) : String;
  end;

  TEuoMenuSelectTests = class(TTestCase)
  private
    Dir   : String;
    Calls : TFakeCalls;
    function  Choose(const Script : String; out Forced : Boolean) : TMenuLogic; overload;
    function  Choose(const Script : String) : TMenuLogic; overload;
    function  AddFile(const Name, Text : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSplitFollowsParameterize;
    procedure TestEachOneSixOnlyWordSelectsOneSix;
    procedure TestOnlyRealCodeCounts;
    procedure TestReforgeModeForcesEitherLogic;
    procedure TestFirstValidModeWins;
    procedure TestInvalidModeMeansAutomatic;
    procedure TestIncludeCallValues;
    procedure TestCalledFilesAreIgnoredByDefault;
    procedure TestIncludeCallScansCalledFiles;
    procedure TestIncludeCallFollowsNestedCalls;
    procedure TestIncludeCallSurvivesACycle;
    procedure TestIncludeCallSkipsRuntimeNamesAndMissingFiles;
    procedure TestForcedModeWinsOverIncludeCall;
  end;

  TEuoMenuLogicTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    Dir    : String;
    procedure Start(const Script : String);
    procedure Play(Lines : Integer);
    procedure PlayToHalt;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestClearChoosesTheLogic;
    procedure TestReforgeLinesDoNothingAtRuntime;
    procedure TestIncludeCallResolvesNamesLikeCall;
    procedure TestOneSixMenuButtonAndMenuRes;
    procedure TestOneFiveKeepsMenuButtonBetweenRuns;
    procedure TestNoticeForOneSixLineUnderAutomaticOneFive;
    procedure TestNoNoticeWhenOneFiveIsForced;
    procedure TestNoticeNamesTheCalledFile;
    procedure TestChangingLogicTakesTheOneFiveWindowDown;
  end;

implementation

const
  CRLF = #13#10;

function MakeTempDir(const Tag : String) : String;
begin
  Result:=IncludeTrailingPathDelimiter(GetTempDir(False))+Tag+IntToStr(GetCurrentProcessId)+'\';
  ForceDirectories(Result);
end;

procedure WriteText(const Path, Text : String);
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Text:=Text;
    L.SaveToFile(Path);
  finally
    L.Free;
  end;
end;

procedure RemoveTempDir(const Dir : String);
var
  SR : TSearchRec;
begin
  if Dir='' then Exit;
  if FindFirst(Dir+'*',faAnyFile,SR)=0 then
  try
    repeat
      if (SR.Attr and faDirectory)=0 then DeleteFile(Dir+SR.Name);
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
  RemoveDir(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TFakeCalls.Create;
begin
  inherited Create;
  Map:=TStringList.Create;
  Asked:=TStringList.Create;
end;

destructor TFakeCalls.Destroy;
begin
  Map.Free;
  Asked.Free;
  inherited Destroy;
end;

function TFakeCalls.Resolve(const Name : String) : String;
begin
  Asked.Add(Name);
  Result:=Map.Values[UpperCase(Name)];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuSelectTests.SetUp;
begin
  Dir:=MakeTempDir('EuoMenuSelectTests');
  Calls:=TFakeCalls.Create;
end;

procedure TEuoMenuSelectTests.TearDown;
begin
  Calls.Free;
  RemoveTempDir(Dir);
end;

function TEuoMenuSelectTests.Choose(const Script : String; out Forced : Boolean) : TMenuLogic;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Text:=Script;
    Result:=ChooseMenuLogic(L,Calls.Resolve,Forced);
  finally
    L.Free;
  end;
end;

function TEuoMenuSelectTests.Choose(const Script : String) : TMenuLogic;
var
  Forced : Boolean;
begin
  Result:=Choose(Script,Forced);
end;

// A file the fake CALL resolver finds under Name.
function TEuoMenuSelectTests.AddFile(const Name, Text : String) : String;
begin
  Result:=Dir+Name;
  WriteText(Result,Text);
  Calls.Map.Values[UpperCase(Name)]:=Result;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuSelectTests.TestSplitFollowsParameterize;
var
  W : TStringList;
begin
  W:=TStringList.Create;
  try
    SplitScriptLine('  menu'#9'form  f ;rest of line', W);
    AssertEquals(3, W.Count);
    AssertEquals('menu', W[0]);
    AssertEquals('form', W[1]);
    AssertEquals('f', W[2]);
    SplitScriptLine('menu form;f', W);   // ';' only starts a comment at the start of a word
    AssertEquals(2, W.Count);
    AssertEquals('form;f', W[1]);
    SplitScriptLine('; menu form f', W);
    AssertEquals(0, W.Count);
  finally
    W.Free;
  end;
end;

procedure TEuoMenuSelectTests.TestEachOneSixOnlyWordSelectsOneSix;
const
  Words : array[0..8] of String =
    ('form', 'Panel', 'RADIO', 'getprop', 'SetProp', 'getdef', 'setdef', 'pushdef', 'popdef');
var
  Cnt : Integer;
begin
  for Cnt:=Low(Words) to High(Words) do
    AssertTrue(Words[Cnt], Choose('menu text t 1 1 hi'+CRLF+'Menu '+Words[Cnt]+' x 1')=mlMenu16);
  AssertTrue('old commands only', Choose('menu clear'+CRLF+'menu button b 1 1 10 10 Go'+CRLF+
    'menu font transparent #true'+CRLF+'menu hideeuo')=mlMenu15);
  AssertTrue('empty script', Choose('')=mlMenu15);
end;

procedure TEuoMenuSelectTests.TestOnlyRealCodeCounts;
begin
  AssertTrue('comment line', Choose('; menu form f 1 1 10 10')=mlMenu15);
  AssertTrue('trailing comment', Choose('menu text t 1 1 hi ; menu setprop t visible #false')=mlMenu15);
  AssertTrue('longer word', Choose('menu formx f 1 1 10 10')=mlMenu15);
  AssertTrue('no space', Choose('menuform f')=mlMenu15);
  AssertTrue('sub-command from a variable', Choose('menu %sub f 1 1 10 10')=mlMenu15);
  AssertTrue('not a MENU line', Choose('set %form setprop')=mlMenu15);
  AssertTrue('tabs and leading blanks', Choose(#9'  MENU'#9'SetProp b visible #true')=mlMenu16);
end;

procedure TEuoMenuSelectTests.TestReforgeModeForcesEitherLogic;
var
  Forced : Boolean;
begin
  AssertTrue(Choose('menu reforge mode 1.5'+CRLF+'menu form f 1 1 10 10', Forced)=mlMenu15);
  AssertTrue('forced', Forced);
  AssertTrue(Choose('menu text t 1 1 hi'+CRLF+'menu reforge mode 1.6', Forced)=mlMenu16);
  AssertTrue('forced, from the last line too', Forced);
  AssertTrue(Choose('menu setprop t visible #true', Forced)=mlMenu16);
  AssertFalse('detected, not forced', Forced);
end;

procedure TEuoMenuSelectTests.TestFirstValidModeWins;
var
  Forced : Boolean;
begin
  AssertTrue(Choose('menu reforge mode 2.0'+CRLF+'menu reforge mode %m'+CRLF+
    'MENU REFORGE MODE 1.6'+CRLF+'menu reforge mode 1.5', Forced)=mlMenu16);
  AssertTrue(Forced);
end;

procedure TEuoMenuSelectTests.TestInvalidModeMeansAutomatic;
var
  Forced : Boolean;
begin
  AssertTrue(Choose('menu reforge mode 2'+CRLF+'menu setprop t visible #true', Forced)=mlMenu16);
  AssertFalse(Forced);
  AssertTrue(Choose('menu reforge mode', Forced)=mlMenu15);
  AssertFalse(Forced);
  AssertTrue('a mode in a comment', Choose('; menu reforge mode 1.6', Forced)=mlMenu15);
  AssertFalse(Forced);
end;

procedure TEuoMenuSelectTests.TestIncludeCallValues;

  function IncludeCallOf(const Lines : String) : Boolean;
  var
    L : TStringList;
    S : TMenuSettings;
  begin
    L:=TStringList.Create;
    try
      L.Text:=Lines;
      ReadMenuSettings(L,S);
      Result:=S.IncludeCall;
    finally
      L.Free;
    end;
  end;

begin
  AssertFalse('default', IncludeCallOf('menu text t 1 1 hi'));
  AssertTrue('#true', IncludeCallOf('menu reforge includecall #true'));
  AssertTrue('TRUE', IncludeCallOf('menu reforge includecall TRUE'));
  AssertTrue('1', IncludeCallOf('menu reforge includecall 1'));
  AssertTrue('-1', IncludeCallOf('menu reforge includecall -1'));
  AssertFalse('#false', IncludeCallOf('menu reforge includecall #false'));
  AssertFalse('0', IncludeCallOf('menu reforge includecall 0'));
  AssertTrue('invalid value skipped', IncludeCallOf('menu reforge includecall yes'+CRLF+'menu reforge includecall #true'));
  AssertFalse('first valid wins', IncludeCallOf('menu reforge includecall #false'+CRLF+'menu reforge includecall #true'));
  AssertFalse('variable is not read', IncludeCallOf('menu reforge includecall %inc'));
end;

procedure TEuoMenuSelectTests.TestCalledFilesAreIgnoredByDefault;
begin
  AddFile('lib.txt', 'menu form f 1 1 10 10');
  AssertTrue(Choose('call lib.txt')=mlMenu15);
  AssertEquals('nothing resolved', 0, Calls.Asked.Count);
end;

procedure TEuoMenuSelectTests.TestIncludeCallScansCalledFiles;
begin
  AddFile('lib.txt', 'menu text t 1 1 hi'+CRLF+'menu setprop t visible #true');
  AssertTrue(Choose('menu reforge includecall #true'+CRLF+'call lib.txt arg1 arg2')=mlMenu16);
  AssertTrue('a 1.5 library leaves 1.5', Choose('menu reforge includecall #true'+CRLF+'call other.txt')=mlMenu15);
end;

procedure TEuoMenuSelectTests.TestIncludeCallFollowsNestedCalls;
begin
  AddFile('a.txt', 'call b.txt');
  AddFile('b.txt', 'menu panel p 1 1 10 10');
  AssertTrue(Choose('menu reforge includecall #true'+CRLF+'call a.txt')=mlMenu16);
end;

procedure TEuoMenuSelectTests.TestIncludeCallSurvivesACycle;
begin
  AddFile('a.txt', 'call b.txt');
  AddFile('b.txt', 'call a.txt'+CRLF+'call b.txt');
  AssertTrue(Choose('menu reforge includecall #true'+CRLF+'call a.txt')=mlMenu15);
  AssertTrue('each file read once', Calls.Asked.Count<=4);
end;

procedure TEuoMenuSelectTests.TestIncludeCallSkipsRuntimeNamesAndMissingFiles;
begin
  AddFile('lib.txt', 'menu form f 1 1 10 10');
  AssertTrue(Choose('menu reforge includecall #true'+CRLF+'call %lib'+CRLF+'call !lib'+CRLF+
    'call lib , .txt'+CRLF+'call missing.txt')=mlMenu15);
  AssertEquals('only the literal name is resolved', 1, Calls.Asked.Count);
  AssertEquals('missing.txt', Calls.Asked[0]);
end;

procedure TEuoMenuSelectTests.TestForcedModeWinsOverIncludeCall;
var
  Forced : Boolean;
begin
  AddFile('lib.txt', 'menu form f 1 1 10 10');
  AssertTrue(Choose('menu reforge mode 1.5'+CRLF+'menu reforge includecall #true'+CRLF+'call lib.txt', Forced)=mlMenu15);
  AssertTrue(Forced);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuLogicTests.SetUp;
begin
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
  Dir:='';
end;

procedure TEuoMenuLogicTests.TearDown;
begin
  Interp.Free;
  RemoveTempDir(Dir);
end;

// What a stopped script's Play does: the text is loaded, then Clear runs (and chooses).
procedure TEuoMenuLogicTests.Start(const Script : String);
begin
  Interp.ScrList.Scr.Text:=Script;
  Interp.Clear;
  Interp.NextLine:=0;
end;

procedure TEuoMenuLogicTests.Play(Lines : Integer);
var
  Cnt : Integer;
begin
  for Cnt:=1 to Lines do Interp.PlayLine;
end;

procedure TEuoMenuLogicTests.PlayToHalt;
var
  Cnt : Integer;
begin
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<1000) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuLogicTests.TestClearChoosesTheLogic;
begin
  AssertTrue('a new interpreter starts on 1.5', Interp.MenuLogic=mlMenu15);
  Start('menu text t 1 1 hi'+CRLF+'menu setprop t visible #true'+CRLF+'HALT');
  AssertTrue(Interp.MenuLogic=mlMenu16);
  Start('menu text t 1 1 hi'+CRLF+'HALT');
  AssertTrue(Interp.MenuLogic=mlMenu15);
  Start('menu reforge mode 1.6'+CRLF+'HALT');
  AssertTrue(Interp.MenuLogic=mlMenu16);
  // the text changing during a run does not change the logic: only Clear chooses
  Interp.ScrList.Scr.Text:='menu text t 1 1 hi'+CRLF+'HALT';
  PlayToHalt;
  AssertTrue(Interp.MenuLogic=mlMenu16);
end;

procedure TEuoMenuLogicTests.TestReforgeLinesDoNothingAtRuntime;
begin
  Start('menu reforge mode 1.5'+CRLF+'menu reforge includecall #true'+CRLF+
    'menu reforge'+CRLF+'set %done yes'+CRLF+'HALT');
  PlayToHalt;
  AssertEquals('yes', Interp.GetVar('%done'));
  AssertTrue(Interp.MenuLogic=mlMenu15);
  AssertEquals('', Interp.MenuNotice);
end;

procedure TEuoMenuLogicTests.TestIncludeCallResolvesNamesLikeCall;
begin
  // CALL tries the name, then .txt, then .euo; the scan must find the same file.
  Dir:=MakeTempDir('EuoMenuLogicTests');
  if Pos(' ', Dir)>0 then
  begin
    Ignore('the temp folder has a space, which a CALL line cannot carry');
    Exit;
  end;
  WriteText(Dir+'lib.euo', 'menu panel p 1 1 10 10');
  Start('menu reforge includecall #true'+CRLF+'call '+Dir+'lib'+CRLF+'HALT');
  AssertTrue('lib -> lib.euo', Interp.MenuLogic=mlMenu16);
  WriteText(Dir+'plain.txt', 'menu text t 1 1 hi');
  Start('menu reforge includecall #true'+CRLF+'call '+Dir+'plain'+CRLF+'HALT');
  AssertTrue('lib -> plain.txt, no 1.6 command', Interp.MenuLogic=mlMenu15);
end;

procedure TEuoMenuLogicTests.TestOneSixMenuButtonAndMenuRes;
begin
  Start('menu reforge mode 1.6'+CRLF+'HALT');
  Interp.SetVar('#menubutton', 'form0');
  AssertEquals('form0 reads back as CLOSED', 'CLOSED', Interp.GetVar('#menubutton'));
  Interp.SetVar('#menubutton', 'FORM0');
  AssertEquals('only the exact string', 'FORM0', Interp.GetVar('#menubutton'));
  Interp.SetVar('#menubutton', 'ok');
  Interp.SetVar('#menures', 'value');
  AssertEquals('ok', Interp.GetVar('#menubutton'));
  AssertEquals('value', Interp.GetVar('#menures'));
  Start('menu reforge mode 1.6'+CRLF+'HALT');
  AssertEquals('emptied at start', '', Interp.GetVar('#menubutton'));
  AssertEquals('emptied at start', '', Interp.GetVar('#menures'));
end;

procedure TEuoMenuLogicTests.TestOneFiveKeepsMenuButtonBetweenRuns;
begin
  Start('menu text t 1 1 hi'+CRLF+'HALT');
  Interp.SetVar('#menubutton', 'Quit');
  Interp.SetVar('#menubutton', 'form0');
  Start('menu text t 1 1 hi'+CRLF+'HALT');
  AssertEquals('1.5 keeps the last value and has no form0 rule', 'form0', Interp.GetVar('#menubutton'));
end;

procedure TEuoMenuLogicTests.TestNoticeForOneSixLineUnderAutomaticOneFive;
begin
  // A sub-command taken from a variable is invisible to the scan, so this runs under 1.5.
  Start('set %sub setprop'+CRLF+'menu %sub t visible #true'+CRLF+'menu %sub t visible #false'+CRLF+'HALT');
  AssertTrue(Interp.MenuLogic=mlMenu15);
  Play(2);
  AssertTrue('names the command', Pos('MENU SETPROP', Interp.MenuNotice)>0);
  AssertTrue('says how to fix it', Pos('menu reforge mode 1.6', Interp.MenuNotice)>0);
  Interp.MenuNotice:='';   // the GUI consumed it
  Play(1);
  AssertEquals('once per run', '', Interp.MenuNotice);
  Start('set %sub setprop'+CRLF+'menu %sub t visible #true'+CRLF+'HALT');
  Play(2);
  AssertTrue('again in the next run', Interp.MenuNotice<>'');
end;

procedure TEuoMenuLogicTests.TestNoNoticeWhenOneFiveIsForced;
begin
  Start('menu reforge mode 1.5'+CRLF+'menu form f 1 1 10 10'+CRLF+'menu setprop f visible #true'+CRLF+'HALT');
  PlayToHalt;
  AssertTrue(Interp.MenuLogic=mlMenu15);
  AssertEquals('', Interp.MenuNotice);
end;

procedure TEuoMenuLogicTests.TestNoticeNamesTheCalledFile;
begin
  Dir:=MakeTempDir('EuoMenuLogicTests');
  if Pos(' ', Dir)>0 then
  begin
    Ignore('the temp folder has a space, which a CALL line cannot carry');
    Exit;
  end;
  WriteText(Dir+'lib16.txt', 'menu form f 1 1 10 10');
  Start('call '+Dir+'lib16.txt'+CRLF+'HALT');
  AssertTrue('called files are not scanned by default', Interp.MenuLogic=mlMenu15);
  PlayToHalt;
  AssertTrue('names the file', Pos('lib16.txt', Interp.MenuNotice)>0);
  AssertTrue('suggests includecall', Pos('menu reforge includecall #true', Interp.MenuNotice)>0);
end;

procedure TEuoMenuLogicTests.TestChangingLogicTakesTheOneFiveWindowDown;
var
  Title : String;
  Wnd   : HWND;
begin
  Application.Initialize;
  Title:='EuoMenuLogicTests'+IntToStr(GetCurrentProcessId);
  Start('menu window title '+Title+CRLF+'menu text t 1 1 hi'+CRLF+'menu show'+CRLF+'HALT');
  PlayToHalt;
  Application.ProcessMessages;
  Wnd:=FindWindow(nil, PChar(Title));
  if (Wnd=0) or not IsWindowVisible(Wnd) then
  begin
    Ignore('MENU form could not be shown in this session');
    Exit;
  end;

  Interp.SetVar('#menubutton', 'kept');

  Start('menu setprop t visible #true'+CRLF+'HALT');
  Application.ProcessMessages;
  AssertTrue(Interp.MenuLogic=mlMenu16);
  AssertFalse('the 1.5 window is hidden', IsWindowVisible(Wnd));

  Start('menu text t 1 1 hi'+CRLF+'HALT');
  Application.ProcessMessages;
  AssertTrue('back to 1.5', Interp.MenuLogic=mlMenu15);
  AssertFalse('and its window stays hidden until the script shows it', IsWindowVisible(Wnd));
  AssertEquals('hiding is not closing: 1.5''s #MenuButton untouched', 'kept', Interp.GetVar('#menubutton'));
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoMenuSelectTests);
  RegisterTest(TEuoMenuLogicTests);
end.
