unit climain;

{
  Port addition (docs\agent-support.md): EUOCli, EasyUO Reforged from the command line, for
  programs and AI coding agents that cannot click in the editor. This unit takes the command
  line apart and hands it to the command's own unit; EUOCli.lpr only passes it the arguments
  and prints what comes back. Commands: check (clicheck.pas), run, vars and clients
  (clirun.pas), docs (clidocs.pas), mcp (climcp.pas), init (cliinit.pas), version, help.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

// Runs "EUOCli <Args>": what the program prints goes to Output, the result is its exit code.
// StdInText is standard input, read only when a command asks for it ("check -", "run -");
// ExeDir is the program's folder. A command that prints while it works ("run") sends each
// line to clirun.CliOnLine instead when that is set.
function RunCli(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;

implementation

uses
  clicheck, clirun, clidocs, climcp, cliinit, ReforgedVersion;

////////////////////////////////////////////////////////////////////////////////
procedure Help(Output : TStrings);
begin
  Output.Add('EUOCli '+REFORGED_VERSION+': EasyUO Reforged from the command line');
  Output.Add('');
  Output.Add('  EUOCli check <script.euo> [--json] [--strict]   report what EasyUO would skip or misread');
  Output.Add('  EUOCli run <script.euo> [--client <n>] [--json] run a script and print what happens');
  Output.Add('  EUOCli vars <#variable> ... [--client <n>]      read variables from a client');
  Output.Add('  EUOCli clients                                  list the UO clients found');
  Output.Add('  EUOCli docs <name> | --search <words>           print a page of the documentation');
  Output.Add('  EUOCli mcp                                      serve all of this to an AI agent as tools');
  Output.Add('  EUOCli init [folder]                            set a script folder up for AI agents');
  Output.Add('  EUOCli version                                  print the version');
  Output.Add('  EUOCli help [command]                           this text, or a command''s');
  Output.Add('');
  Output.Add('Documentation: https://ilpersi.github.io/EasyUOReforged/guide/euocli/');
end;

////////////////////////////////////////////////////////////////////////////////
function RunCli(Args : TStrings; const StdInText, ExeDir : String; Output : TStrings) : Integer;
var
  Cmd, Topic : String;
  Rest       : TStringList;
  i          : Integer;
begin
  Result:=CLI_OK;
  if Args.Count=0 then
  begin
    Help(Output);
    Exit(CLI_USAGE);
  end;

  Cmd:=LowerCase(Args[0]);
  Rest:=TStringList.Create;
  try
    for i:=1 to Args.Count-1 do Rest.Add(Args[i]);

    if (Cmd='help') or (Cmd='--help') or (Cmd='-h') or (Cmd='/?') then
    begin
      Topic:='';
      if Rest.Count>0 then Topic:=LowerCase(Rest[0]);
      if Topic='check' then CheckHelp(Output)
      else if Topic='run' then RunHelp(Output)
      else if Topic='vars' then VarsHelp(Output)
      else if Topic='clients' then ClientsHelp(Output)
      else if Topic='docs' then DocsHelp(Output)
      else if Topic='mcp' then McpHelp(Output)
      else if Topic='init' then InitHelp(Output)
      else Help(Output);
    end
    else if (Cmd='version') or (Cmd='--version') then
      Output.Add(REFORGED_VERSION)
    else if Cmd='check' then Result:=RunCheck(Rest,StdInText,ExeDir,Output)
    else if Cmd='run' then Result:=RunRun(Rest,StdInText,ExeDir,Output)
    else if Cmd='vars' then Result:=RunVars(Rest,Output)
    else if Cmd='clients' then Result:=RunClients(Rest,Output)
    else if Cmd='docs' then Result:=RunDocs(Rest,ExeDir,Output)
    else if Cmd='mcp' then Result:=RunMcp(Rest,ExeDir,Output)
    else if Cmd='init' then Result:=RunInit(Rest,ExeDir,Output)
    else begin
      Output.Add('EUOCli: unknown command "'+Args[0]+'"');
      Output.Add('Try: EUOCli help');
      Result:=CLI_USAGE;
    end;
  finally
    Rest.Free;
  end;
end;

end.
