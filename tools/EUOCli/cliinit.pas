unit cliinit;

{
  Port addition (docs\agent-support.md, phase 4): "EUOCli init <folder>" sets a folder of
  scripts up for AI coding agents, in one step instead of the copying the pack's README
  describes. It writes three things, and nothing else in the folder is touched:

    .claude\skills\euo-script\   the agent pack that came with this program (Claude Code
                                 loads it as a skill), plus euocli-path.txt, which tells the
                                 skill where EUOCli.exe is
    AGENTS.md                    the pack's instructions for every other agent, between two
                                 marker lines. An AGENTS.md that is already there keeps its
                                 own text: the block is added at its end, or replaced when
                                 it is there from an earlier init
    .mcp.json                    the entry that starts "EUOCli mcp", merged into the file
                                 when there is one. A file that cannot be read as JSON is
                                 left alone, and the entry is printed instead

  Running it again after an update of EasyUO Reforged replaces the pack and the block.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  InitBlockStart = '<!-- EasyUO Reforged: start. Written by "EUOCli init"; it replaces what is between these two lines. -->';
  InitBlockEnd   = '<!-- EasyUO Reforged: end -->';
  InitSkillDir   = '.claude\skills\euo-script';
  InitMcpName    = 'easyuo';

function RunInit(Args : TStrings; const ExeDir : String; Output : TStrings) : Integer;
procedure InitHelp(Output : TStrings);

implementation

uses
  fpjson, jsonparser, clicheck, clidocs;

////////////////////////////////////////////////////////////////////////////////
procedure InitHelp(Output : TStrings);
begin
  Output.Add('EUOCli init [folder] [--no-mcp] [--pack <folder>]');
  Output.Add('');
  Output.Add('Sets a folder of scripts up for AI coding agents (Claude Code, Codex, Cursor, ...):');
  Output.Add('');
  Output.Add('  .claude\skills\euo-script\   the agent pack: language rules, every command and #variable');
  Output.Add('  AGENTS.md                    the instructions other agents read first');
  Output.Add('  .mcp.json                    the entry that gives the agent EUOCli''s tools (EUOCli mcp)');
  Output.Add('');
  Output.Add('  [folder]          the folder to set up. Default: the current one');
  Output.Add('  --no-mcp          do not write .mcp.json');
  Output.Add('  --pack <folder>   the agent pack to copy. Default: agent\euo-script next to EUOCli.exe');
  Output.Add('');
  Output.Add('An AGENTS.md or .mcp.json that is already there keeps what it holds. Run it again after');
  Output.Add('updating EasyUO Reforged: it replaces the pack with the new one.');
  Output.Add('');
  Output.Add('Exit code: 0 done; 2 wrong command line, no such folder, or no agent pack to copy.');
end;

////////////////////////////////////////////////////////////////////////////////
function ReadText(const FileName : String) : String;
var
  S : TMemoryStream;
begin
  Result:='';
  S:=TMemoryStream.Create;
  try
    S.LoadFromFile(FileName);
    SetLength(Result,S.Size);
    if S.Size>0 then Move(S.Memory^,Result[1],S.Size);
  finally
    S.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure WriteText(const FileName, Text : String);
var
  S : TMemoryStream;
begin
  S:=TMemoryStream.Create;
  try
    if Text<>'' then S.Write(Text[1],Length(Text));
    S.SaveToFile(FileName);
  finally
    S.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Copies the folder From (with its trailing delimiter) into Dest, files and sub-folders.
// Returns the number of files.
function CopyTree(const From, Dest : String) : Integer;
var
  SR : TSearchRec;
  S  : TMemoryStream;
begin
  Result:=0;
  ForceDirectories(Dest);
  if FindFirst(From+'*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then
        Inc(Result,CopyTree(From+SR.Name+PathDelim,Dest+SR.Name+PathDelim))
      else begin
        S:=TMemoryStream.Create;
        try
          S.LoadFromFile(From+SR.Name);
          S.SaveToFile(Dest+SR.Name);
        finally
          S.Free;
        end;
        Inc(Result);
      end;
    until FindNext(SR)<>0;
  finally
    FindClose(SR);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The block for AGENTS.md: the pack's own AGENTS.md, with its paths pointing at where
// init put the pack, and where the program is.
function AgentsBlock(const PackAgents, ExeDir : String; WithMcp : Boolean) : String;
var
  Body : String;
begin
  Body:=TrimRight(StringReplace(PackAgents,#13#10,#10,[rfReplaceAll]));
  Body:=StringReplace(Body,'`euo-script/','`.claude/skills/euo-script/',[rfReplaceAll]);
  Result:=InitBlockStart+#10+Body+#10#10+
    '`EUOCli.exe` is here: `'+ExeDir+'EUOCli.exe`.';
  if WithMcp then
    Result:=Result+' If the `'+InitMcpName+'` MCP server is connected, its tools do the same without a '+
      'shell: `euo_check`, `euo_run`, `euo_status`, `euo_vars`, `euo_docs`. `euo_run_live` runs on the '+
      'game: only after the user''s yes for that script.';
  Result:=Result+#10+InitBlockEnd+#10;
end;

////////////////////////////////////////////////////////////////////////////////
// Old with the block put in: in place of the block an earlier init wrote, or at the end.
function PutBlock(const Old, Block : String) : String;
var
  A, B : Integer;
  Text : String;
begin
  Text:=StringReplace(Old,#13#10,#10,[rfReplaceAll]);
  A:=Pos(InitBlockStart,Text);
  B:=Pos(InitBlockEnd,Text);
  if (A>0) and (B>A) then
  begin
    B:=B+Length(InitBlockEnd);
    if (B<=Length(Text)) and (Text[B]=#10) then Inc(B);
    Result:=Copy(Text,1,A-1)+Block+Copy(Text,B,MaxInt);
  end
  else if Trim(Text)='' then Result:=Block
  else Result:=TrimRight(Text)+#10#10+Block;
end;

////////////////////////////////////////////////////////////////////////////////
function RunInit(Args : TStrings; const ExeDir : String; Output : TStrings) : Integer;
var
  Folder, Pack, PackDir, A : String;
  WithMcp                  : Boolean;
  FolderGiven              : Boolean;
  i, N                     : Integer;
  Dest, FN, Old, Exe       : String;
  Data                     : TJSONData;
  Root, Servers, Entry     : TJSONObject;
  Arr                      : TJSONArray;
  P                        : TJSONData;

  function Fail(const Msg : String) : Integer;
  begin
    Output.Add('EUOCli init: '+Msg);
    Output.Add('Try: EUOCli help init');
    Result:=CLI_USAGE;
  end;

begin
  Result:=CLI_OK;
  Folder:='.';
  FolderGiven:=False;
  Pack:='';
  WithMcp:=True;
  i:=0;
  while i<Args.Count do
  begin
    A:=Args[i];
    if A='--no-mcp' then WithMcp:=False
    else if A='--pack' then
    begin
      Inc(i);
      if i>=Args.Count then Exit(Fail('--pack needs a folder'));
      Pack:=Args[i];
    end
    else if Copy(A,1,2)='--' then Exit(Fail('unknown option '+A))
    else if FolderGiven then Exit(Fail('one folder at a time'))
    else begin
      Folder:=A;
      FolderGiven:=True;
    end;
    Inc(i);
  end;
  if not DirectoryExists(Folder) then Exit(Fail('there is no folder '+Folder));
  Folder:=IncludeTrailingPathDelimiter(ExpandFileName(Folder));

  PackDir:=FindPack(ExeDir,Pack);
  if (PackDir='') or not FileExists(PackDir+'SKILL.md') or not FileExists(PackDir+'language.md') then
  begin
    if Pack<>'' then Exit(Fail('there is no agent pack in '+Pack))
    else Exit(Fail('the agent pack was not found next to EUOCli.exe (the folder agent\euo-script of an '+
      'EasyUO Reforged release). Give its place with --pack'));
  end;
  Exe:=IncludeTrailingPathDelimiter(ExeDir)+'EUOCli.exe';

  // ---- the pack, as a Claude Code skill -----------------------------------------------------
  Dest:=Folder+InitSkillDir+PathDelim;
  N:=CopyTree(PackDir,Dest);
  WriteText(Dest+'euocli-path.txt',Exe+#10);
  Output.Add('wrote '+InitSkillDir+'\  ('+IntToStr(N)+' files: the agent pack)');

  // ---- AGENTS.md ----------------------------------------------------------------------------
  // The pack's AGENTS.md is one folder up from the skill, in a release and on the site.
  FN:=ExtractFilePath(ExcludeTrailingPathDelimiter(PackDir))+'AGENTS.md';
  if FileExists(FN) then
  begin
    Old:='';
    if FileExists(Folder+'AGENTS.md') then Old:=ReadText(Folder+'AGENTS.md');
    WriteText(Folder+'AGENTS.md',PutBlock(Old,AgentsBlock(ReadText(FN),IncludeTrailingPathDelimiter(ExeDir),WithMcp)));
    if Old='' then Output.Add('wrote AGENTS.md')
    else if Pos(InitBlockStart,Old)>0 then Output.Add('updated the EasyUO Reforged part of AGENTS.md')
    else Output.Add('added the EasyUO Reforged part to the end of AGENTS.md');
  end
  else Output.Add('AGENTS.md was not written: the pack in '+PackDir+' came without one');

  // ---- .mcp.json ----------------------------------------------------------------------------
  if WithMcp then
  begin
    FN:=Folder+'.mcp.json';
    Data:=nil;
    Root:=nil;
    try
      if FileExists(FN) then
      begin
        try
          Data:=GetJSON(ReadText(FN));
        except
          Data:=nil;
        end;
        if Data is TJSONObject then Root:=TJSONObject(Data);
        if Root<>nil then
        begin
          P:=Root.Find('mcpServers');
          if (P<>nil) and not (P is TJSONObject) then Root:=nil;
        end;
      end
      else begin
        Root:=TJSONObject.Create;
        Data:=Root;
      end;

      Entry:=TJSONObject.Create;
      Entry.Add('command',Exe);
      Arr:=TJSONArray.Create;
      Arr.Add('mcp');
      Entry.Add('args',Arr);

      if Root=nil then
      begin
        Output.Add('.mcp.json was left alone: it is there, and it is not the JSON this program expects.');
        Output.Add('Add this to its "mcpServers" by hand:');
        Output.Add('  "'+InitMcpName+'": '+Entry.FormatJSON([foSingleLineArray,foSingleLineObject]));
        Entry.Free;
      end
      else begin
        Servers:=nil;
        P:=Root.Find('mcpServers');
        if P is TJSONObject then Servers:=TJSONObject(P)
        else begin
          Servers:=TJSONObject.Create;
          Root.Add('mcpServers',Servers);
        end;
        Old:='';
        if Servers.Find(InitMcpName)<>nil then
        begin
          Old:='x';
          Servers.Delete(InitMcpName);
        end;
        Servers.Add(InitMcpName,Entry);
        WriteText(FN,Root.FormatJSON+#10);
        if Old<>'' then Output.Add('updated the "'+InitMcpName+'" entry of .mcp.json')
        else Output.Add('wrote the "'+InitMcpName+'" entry of .mcp.json  (EUOCli mcp)');
      end;
    finally
      Data.Free;
    end;
  end;

  Output.Add('');
  Output.Add('Start your agent in '+ExcludeTrailingPathDelimiter(Folder)+' and ask for a script in plain words.');
  if WithMcp then
    Output.Add('It will ask before it uses the "'+InitMcpName+'" tools. The tool euo_run_live runs a script on your '+
      'character: allow it one run at a time.');
end;

end.
