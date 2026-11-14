unit DocsLintTests;

{
  Runs the script checker (parser\EuoLint.pas) over every script the project shows people:
  each euo example of the documentation site (website\src\content\docs) and of the agent
  pack's hand-written files (agent\), and the scripts in the repository
  (tools\EUOSelfTest\EUOSelfTest.euo, tests\euo\*.euo). A warning fails the suite.

  Readers and AI agents copy those examples, so a mistake in one is copied into every script
  written from it; and a checker that complained about the project's own, working scripts
  would be a checker nobody believes. Both are checked here at once.

  Some examples are wrong on purpose (a page that shows what a missing space does), and the
  self-test scripts do odd things to test them. Those are in Excepted below, by place and
  rule, each with its reason. An entry that no longer matches anything fails too, so the list
  cannot rot. CALL lines are not checked: an example's called file does not exist here.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter, EuoLint;

type
  TDocsLintTests = class(TTestCase)
  private
    Linter   : TEuoLinter;
    Problems : TStringList;
    Used     : array of Boolean;
    Checked  : Integer;
    procedure CollectFiles(const Dir, Mask : String; Files : TStringList);
    procedure CheckScript(const Place : String; Lines : TStrings);
    procedure CheckPage(const FN, Shown : String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEveryScriptOfTheProjectIsClean;
  end;

implementation

type
  TExcepted = record
    Place : String;   // 'language/expressions.md#2' (page, n-th euo example) or a script's path
    Rule  : String;
    Why   : String;
  end;

const
  MinToFind = 300;   // fewer scripts than this means the pages were not found or read

  Excepted : array[0..14] of TExcepted = (
    // ---- the site: examples that show a mistake, and one that is not a script -------------
    (Place: 'guides/execution-speed.md#1'; Rule: 'unknown-command';
     Why: 'pseudo-code of what EasyUO does each cycle ("run #LPC lines of the script"), marked as such'),
    (Place: 'language/common-mistakes.md#1'; Rule: 'unknown-command';
     Why: 'shows that a word that is no command is skipped'),
    (Place: 'language/common-mistakes.md#1'; Rule: 'unknown-variable';
     Why: 'shows that a #variable that does not exist reads N/A'),
    (Place: 'language/common-mistakes.md#1'; Rule: 'glued-words';
     Why: 'shows that %a+1 is one word'),
    (Place: 'language/common-mistakes.md#2'; Rule: 'glued-words';
     Why: 'shows that (%a > 1) is not understood'),
    (Place: 'language/common-mistakes.md#6'; Rule: 'stray-brace';
     Why: 'shows that a blank line between the if and its brace makes the block run always'),
    (Place: 'language/common-mistakes.md#13'; Rule: 'missing-sub';
     Why: 'shows that a gosub to a sub that does not exist does nothing'),
    (Place: 'language/expressions.md#3'; Rule: 'glued-words';
     Why: 'the "Spaces matter" example: its two lines marked wrong'),
    // ---- the self-test scripts: they do these things to test what happens -----------------
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'missing-label';
     Why: 'tests that a goto to a missing label does nothing'),
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'unknown-command';
     Why: 'tests that an unknown word is skipped'),
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'stray-brace';
     Why: 'tests that a block of its own always runs'),
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'missing-sub';
     Why: 'tests that a gosub to a missing sub does nothing'),
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'unknown-variable';
     Why: 'tests that an unknown #variable, and #strmax of the old keyword list, read N/A'),
    (Place: 'tests/euo/all-commands-test.euo'; Rule: 'unknown-subcommand';
     Why: 'tests that event sleep is accepted and does nothing'),
    (Place: 'tests/euo/call-helper.euo'; Rule: 'missing-sub';
     Why: 'tests that a called script cannot gosub a sub of the script that called it')
  );

////////////////////////////////////////////////////////////////////////////////
function RepoDir : String;
begin
  Result:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..')+PathDelim;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsLintTests.SetUp;
var
  Interp     : TEuoInterpreter;
  Cmds, Vars : TStringList;
begin
  Interp:=TEuoInterpreter.Create(0);
  Cmds:=TStringList.Create;
  Vars:=TStringList.Create;
  try
    Interp.GetCommandNames(Cmds);
    Interp.GetVariableNames(Vars);
    Linter:=TEuoLinter.Create(Cmds,Vars);
  finally
    Vars.Free;
    Cmds.Free;
    Interp.Free;
  end;
  Problems:=TStringList.Create;
  SetLength(Used,Length(Excepted));
  Checked:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsLintTests.TearDown;
begin
  Problems.Free;
  Linter.Free;
end;

////////////////////////////////////////////////////////////////////////////////
// Every file under Dir whose extension is in Mask ('.md.mdx', '.euo').
procedure TDocsLintTests.CollectFiles(const Dir, Mask : String; Files : TStringList);
var
  SR : TSearchRec;
begin
  if FindFirst(Dir+PathDelim+'*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then CollectFiles(Dir+PathDelim+SR.Name,Mask,Files)
      else if Pos(LowerCase(ExtractFileExt(SR.Name))+'.',Mask+'.')>0 then
        Files.Add(Dir+PathDelim+SR.Name);
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsLintTests.CheckScript(const Place : String; Lines : TStrings);
var
  Res  : TEuoLintResult;
  i, j : Integer;
  F    : TEuoFinding;
  Skip : Boolean;
begin
  Inc(Checked);
  Res:=TEuoLintResult.Create;
  try
    Linter.Check(Lines,Res);
    for i:=0 to Res.Count-1 do
    begin
      F:=Res[i];
      if F.Severity<>lsWarning then Continue;
      Skip:=False;
      for j:=Low(Excepted) to High(Excepted) do
        if (Excepted[j].Place=Place) and (Excepted[j].Rule=F.Rule) then
        begin
          Used[j]:=True;
          Skip:=True;
        end;
      if not Skip then
        Problems.Add(Place+', line '+IntToStr(F.Line)+': ['+F.Rule+'] '+F.Message);
    end;
  finally
    Res.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsLintTests.CheckPage(const FN, Shown : String);
var
  Text, Block : TStringList;
  i, N        : Integer;
  InBlock     : Boolean;
  S           : String;
begin
  Text:=TStringList.Create;
  Block:=TStringList.Create;
  try
    Text.LoadFromFile(FN);
    InBlock:=False;
    N:=0;
    for i:=0 to Text.Count-1 do
    begin
      S:=Trim(Text[i]);
      if not InBlock then
      begin
        if Copy(S,1,6)='```euo' then
        begin
          InBlock:=True;
          Block.Clear;
          Inc(N);
        end;
      end
      else if Copy(S,1,3)='```' then
      begin
        InBlock:=False;
        CheckScript(Shown+'#'+IntToStr(N),Block);
      end
      else Block.Add(Text[i]);
    end;
  finally
    Block.Free;
    Text.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDocsLintTests.TestEveryScriptOfTheProjectIsClean;
var
  Files, Lines : TStringList;
  i            : Integer;
  Root, Docs   : String;

  function Rel(const FN, Base : String) : String;
  begin
    Result:=StringReplace(Copy(FN,Length(Base)+1,MaxInt),'\','/',[rfReplaceAll]);
  end;

begin
  Root:=RepoDir;
  Docs:=Root+'website'+PathDelim+'src'+PathDelim+'content'+PathDelim+'docs';
  AssertTrue('The documentation pages are not at '+Docs,DirectoryExists(Docs));
  Files:=TStringList.Create;
  Lines:=TStringList.Create;
  try
    // the site's examples: 'language/expressions.md#2'
    CollectFiles(Docs,'.md.mdx',Files);
    Files.Sort;
    for i:=0 to Files.Count-1 do CheckPage(Files[i],Rel(Files[i],Docs+PathDelim));

    // the agent pack's hand-written files: 'agent/euo-script/SKILL.md#1'
    Files.Clear;
    CollectFiles(Root+'agent','.md',Files);
    Files.Sort;
    for i:=0 to Files.Count-1 do CheckPage(Files[i],Rel(Files[i],Root));

    // the repository's own scripts: 'tests/euo/call-helper.euo'
    Files.Clear;
    CollectFiles(Root+'tests'+PathDelim+'euo','.euo',Files);
    CollectFiles(Root+'tools'+PathDelim+'EUOSelfTest','.euo',Files);
    Files.Sort;
    for i:=0 to Files.Count-1 do
    begin
      Lines.LoadFromFile(Files[i]);
      CheckScript(Rel(Files[i],Root),Lines);
    end;

    for i:=Low(Excepted) to High(Excepted) do
      if not Used[i] then
        Problems.Add('Excepted lists '+Excepted[i].Place+' ['+Excepted[i].Rule+'], but nothing is reported there any more: remove the entry');

    if Problems.Count>0 then
      Fail(IntToStr(Problems.Count)+' warning(s) from the script checker in the project''s own scripts. Correct the script, '+
        'or list it in Excepted (tests\DocsLintTests.pas) with the reason:'+LineEnding+Problems.Text);
    AssertTrue('Only '+IntToStr(Checked)+' scripts were found; at least '+IntToStr(MinToFind)+' are expected',
      Checked>=MinToFind);
  finally
    Lines.Free;
    Files.Free;
  end;
end;

initialization
  RegisterTest(TDocsLintTests);

end.
