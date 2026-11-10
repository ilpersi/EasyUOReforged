unit EuoCliCheckTests;

{
  Tests for EUOCli's command line (tools\EUOCli\climain.pas) and its "check" command
  (clicheck.pas), called as EUOCli.lpr calls them: arguments in, printed lines and exit code
  out. What the checker finds is EuoLintTests' business; here it is how it is asked and how
  it answers.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, climain, clicheck, ReforgedVersion;

type
  TEuoCliCheckTests = class(TTestCase)
  private
    Dir    : String;
    Output : TStringList;
    // Runs "EUOCli <Args>" (words separated by '|') with StdIn piped in; returns the exit code.
    function  Run(const Args : String; const StdIn : String = '') : Integer;
    function  Script(const Name : String; const Lines : array of String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestVersionAndHelp;
    procedure TestUsageErrors;
    procedure TestPlainOutput;
    procedure TestCleanScript;
    procedure TestStrictExitCode;
    procedure TestJsonOutput;
    procedure TestStdIn;
    procedure TestSeveralFiles;
    procedure TestCurPath;
    procedure TestOldEncodingIsRead;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euocli-'+IntToStr(GetProcessID);
  ForceDirectories(Dir);
  Output:=TStringList.Create;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TearDown;
var
  SR : TSearchRec;
begin
  Output.Free;
  if FindFirst(Dir+PathDelim+'*',faAnyFile,SR)=0 then
  begin
    repeat
      if (SR.Attr and faDirectory)=0 then DeleteFile(Dir+PathDelim+SR.Name);
    until FindNext(SR)<>0;
    FindClose(SR);
  end;
  RemoveDir(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliCheckTests.Run(const Args : String; const StdIn : String) : Integer;
var
  SL : TStringList;
begin
  SL:=TStringList.Create;
  try
    SL.Delimiter:='|';
    SL.StrictDelimiter:=True;
    SL.DelimitedText:=Args;
    Output.Clear;
    // The program's folder is where CALL starts from by default; here it is the temp folder.
    Result:=RunCli(SL,StdIn,Dir,Output);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliCheckTests.Script(const Name : String; const Lines : array of String) : String;
var
  SL  : TStringList;
  Cnt : Integer;
begin
  Result:=Dir+PathDelim+Name;
  SL:=TStringList.Create;
  try
    for Cnt:=Low(Lines) to High(Lines) do SL.Add(Lines[Cnt]);
    SL.SaveToFile(Result);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestVersionAndHelp;
begin
  AssertEquals(CLI_OK,Run('version'));
  AssertEquals(REFORGED_VERSION,Trim(Output.Text));
  AssertEquals(CLI_OK,Run('help'));
  AssertTrue('help lists check',Pos('EUOCli check',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|check'));
  AssertTrue('check''s own help',Pos('--strict',Output.Text)>0);
  AssertEquals('no command at all is a usage error, with the help',CLI_USAGE,Run(''));
  AssertTrue(Pos('EUOCli check',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestUsageErrors;
begin
  AssertEquals(CLI_USAGE,Run('frobnicate'));
  AssertTrue(Pos('unknown command',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('check'));
  AssertTrue(Pos('no script given',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('check|'+Dir+PathDelim+'nothere.euo'));
  AssertTrue(Pos('file not found',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('check|--frob|x.euo'));
  AssertTrue(Pos('unknown option --frob',Output.Text)>0);
  AssertEquals(CLI_USAGE,Run('check|x.euo|--curpath'));
  AssertTrue(Pos('--curpath needs a folder',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestPlainOutput;
var
  FN : String;
begin
  FN:=Script('bad.euo',['set %a 1','  finditm POF','halt']);
  AssertEquals('warnings alone do not change the exit code',CLI_OK,Run('check|'+FN));
  AssertEquals(FN+':2:3: warning [unknown-command] "finditm" is not a command: the interpreter skips this line without an error.',
    Output[0]);
  AssertTrue('the hint is indented under it',Copy(Output[1],1,4)='    ');
  AssertEquals(FN+': 1 warning, 0 notes',Output[Output.Count-1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestCleanScript;
var
  FN : String;
begin
  FN:=Script('good.euo',['set %a 1','halt']);
  AssertEquals(CLI_OK,Run('check|'+FN+'|--strict'));
  AssertEquals(FN+': nothing found',Trim(Output.Text));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestStrictExitCode;
var
  FN : String;
begin
  FN:=Script('bad.euo',['set %a #nosuch','halt']);
  AssertEquals(CLI_WARNINGS,Run('check|--strict|'+FN));
  AssertEquals('the option may come after the file',CLI_WARNINGS,Run('check|'+FN+'|--strict'));
  // a note is no warning
  FN:=Script('client.euo',['finditem POF','halt']);
  AssertEquals(CLI_OK,Run('check|--strict|'+FN));
  AssertEquals(FN+': 0 warnings, 1 note',Output[Output.Count-1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestJsonOutput;
var
  FN      : String;
  Data    : TJSONData;
  Root    : TJSONObject;
  FileObj : TJSONObject;
  Finding : TJSONObject;
begin
  FN:=Script('bad.euo',['menu clear','finditem POF','set %a %b+1','halt']);
  AssertEquals(CLI_WARNINGS,Run('check|--json|--strict|'+FN));
  Data:=GetJSON(Output.Text);
  try
    Root:=Data as TJSONObject;
    AssertEquals(REFORGED_VERSION,Root.Get('version',''));
    AssertEquals(1,Root.Get('warnings',-1));
    AssertEquals(2,Root.Get('notes',-1));
    AssertEquals(1,Root.Arrays['files'].Count);
    FileObj:=Root.Arrays['files'].Objects[0];
    AssertEquals(FN,FileObj.Get('file',''));
    AssertEquals(4,FileObj.Get('lines',-1));
    AssertEquals(3,FileObj.Arrays['findings'].Count);

    Finding:=FileObj.Arrays['findings'].Objects[0];
    AssertEquals('glued-words',Finding.Get('rule',''));
    AssertEquals('warning',Finding.Get('severity',''));
    AssertEquals(3,Finding.Get('line',-1));
    AssertEquals(8,Finding.Get('column',-1));
    AssertEquals('%b+1',Finding.Get('word',''));
    AssertTrue(Finding.Get('message','')<>'');
    AssertTrue(Finding.Get('hint','')<>'');
    AssertEquals('whole-script notes come last','note',
      FileObj.Arrays['findings'].Objects[2].Get('severity',''));

    AssertEquals(1,FileObj.Objects['summary'].Get('warnings',-1));
    AssertEquals(2,FileObj.Objects['summary'].Get('notes',-1));
    AssertEquals('1.5',FileObj.Objects['summary'].Get('menuLogic',''));
    AssertEquals('finditem',FileObj.Objects['summary'].Arrays['clientCommands'].Strings[0]);
  finally
    Data.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestStdIn;
begin
  AssertEquals(CLI_WARNINGS,Run('check|-|--strict','set %a 1'+LineEnding+'frob'+LineEnding+'halt'+LineEnding));
  AssertEquals('<stdin>:2:1: warning [unknown-command] "frob" is not a command: the interpreter skips this line without an error.',
    Output[0]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestSeveralFiles;
var
  A, B : String;
begin
  A:=Script('a.euo',['set %a 1','halt']);
  B:=Script('b.euo',['frob','halt']);
  AssertEquals(CLI_WARNINGS,Run('check|--strict|'+A+'|'+B));
  AssertEquals(A+': nothing found',Output[0]);
  AssertEquals(B+': 1 warning, 0 notes',Output[Output.Count-1]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliCheckTests.TestCurPath;
var
  FN, Other : String;
begin
  Script('lib.euo',['exit']);
  FN:=Script('main.euo',['call lib.euo','halt']);
  AssertEquals('found in the program''s folder',CLI_OK,Run('check|--strict|'+FN));
  Other:=IncludeTrailingPathDelimiter(GetTempDir);
  AssertEquals('not found from another folder',CLI_WARNINGS,Run('check|--strict|--curpath|'+Other+'|'+FN));
  AssertTrue(Pos('[missing-call-file]',Output.Text)>0);
  AssertEquals('--curpath=folder too',CLI_WARNINGS,Run('check|--strict|--curpath='+Other+'|'+FN));
end;

////////////////////////////////////////////////////////////////////////////////
// A script saved in the old ANSI encoding is read as the editor reads it, so a byte that is
// not UTF-8 does not turn its line into something else.
procedure TEuoCliCheckTests.TestOldEncodingIsRead;
var
  FN : String;
  FS : TFileStream;
  S  : RawByteString;
begin
  FN:=Dir+PathDelim+'ansi.euo';
  S:='set %a caf'#$E9#13#10'frob'#13#10'halt'#13#10;
  FS:=TFileStream.Create(FN,fmCreate);
  try
    FS.WriteBuffer(S[1],Length(S));
  finally
    FS.Free;
  end;
  AssertEquals(CLI_WARNINGS,Run('check|--strict|'+FN));
  AssertEquals(FN+': 1 warning, 0 notes',Output[Output.Count-1]);
  AssertTrue('the finding is on the right line',Pos(':2:1: warning [unknown-command]',Output[0])>0);
end;

initialization
  RegisterTest(TEuoCliCheckTests);

end.
