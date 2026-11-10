unit climain;

{
  Port addition (docs\agent-support.md): EUOCli, EasyUO Reforged from the command line, for
  programs and AI coding agents that cannot click in the editor. This unit takes the command
  line apart and hands it to the command's own unit; EUOCli.lpr only passes it the arguments
  and prints what comes back. Commands so far: check (clicheck.pas), version, help.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

// Runs "EUOCli <Args>": what the program prints goes to Output, the result is its exit code.
// StdInText is standard input, read only when a command asks for it ("check -"); ExeDir is
// the program's folder.
function RunCli(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;

implementation

uses
  clicheck, ReforgedVersion;

////////////////////////////////////////////////////////////////////////////////
procedure Help(Output : TStrings);
begin
  Output.Add('EUOCli '+REFORGED_VERSION+': EasyUO Reforged from the command line');
  Output.Add('');
  Output.Add('  EUOCli check <script.euo> [--json] [--strict]   report what EasyUO would skip or misread');
  Output.Add('  EUOCli version                                  print the version');
  Output.Add('  EUOCli help [command]                           this text, or a command''s');
  Output.Add('');
  Output.Add('Documentation: https://ilpersi.github.io/EasyUOReforged/guide/euocli/');
end;

////////////////////////////////////////////////////////////////////////////////
function RunCli(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
var
  Cmd  : String;
  Rest : TStringList;
  i    : Integer;
begin
  Result:=CLI_OK;
  if Args.Count=0 then
  begin
    Help(Output);
    Exit(CLI_USAGE);
  end;

  Cmd:=LowerCase(Args[0]);
  if (Cmd='help') or (Cmd='--help') or (Cmd='-h') or (Cmd='/?') then
  begin
    if (Args.Count>1) and (LowerCase(Args[1])='check') then CheckHelp(Output)
    else Help(Output);
  end
  else if (Cmd='version') or (Cmd='--version') then
    Output.Add(REFORGED_VERSION)
  else if Cmd='check' then
  begin
    Rest:=TStringList.Create;
    try
      for i:=1 to Args.Count-1 do Rest.Add(Args[i]);
      Result:=RunCheck(Rest,StdInText,ExeDir,Output);
    finally
      Rest.Free;
    end;
  end
  else begin
    Output.Add('EUOCli: unknown command "'+Args[0]+'"');
    Output.Add('Try: EUOCli help');
    Result:=CLI_USAGE;
  end;
end;

end.
