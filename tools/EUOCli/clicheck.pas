unit clicheck;

{
  Port addition (docs\agent-support.md, phase 2): "EUOCli check", the script checker as a
  command. It reads each script as the editor reads a file (easyuo\scriptfile.pas), checks it
  with parser\EuoLint.pas and prints the findings, as text or as JSON. The names it checks
  against come from a TEuoInterpreter it creates and never runs, so there is no copy of them
  here. No script is loaded into it and it selects no client. (The program as a whole does
  look for running clients when it starts, as the editor does: linking the engine starts
  uo\uoselector.pas's scan. This command makes no use of what that finds.)

  Everything is in this unit, arguments in and lines out, so the test suite calls it as the
  program does (tests\EuoCliCheckTests.pas).

  Exit codes: 0 checked; 1 checked, --strict was given and there is at least one warning;
  2 the command line is wrong or a file cannot be read.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

const
  CLI_OK       = 0;
  CLI_WARNINGS = 1;
  CLI_USAGE    = 2;

// "EUOCli check <Args>". StdInText is the script "-" stands for. ExeDir is the folder CALL
// lines are resolved from when --curpath is not given: the program's own folder, which in a
// release is the folder of EasyUOReforged.exe (#CurPath).
function RunCheck(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;

procedure CheckHelp(Output : TStrings);

// One script's findings, as "check --json" gives them for one file: for the MCP server.
// Shown is the name to report; CurPath the folder CALL lines are resolved from.
function CheckScriptJson(const Text, Shown, CurPath : String) : TJSONObject;

implementation

uses
  EuoInterpreter, EuoLint, scriptfile, ReforgedVersion;

////////////////////////////////////////////////////////////////////////////////
procedure CheckHelp(Output : TStrings);
begin
  Output.Add('EUOCli check <script.euo> [more scripts] [--json] [--strict] [--curpath <folder>]');
  Output.Add('');
  Output.Add('Reports what EasyUO would skip or misread in a script, without running it: a word that');
  Output.Add('is not a command, a #variable that does not exist, words with no space between them,');
  Output.Add('a block or a loop that is not closed, a gosub or goto that leads nowhere, a script that');
  Output.Add('restarts because it has no halt. EasyUO itself gives no error for any of these.');
  Output.Add('');
  Output.Add('  <script>            a script file; - reads the script from standard input');
  Output.Add('  --json              print the findings as JSON');
  Output.Add('  --strict            exit with code 1 when there is a warning');
  Output.Add('  --curpath <folder>  the folder "call" starts from: the folder of EasyUOReforged.exe.');
  Output.Add('                      Default: the folder of EUOCli.exe');
  Output.Add('');
  Output.Add('Exit code: 0 checked; 1 a warning was found and --strict was given; 2 the command line');
  Output.Add('is wrong or a file cannot be read.');
end;

////////////////////////////////////////////////////////////////////////////////
function Plural(N : Integer; const One : String) : String;
begin
  Result:=IntToStr(N)+' '+One;
  if N<>1 then Result:=Result+'s';
end;

////////////////////////////////////////////////////////////////////////////////
procedure PrintPlain(const FileName : String; Res : TEuoLintResult; Output : TStrings);
var
  i     : Integer;
  F     : TEuoFinding;
  Where : String;
begin
  for i:=0 to Res.Count-1 do
  begin
    F:=Res[i];
    Where:=FileName;
    if F.Line>0 then
    begin
      Where:=Where+':'+IntToStr(F.Line);
      if F.Column>0 then Where:=Where+':'+IntToStr(F.Column);
    end;
    Output.Add(Where+': '+EuoSeverityName[F.Severity]+' ['+F.Rule+'] '+F.Message);
    if F.Hint<>'' then Output.Add('    '+F.Hint);
  end;
  if Res.Count=0 then Output.Add(FileName+': nothing found')
  else Output.Add(FileName+': '+Plural(Res.Warnings,'warning')+', '+Plural(Res.Notes,'note'));
end;

////////////////////////////////////////////////////////////////////////////////
function ToJson(const FileName : String; Res : TEuoLintResult) : TJSONObject;
var
  i        : Integer;
  F        : TEuoFinding;
  Findings : TJSONArray;
  Item     : TJSONObject;
  Summary  : TJSONObject;
  Clients  : TJSONArray;
begin
  Findings:=TJSONArray.Create;
  for i:=0 to Res.Count-1 do
  begin
    F:=Res[i];
    Item:=TJSONObject.Create;
    Item.Add('rule',F.Rule);
    Item.Add('severity',EuoSeverityName[F.Severity]);
    Item.Add('line',F.Line);
    Item.Add('column',F.Column);
    Item.Add('word',F.Word);
    Item.Add('message',F.Message);
    Item.Add('hint',F.Hint);
    Findings.Add(Item);
  end;
  Clients:=TJSONArray.Create;
  for i:=0 to Res.ClientCommands.Count-1 do Clients.Add(Res.ClientCommands[i]);
  Summary:=TJSONObject.Create;
  Summary.Add('warnings',Res.Warnings);
  Summary.Add('notes',Res.Notes);
  Summary.Add('menuLogic',Res.MenuLogic);
  Summary.Add('clientCommands',Clients);

  Result:=TJSONObject.Create;
  Result.Add('file',FileName);
  Result.Add('lines',Res.LineCount);
  Result.Add('findings',Findings);
  Result.Add('summary',Summary);
end;

////////////////////////////////////////////////////////////////////////////////
function CheckScriptJson(const Text, Shown, CurPath : String) : TJSONObject;
var
  Interp     : TEuoInterpreter;
  Cmds, Vars : TStringList;
  Lines      : TStringList;
  Linter     : TEuoLinter;
  Res        : TEuoLintResult;
begin
  Cmds:=TStringList.Create;
  Vars:=TStringList.Create;
  Lines:=TStringList.Create;
  Res:=TEuoLintResult.Create;
  Interp:=TEuoInterpreter.Create(0);
  Linter:=nil;
  try
    Interp.GetCommandNames(Cmds);
    Interp.GetVariableNames(Vars);
    Linter:=TEuoLinter.Create(Cmds,Vars);
    Linter.CurPath:=CurPath;
    Lines.Text:=Text;
    Linter.Check(Lines,Res);
    Result:=ToJson(Shown,Res);
  finally
    Linter.Free;
    Interp.Free;
    Res.Free;
    Lines.Free;
    Vars.Free;
    Cmds.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunCheck(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
var
  Files       : TStringList;
  Json        : Boolean;
  Strict      : Boolean;
  CurPath     : String;
  i           : Integer;
  A           : String;
  Interp      : TEuoInterpreter;
  Cmds, Vars  : TStringList;
  Linter      : TEuoLinter;
  Res         : TEuoLintResult;
  Lines       : TStringList;
  Root        : TJSONObject;
  FileArr     : TJSONArray;
  Total       : Integer;
  TotalNotes  : Integer;
  Shown       : String;

  function Fail(const Msg : String) : Integer;
  begin
    Output.Clear;
    Output.Add('EUOCli check: '+Msg);
    Output.Add('Try: EUOCli help check');
    Result:=CLI_USAGE;
  end;

begin
  Files:=TStringList.Create;
  Lines:=TStringList.Create;
  Cmds:=TStringList.Create;
  Vars:=TStringList.Create;
  Root:=nil;
  Interp:=nil;
  Linter:=nil;
  try
    Json:=False;
    Strict:=False;
    CurPath:=ExeDir;
    i:=0;
    while i<Args.Count do
    begin
      A:=Args[i];
      if A='--json' then Json:=True
      else if A='--strict' then Strict:=True
      else if A='--curpath' then
      begin
        Inc(i);
        if i>=Args.Count then Exit(Fail('--curpath needs a folder'));
        CurPath:=Args[i];
      end
      else if Copy(A,1,10)='--curpath=' then CurPath:=Copy(A,11,MaxInt)
      else if (A<>'-') and (Copy(A,1,1)='-') then Exit(Fail('unknown option '+A))
      else Files.Add(A);
      Inc(i);
    end;
    if Files.Count=0 then Exit(Fail('no script given'));
    for i:=0 to Files.Count-1 do
      if (Files[i]<>'-') and not FileExists(Files[i]) then
        Exit(Fail('file not found: '+Files[i]));

    // The names come from the interpreter itself. It is created and never run: no script is
    // loaded and no client is looked for.
    Interp:=TEuoInterpreter.Create(0);
    Interp.GetCommandNames(Cmds);
    Interp.GetVariableNames(Vars);
    Linter:=TEuoLinter.Create(Cmds,Vars);
    Linter.CurPath:=CurPath;

    Total:=0;
    TotalNotes:=0;
    FileArr:=nil;
    if Json then
    begin
      Root:=TJSONObject.Create;
      Root.Add('version',REFORGED_VERSION);
      FileArr:=TJSONArray.Create;
      Root.Add('files',FileArr);
    end;

    for i:=0 to Files.Count-1 do
    begin
      if Files[i]='-' then
      begin
        Shown:='<stdin>';
        Lines.Text:=StdInText;
      end
      else begin
        Shown:=Files[i];
        try
          Lines.Text:=LoadScriptFileAsUTF8(Files[i]);
        except
          on E : Exception do Exit(Fail('cannot read '+Files[i]+': '+E.Message));
        end;
      end;

      Res:=TEuoLintResult.Create;
      try
        Linter.Check(Lines,Res);
        Inc(Total,Res.Warnings);
        Inc(TotalNotes,Res.Notes);
        if Json then FileArr.Add(ToJson(Shown,Res))
        else PrintPlain(Shown,Res,Output);
      finally
        Res.Free;
      end;
    end;

    if Json then
    begin
      Root.Add('warnings',Total);
      Root.Add('notes',TotalNotes);
      Output.Text:=Root.FormatJSON;
    end;

    if Strict and (Total>0) then Result:=CLI_WARNINGS else Result:=CLI_OK;
  finally
    Root.Free;
    Linter.Free;
    if Interp<>nil then Interp.Free;   // TEuoInterpreter.Free is its own method, not nil-safe
    Vars.Free;
    Cmds.Free;
    Lines.Free;
    Files.Free;
  end;
end;

end.
