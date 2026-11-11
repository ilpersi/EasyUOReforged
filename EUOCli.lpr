program EUOCli;

{
  Port addition: EUOCli, EasyUO Reforged from the command line, for programs and AI coding
  agents (docs\agent-support.md). A console program: it reads its arguments and standard
  input, hands them to tools\EUOCli\climain.pas and prints what comes back, as UTF-8 bytes
  whatever the console's code page is, so that a program reading its output gets the same
  text on every machine.

  `Interfaces` is in the uses clause because the interpreter this program creates links the
  MENU command's LCL controls (as tests\RunTests.lpr does); no window is ever made here.
  The executable carries EasyUO Reforged's own icon (easyuo\appicon.res).

  It ends with TerminateProcess, not by returning. Linking the engine brings in
  uo\uoselector.pas, whose initialization starts the thread that looks for UO clients (so
  this program looks for them when it starts, as the editor does, whatever the command) and
  whose finalization stops that thread with TerminateThread. A program that is done within
  milliseconds reaches that finalization while the thread is still inside its first scan,
  holding locks the rest of the shutdown then waits on for ever: "EUOCli version" hung that
  way about every other run. The editor and the test runner live long enough to never see
  it. Everything this program owns is released and its output written by then, so there is
  nothing left for an orderly exit to do.
}

{$mode delphi}{$H+}
{$apptype console}

{$R easyuo\appicon.res}

uses
  Interfaces,
  Windows, SysUtils, Classes,
  climain in 'tools\EUOCli\climain.pas',
  clirun in 'tools\EUOCli\clirun.pas',
  climcp in 'tools\EUOCli\climcp.pas';

////////////////////////////////////////////////////////////////////////////////
// Standard input to its end, when it is a file or a pipe. A console nobody is typing
// into would wait for ever, so it reads as empty: "check -" is for a piped script.
function ReadStdIn : String;
var
  H    : THandle;
  Buf  : array[0..16383] of Byte;
  Got  : DWORD;
  Part : String;
begin
  Result:='';
  H:=GetStdHandle(STD_INPUT_HANDLE);
  if (H=0) or (H=INVALID_HANDLE_VALUE) then Exit;
  if GetFileType(H)=FILE_TYPE_CHAR then Exit;
  while ReadFile(H,Buf,SizeOf(Buf),Got,nil) and (Got>0) do
  begin
    SetString(Part,PAnsiChar(@Buf[0]),Got);
    Result:=Result+Part;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure WriteStdOut(const S : String);
var
  H    : THandle;
  Done : DWORD;
begin
  H:=GetStdHandle(STD_OUTPUT_HANDLE);
  if (H=0) or (H=INVALID_HANDLE_VALUE) or (S='') then Exit;
  WriteFile(H,S[1],Length(S),Done,nil);
end;

////////////////////////////////////////////////////////////////////////////////
// clirun.CliOnLine: "run" prints each line the moment it has it, so whoever reads the
// output sees a long run as it goes.
procedure WriteLineNow(const Line : String);
begin
  WriteStdOut(Line+LineEnding);
end;

////////////////////////////////////////////////////////////////////////////////
// climcp.McpOut: one message of the MCP server. The protocol wants one line feed after
// each, and nothing else on standard output while it runs.
procedure WriteMcpLine(const Line : String);
begin
  WriteStdOut(Line+#10);
end;

////////////////////////////////////////////////////////////////////////////////
// Ctrl+C and Ctrl+Break ask "run" and "mcp" to stop their script and end in order. Windows calls this
// on a thread of its own; it only sets a flag the run loop reads.
function CtrlHandler(CtrlType : DWORD) : BOOL; stdcall;
begin
  Result:=(CtrlType=CTRL_C_EVENT) or (CtrlType=CTRL_BREAK_EVENT);
  if Result then CliInterrupted:=True;
end;

var
  Args, Output : TStringList;
  StdInText    : String;
  i, Code      : Integer;
  NeedsStdIn   : Boolean;

begin
  Args:=TStringList.Create;
  Output:=TStringList.Create;
  try
    NeedsStdIn:=False;
    for i:=1 to ParamCount do
    begin
      Args.Add(ParamStr(i));
      if ParamStr(i)='-' then NeedsStdIn:=True;
    end;
    StdInText:='';
    if NeedsStdIn then StdInText:=ReadStdIn;

    // A console set to another code page would show UTF-8 as two wrong characters.
    SetConsoleOutputCP(CP_UTF8);
    CliOnLine:=WriteLineNow;
    McpOut:=WriteMcpLine;
    SetConsoleCtrlHandler(@CtrlHandler,True);
    Code:=RunCli(Args,StdInText,ExtractFilePath(ParamStr(0)),Output);
    WriteStdOut(Output.Text);
  finally
    Output.Free;
    Args.Free;
  end;
  // See the header comment: no unit finalization.
  TerminateProcess(GetCurrentProcess,Code);
end.
