unit EuoCliInitTests;

{
  Tests for EUOCli's "init" (tools\EUOCli\cliinit.pas) and "docs" (clidocs.pas), called as
  the program calls them. Both work from an agent pack; the tests make a small one in a
  temporary folder and point the commands at it with --pack, so nothing depends on a built
  site or a release.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, climain, clicheck, cliinit;

type
  TEuoCliInitTests = class(TTestCase)
  private
    Dir    : String;    // stands for the program's folder
    Pack   : String;    // Dir\agent\euo-script
    Work   : String;    // the folder that is set up
    Output : TStringList;
    function  Run(const Args : String) : Integer;
    function  Load(const FileName : String) : String;
    procedure Save(const FileName, Text : String);
    function  Count(const Sub, S : String) : Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitWritesTheThreeThings;
    procedure TestInitKeepsAnAgentsFileThatIsThere;
    procedure TestInitTwiceLeavesOneBlock;
    procedure TestInitMergesIntoMcpJson;
    procedure TestInitLeavesABrokenMcpJsonAlone;
    procedure TestInitNoMcp;
    procedure TestInitUsageErrors;
    procedure TestDocsCommand;
    procedure TestHelpOfTheNewCommands;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure RemoveTree(const Path : String);
var
  SR : TSearchRec;
begin
  if FindFirst(Path+PathDelim+'*',faAnyFile,SR)=0 then
  begin
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then RemoveTree(Path+PathDelim+SR.Name)
      else DeleteFile(Path+PathDelim+SR.Name);
    until FindNext(SR)<>0;
    FindClose(SR);
  end;
  RemoveDir(Path);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euocliinit-'+IntToStr(GetProcessID);
  Pack:=Dir+PathDelim+'agent'+PathDelim+'euo-script';
  Work:=Dir+PathDelim+'scripts';
  ForceDirectories(Work);
  Output:=TStringList.Create;

  // A small pack, laid out as a release has it: AGENTS.md next to the skill folder.
  Save(Dir+PathDelim+'agent'+PathDelim+'AGENTS.md',
    '# EasyUO scripts in this folder'+#10#10+'Read `euo-script/SKILL.md` and (`euo-script/language.md`).'+#10);
  Save(Pack+PathDelim+'SKILL.md','the skill');
  Save(Pack+PathDelim+'language.md','the rules');
  Save(Pack+PathDelim+'reference.json',
    '{"commands":[{"name":"finditem","title":"FindItem","description":"Finds objects.","needsClient":true,'+
    '"origin":"original","aliases":[],"file":"reference/commands/finditem.md"}],"variables":[],"pages":[]}');
  Save(Pack+PathDelim+'reference'+PathDelim+'commands'+PathDelim+'finditem.md','# FindItem');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TearDown;
begin
  Output.Free;
  RemoveTree(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliInitTests.Run(const Args : String) : Integer;
var
  SL : TStringList;
begin
  SL:=TStringList.Create;
  try
    SL.Delimiter:='|';
    SL.StrictDelimiter:=True;
    SL.DelimitedText:=Args;
    Output.Clear;
    Result:=RunCli(SL,'',Dir+PathDelim,Output);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliInitTests.Load(const FileName : String) : String;
var
  S : TStringStream;
begin
  S:=TStringStream.Create('');
  try
    S.LoadFromFile(FileName);
    Result:=S.DataString;
  finally
    S.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.Save(const FileName, Text : String);
var
  S : TStringStream;
begin
  ForceDirectories(ExtractFilePath(FileName));
  S:=TStringStream.Create(Text);
  try
    S.SaveToFile(FileName);
  finally
    S.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliInitTests.Count(const Sub, S : String) : Integer;
var
  P : Integer;
begin
  Result:=0;
  P:=Pos(Sub,S);
  while P>0 do
  begin
    Inc(Result);
    P:=Pos(Sub,S,P+Length(Sub));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitWritesTheThreeThings;
var
  Skill, Agents : String;
  Root          : TJSONData;
  Entry         : TJSONObject;
begin
  AssertEquals(Output.Text,CLI_OK,Run('init|'+Work));
  Skill:=Work+PathDelim+'.claude'+PathDelim+'skills'+PathDelim+'euo-script'+PathDelim;
  AssertEquals('the pack, as a skill','the skill',Load(Skill+'SKILL.md'));
  AssertEquals('with its sub-folders','# FindItem',Load(Skill+'reference'+PathDelim+'commands'+PathDelim+'finditem.md'));
  AssertEquals('and where the program is',Dir+PathDelim+'EUOCli.exe',Trim(Load(Skill+'euocli-path.txt')));

  Agents:=Load(Work+PathDelim+'AGENTS.md');
  AssertTrue('the pack''s instructions',Pos('# EasyUO scripts in this folder',Agents)>0);
  AssertTrue('pointing at where the pack now is',Pos('`.claude/skills/euo-script/SKILL.md`',Agents)>0);
  AssertEquals('every path of them',0,Pos('`euo-script/',Agents));
  AssertTrue(Pos('(`.claude/skills/euo-script/language.md`)',Agents)>0);
  AssertTrue('between its two marker lines',(Pos(InitBlockStart,Agents)=1) and (Pos(InitBlockEnd,Agents)>0));
  AssertTrue('with the program''s place',Pos(Dir+PathDelim+'EUOCli.exe',Agents)>0);
  AssertTrue('and the rule for the tool that runs on the game',Pos('euo_run_live',Agents)>0);

  Root:=GetJSON(Load(Work+PathDelim+'.mcp.json'));
  try
    Entry:=TJSONObject(Root).Objects['mcpServers'].Objects[InitMcpName];
    AssertEquals(Dir+PathDelim+'EUOCli.exe',Entry.Get('command',''));
    AssertEquals(1,Entry.Arrays['args'].Count);
    AssertEquals('mcp',Entry.Arrays['args'].Strings[0]);
  finally
    Root.Free;
  end;
  AssertTrue('it says what it did',Pos('wrote AGENTS.md',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitKeepsAnAgentsFileThatIsThere;
var
  Agents : String;
begin
  Save(Work+PathDelim+'AGENTS.md','# My notes'+#13#10#13#10+'Keep this.'+#13#10);
  AssertEquals(CLI_OK,Run('init|'+Work));
  Agents:=Load(Work+PathDelim+'AGENTS.md');
  AssertTrue('the user''s own text comes first',Pos('# My notes',Agents)=1);
  AssertTrue(Pos('Keep this.',Agents)>0);
  AssertTrue('and the block after it',Pos(InitBlockStart,Agents)>Pos('Keep this.',Agents));
  AssertTrue(Pos('added the EasyUO Reforged part to the end of AGENTS.md',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
// What an update of EasyUO Reforged does: init again. The block is replaced, not added twice,
// and what the user wrote around it stays.
procedure TEuoCliInitTests.TestInitTwiceLeavesOneBlock;
var
  Agents : String;
begin
  Save(Work+PathDelim+'AGENTS.md','# My notes'+#10);
  AssertEquals(CLI_OK,Run('init|'+Work));
  Agents:=Load(Work+PathDelim+'AGENTS.md')+'After the block.'+#10;
  Save(Work+PathDelim+'AGENTS.md',Agents);
  Save(Dir+PathDelim+'agent'+PathDelim+'AGENTS.md','# The new instructions'+#10);

  AssertEquals(CLI_OK,Run('init|'+Work));
  Agents:=Load(Work+PathDelim+'AGENTS.md');
  AssertEquals('one block',1,Count(InitBlockStart,Agents));
  AssertEquals(1,Count(InitBlockEnd,Agents));
  AssertTrue('with the new text',Pos('# The new instructions',Agents)>0);
  AssertEquals('and not the old',0,Pos('# EasyUO scripts in this folder',Agents));
  AssertTrue('the text before it stays',Pos('# My notes',Agents)=1);
  AssertTrue('and the text after it',Pos('After the block.',Agents)>Pos(InitBlockEnd,Agents));
  AssertTrue(Pos('updated the EasyUO Reforged part of AGENTS.md',Output.Text)>0);
  AssertTrue(Pos('updated the "'+InitMcpName+'" entry of .mcp.json',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitMergesIntoMcpJson;
var
  Root    : TJSONData;
  Servers : TJSONObject;
begin
  Save(Work+PathDelim+'.mcp.json','{"mcpServers":{"other":{"command":"x","args":["y"]}},"mine":1}');
  AssertEquals(CLI_OK,Run('init|'+Work));
  Root:=GetJSON(Load(Work+PathDelim+'.mcp.json'));
  try
    Servers:=TJSONObject(Root).Objects['mcpServers'];
    AssertEquals('the server that was there stays','x',Servers.Objects['other'].Get('command',''));
    AssertNotNull(Servers.Find(InitMcpName));
    AssertEquals('so does everything else in the file',1,TJSONObject(Root).Get('mine',0));
  finally
    Root.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitLeavesABrokenMcpJsonAlone;
const
  Broken = '{"mcpServers": {  this is not JSON';
begin
  Save(Work+PathDelim+'.mcp.json',Broken);
  AssertEquals('the rest is still done',CLI_OK,Run('init|'+Work));
  AssertEquals('not a byte of it changed',Broken,Load(Work+PathDelim+'.mcp.json'));
  AssertTrue(Output.Text,Pos('.mcp.json was left alone',Output.Text)>0);
  AssertTrue('it prints the entry to add by hand',Pos('"'+InitMcpName+'": {',Output.Text)>0);
  AssertTrue(FileExists(Work+PathDelim+'AGENTS.md'));

  Save(Work+PathDelim+'.mcp.json','{"mcpServers":[1,2]}');
  AssertEquals(CLI_OK,Run('init|'+Work));
  AssertEquals('nor one whose servers are not what they should be','{"mcpServers":[1,2]}',Load(Work+PathDelim+'.mcp.json'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitNoMcp;
begin
  AssertEquals(CLI_OK,Run('init|'+Work+'|--no-mcp'));
  AssertFalse(FileExists(Work+PathDelim+'.mcp.json'));
  AssertTrue(FileExists(Work+PathDelim+'AGENTS.md'));
  AssertEquals('and the instructions do not speak of its tools',0,Pos('euo_run_live',Load(Work+PathDelim+'AGENTS.md')));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestInitUsageErrors;
begin
  AssertEquals('no such folder',CLI_USAGE,Run('init|'+Dir+PathDelim+'nowhere'));
  AssertEquals(CLI_USAGE,Run('init|'+Work+'|--frobnicate'));
  AssertEquals(CLI_USAGE,Run('init|'+Work+'|'+Dir));
  AssertEquals(CLI_USAGE,Run('init|'+Work+'|--pack'));
  AssertEquals('a pack that is none',CLI_USAGE,Run('init|'+Work+'|--pack|'+Work));
  AssertFalse('and nothing was written',DirectoryExists(Work+PathDelim+'.claude'));

  // Without the generated files it is not a pack to hand to an agent.
  DeleteFile(Pack+PathDelim+'language.md');
  AssertEquals(CLI_USAGE,Run('init|'+Work));
  AssertTrue(Output.Text,Pos('agent pack was not found',Output.Text)>0);
  AssertFalse(FileExists(Work+PathDelim+'AGENTS.md'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestDocsCommand;
begin
  AssertEquals(CLI_OK,Run('docs|finditem'));
  AssertEquals('the page','# FindItem',Trim(Output.Text));
  AssertEquals(CLI_OK,Run('docs|--search|finds|objects'));
  AssertTrue(Output.Text,Pos('finditem [client]: Finds objects.',Output.Text)=1);
  AssertEquals('not found',CLI_WARNINGS,Run('docs|nosuchthing'));
  AssertEquals(CLI_WARNINGS,Run('docs|--search|nosuchthing'));
  AssertEquals(CLI_USAGE,Run('docs'));
  AssertEquals(CLI_USAGE,Run('docs|finditem|--pack|'+Work));
  AssertEquals('a pack named by hand',CLI_OK,Run('docs|finditem|--pack|'+Pack));

  DeleteFile(Pack+PathDelim+'reference.json');
  AssertEquals('no pack',CLI_USAGE,Run('docs|finditem'));
  AssertTrue('it says where the pages are on the web',Pos('llms.txt',Output.Text)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliInitTests.TestHelpOfTheNewCommands;
begin
  AssertEquals(CLI_OK,Run('help'));
  AssertTrue(Pos('EUOCli mcp',Output.Text)>0);
  AssertTrue(Pos('EUOCli init',Output.Text)>0);
  AssertTrue(Pos('EUOCli docs',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|mcp'));
  AssertTrue(Pos('euo_run_live',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|init'));
  AssertTrue(Pos('.mcp.json',Output.Text)>0);
  AssertEquals(CLI_OK,Run('help|docs'));
  AssertTrue(Pos('--search',Output.Text)>0);
  AssertEquals('an option the server does not have',CLI_USAGE,Run('mcp|--frobnicate'));
end;

initialization
  RegisterTest(TEuoCliInitTests);

end.
