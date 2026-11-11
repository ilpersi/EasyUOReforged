unit EuoCliMcpTests;

{
  Tests for EUOCli's MCP server (tools\EUOCli\climcp.pas). They talk to TMcpServer.Handle,
  one JSON-RPC message in and its answer out, which is what the program does with every
  line of standard input. The run tools start a real TExecutor, so like EuoCliRunTests these
  depend a little on timing; the scripts are short and the waits generous.

  No test uses a UO client, whatever is running on the machine: euo_run cannot, and that is
  one of the things tested; euo_run_live is only asked for a client that is not there, and
  euo_vars is always told "client": 0.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, climcp, clisession;

type
  TEuoCliMcpTests = class(TTestCase)
  private
    Dir     : String;
    Server  : TMcpServer;
    Made    : TList;       // every parsed answer, freed in TearDown
    NextId  : Integer;
    IsError : Boolean;     // of the last tool call
    Text    : String;      // its text
    function  Keep(D : TJSONData) : TJSONData;
    // A request: the parsed answer (nil when there was none).
    function  Ask(const Method : String; const Params : String = '') : TJSONObject;
    // A tool call: the JSON object in its text, or nil when the text is not JSON.
    function  Tool(const Name : String; const Args : String = '{}') : TJSONObject;
    function  Events(Res : TJSONObject) : String;
    procedure MakePack;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialize;
    procedure TestDiscoverAndRequestsThatCarryTheVersion;
    procedure TestAVersionNobodyKnowsIsRefused;
    procedure TestPingNotificationsAndErrors;
    procedure TestToolList;
    procedure TestRunHasNoWayToAClientOrABlockedCommand;
    procedure TestUnknownTool;
    procedure TestCheck;
    procedure TestRunToItsEnd;
    procedure TestBlockedCommandStopsTheRun;
    procedure TestRunLive;
    procedure TestAScriptWithoutHaltIsStoppedAtItsRestart;
    procedure TestTimeout;
    procedure TestFollowAndStop;
    procedure TestBreakpointStepAndContinue;
    procedure TestStepIntoAndOut;
    procedure TestPauseAndContinue;
    procedure TestPausedTimeDoesNotCount;
    procedure TestVars;
    procedure TestDocs;
    procedure TestACancelledCallGetsNoAnswer;
    procedure TestShutdownStopsTheScript;
    procedure TestAnAnswerIsOneLine;
  end;

implementation

const
  V_MODERN = '"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}';

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
procedure SaveText(const FileName, Text : String);
var
  SL : TStringList;
begin
  ForceDirectories(ExtractFilePath(FileName));
  SL:=TStringList.Create;
  try
    SL.Text:=Text;
    SL.SaveToFile(FileName);
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// A script as the "script" argument: lines joined, as JSON text.
function Scr(const Lines : array of String) : String;
var
  i : Integer;
  S : String;
begin
  S:='';
  for i:=Low(Lines) to High(Lines) do
  begin
    if i>Low(Lines) then S:=S+#10;
    S:=S+Lines[i];
  end;
  Result:='"script":"'+StringToJSONString(S)+'"';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euoclimcp-'+IntToStr(GetProcessID);
  ForceDirectories(Dir);
  Made:=TList.Create;
  NextId:=0;
  // No pack next to "the program": the docs test makes its own and a server that reads it.
  Server:=TMcpServer.Create(Dir+PathDelim,'');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TearDown;
var
  i : Integer;
begin
  Server.Free;
  for i:=0 to Made.Count-1 do TObject(Made[i]).Free;
  Made.Free;
  RemoveTree(Dir);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliMcpTests.Keep(D : TJSONData) : TJSONData;
begin
  Made.Add(D);
  Result:=D;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliMcpTests.Ask(const Method : String; const Params : String) : TJSONObject;
var
  Line, Reply : String;
begin
  Inc(NextId);
  Line:='{"jsonrpc":"2.0","id":'+IntToStr(NextId)+',"method":"'+Method+'"';
  if Params<>'' then Line:=Line+',"params":'+Params;
  Line:=Line+'}';
  Reply:=Server.Handle(Line);
  if Reply='' then Exit(nil);
  Result:=TJSONObject(Keep(GetJSON(Reply)));
  AssertEquals('every answer is JSON-RPC 2.0','2.0',Result.Get('jsonrpc',''));
  AssertEquals('and carries the id of its request',NextId,Result.Get('id',-1));
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCliMcpTests.Tool(const Name : String; const Args : String) : TJSONObject;
var
  Reply  : TJSONObject;
  Res    : TJSONObject;
  Parsed : TJSONData;
begin
  Result:=nil;
  Reply:=Ask('tools/call','{"name":"'+Name+'","arguments":'+Args+'}');
  AssertNotNull(Name+' got an answer',Reply);
  if Reply.Find('error')<>nil then Fail(Name+': '+Reply.Find('error').AsJSON);
  Res:=Reply.Objects['result'];
  IsError:=Res.Get('isError',False);
  AssertEquals('one piece of text',1,Res.Arrays['content'].Count);
  AssertEquals('text',Res.Arrays['content'].Objects[0].Get('type',''));
  Text:=Res.Arrays['content'].Objects[0].Get('text','');
  if (Text<>'') and (Text[1]='{') then
  begin
    Parsed:=nil;
    try
      Parsed:=GetJSON(Text);
    except
      Parsed:=nil;
    end;
    if Parsed is TJSONObject then Result:=TJSONObject(Keep(Parsed))
    else Parsed.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The events of a run's answer, one per line: "log:text", "display:text", "line:3".
function TEuoCliMcpTests.Events(Res : TJSONObject) : String;
var
  Arr  : TJSONArray;
  i    : Integer;
  Kind : String;
begin
  Result:='';
  Arr:=Res.Arrays['events'];
  for i:=0 to Arr.Count-1 do
  begin
    Kind:=Arr.Objects[i].Get('event','');
    if Kind='line' then Result:=Result+'line:'+IntToStr(Arr.Objects[i].Get('line',0))+'|'
    else Result:=Result+Kind+':'+Arr.Objects[i].Get('text','')+'|';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestInitialize;
var
  R : TJSONObject;
begin
  R:=Ask('initialize','{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}');
  AssertEquals('a version it knows is the one used','2025-06-18',R.Objects['result'].Get('protocolVersion',''));
  AssertNotNull('it offers tools',R.Objects['result'].Objects['capabilities'].Find('tools'));
  AssertEquals(McpServerName,R.Objects['result'].Objects['serverInfo'].Get('name',''));
  AssertTrue('it says what it is for',Pos('euo_run_live',R.Objects['result'].Get('instructions',''))>0);
  AssertNull('the handshake has no resultType',R.Objects['result'].Find('resultType'));

  R:=Ask('initialize','{"protocolVersion":"2031-01-01","capabilities":{}}');
  AssertEquals('a version it does not know gets its newest handshake version',
    MCP_LATEST_LEGACY,R.Objects['result'].Get('protocolVersion',''));
  R:=Ask('initialize','{"protocolVersion":"2024-11-05","capabilities":{}}');
  AssertEquals('the oldest one too','2024-11-05',R.Objects['result'].Get('protocolVersion',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestDiscoverAndRequestsThatCarryTheVersion;
var
  R, Res : TJSONObject;
begin
  R:=Ask('server/discover','{'+V_MODERN+'}');
  Res:=R.Objects['result'];
  AssertEquals('complete',Res.Get('resultType',''));
  AssertEquals(MCP_MODERN,Res.Arrays['supportedVersions'].Strings[0]);
  AssertNotNull(Res.Objects['capabilities'].Find('tools'));
  AssertEquals(McpServerName,Res.Objects['_meta'].Objects['io.modelcontextprotocol/serverInfo'].Get('name',''));
  AssertTrue(Res.Get('ttlMs',0)>0);
  AssertEquals('public',Res.Get('cacheScope',''));

  Res:=Ask('tools/list','{'+V_MODERN+'}').Objects['result'];
  AssertEquals('a request that carries the version gets resultType','complete',Res.Get('resultType',''));
  AssertTrue(Res.Get('ttlMs',0)>0);
  AssertEquals('public',Res.Get('cacheScope',''));
  Res:=Ask('tools/call','{"name":"euo_stop","arguments":{},'+V_MODERN+'}').Objects['result'];
  AssertEquals('complete',Res.Get('resultType',''));

  Res:=Ask('tools/list').Objects['result'];
  AssertNull('one that does not, as after a handshake, gets none',Res.Find('resultType'));
  AssertNull(Res.Find('ttlMs'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestAVersionNobodyKnowsIsRefused;
var
  E : TJSONObject;
begin
  E:=Ask('tools/list','{"_meta":{"io.modelcontextprotocol/protocolVersion":"1999-01-01"}}').Objects['error'];
  AssertEquals(-32022,E.Get('code',0));
  AssertEquals('1999-01-01',E.Objects['data'].Get('requested',''));
  AssertEquals(MCP_MODERN,E.Objects['data'].Arrays['supported'].Strings[0]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestPingNotificationsAndErrors;
var
  R : TJSONObject;
begin
  AssertEquals('ping gets an empty result',0,Ask('ping').Objects['result'].Count);
  AssertEquals('a notification gets no answer','',Server.Handle('{"jsonrpc":"2.0","method":"notifications/initialized"}'));
  AssertEquals('','' +Server.Handle('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":5}}'));
  AssertEquals('an answer to nothing is ignored','',Server.Handle('{"jsonrpc":"2.0","id":3,"result":{}}'));
  AssertEquals('so is an empty line','',Server.Handle('   '));
  AssertEquals(-32601,Ask('resources/list').Objects['error'].Get('code',0));

  R:=TJSONObject(Keep(GetJSON(Server.Handle('{"jsonrpc":"2.0","id":'))));
  AssertEquals('not JSON',-32700,R.Objects['error'].Get('code',0));
  R:=TJSONObject(Keep(GetJSON(Server.Handle('[1,2]'))));
  AssertEquals('not a request',-32600,R.Objects['error'].Get('code',0));
  R:=TJSONObject(Keep(GetJSON(Server.Handle('{"jsonrpc":"2.0","id":9}'))));
  AssertEquals('no method',-32600,R.Objects['error'].Get('code',0));
  R:=TJSONObject(Keep(GetJSON(Server.Handle('{"jsonrpc":"2.0","id":"abc","method":"ping"}'))));
  AssertEquals('a text id comes back as it was','abc',R.Get('id',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestToolList;
const
  Names : array[0..11] of String = ('euo_check','euo_run','euo_run_live','euo_status','euo_stop','euo_pause',
    'euo_continue','euo_step','euo_breakpoint','euo_vars','euo_clients','euo_docs');
var
  Tools : TJSONArray;
  T     : TJSONObject;
  i     : Integer;
begin
  Tools:=Ask('tools/list').Objects['result'].Arrays['tools'];
  AssertEquals(Length(Names),Tools.Count);
  for i:=0 to Tools.Count-1 do
  begin
    T:=Tools.Objects[i];
    AssertEquals(Names[i],T.Get('name',''));
    AssertTrue(Names[i]+' says what it does',Length(T.Get('description',''))>40);
    AssertEquals(Names[i],'object',T.Objects['inputSchema'].Get('type',''));
    AssertNotNull(Names[i],T.Objects['inputSchema'].Find('properties'));
    AssertNotNull(Names[i],T.Objects['annotations'].Find('readOnlyHint'));
  end;
  AssertTrue('checking changes nothing',Tools.Objects[0].Objects['annotations'].Get('readOnlyHint',False));
  AssertFalse('a run without a client harms nothing',Tools.Objects[1].Objects['annotations'].Get('destructiveHint',True));
  AssertTrue('a run on the game can',Tools.Objects[2].Objects['annotations'].Get('destructiveHint',False));
end;

////////////////////////////////////////////////////////////////////////////////
// The owner's decision: allowing euo_run for good must never allow a run on the user's
// character or a command that reaches beyond the script. So euo_run has no argument for
// either, and refuses a call that passes one anyway.
procedure TEuoCliMcpTests.TestRunHasNoWayToAClientOrABlockedCommand;
var
  Tools : TJSONArray;
  Props : TJSONObject;
begin
  Tools:=Ask('tools/list').Objects['result'].Arrays['tools'];
  Props:=Tools.Objects[1].Objects['inputSchema'].Objects['properties'];
  AssertEquals('euo_run',Tools.Objects[1].Get('name',''));
  AssertNull('euo_run has no client argument',Props.Find('client'));
  AssertNull('and no allow argument',Props.Find('allow'));
  AssertFalse('nor may it take others',Tools.Objects[1].Objects['inputSchema'].Get('additionalProperties',True));
  Props:=Tools.Objects[2].Objects['inputSchema'].Objects['properties'];
  AssertNotNull('euo_run_live has both',Props.Find('client'));
  AssertNotNull(Props.Find('allow'));

  Tool('euo_run','{'+Scr(['log ran','halt'])+',"client":1}');
  AssertTrue('a client passed to euo_run is an error',IsError);
  AssertTrue(Text,Pos('euo_run_live',Text)>0);
  Tool('euo_run','{'+Scr(['log ran','halt'])+',"allow":["execute"]}');
  AssertTrue('so is allow',IsError);
  AssertEquals('and nothing ran','none',Tool('euo_status').Get('state',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestUnknownTool;
begin
  AssertEquals(-32602,Ask('tools/call','{"name":"euo_nothing","arguments":{}}').Objects['error'].Get('code',0));
  AssertEquals('arguments may be left out',-32602,Ask('tools/call','{"name":"euo_nothing"}').Objects['error'].Get('code',0));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestCheck;
var
  R  : TJSONObject;
  FN : String;
begin
  R:=Tool('euo_check','{'+Scr(['finditm POF','halt'])+'}');
  AssertFalse(IsError);
  AssertEquals(1,R.Objects['summary'].Get('warnings',0));
  AssertEquals('unknown-command',R.Arrays['findings'].Objects[0].Get('rule',''));
  AssertEquals(1,R.Arrays['findings'].Objects[0].Get('line',0));

  FN:=Dir+PathDelim+'ok.euo';
  SaveText(FN,'set %a 1'+LineEnding+'halt'+LineEnding);
  R:=Tool('euo_check','{"file":"'+StringToJSONString(FN)+'"}');
  AssertEquals('a file',0,R.Objects['summary'].Get('warnings',-1));
  AssertEquals(FN,R.Get('file',''));

  Tool('euo_check','{}');
  AssertTrue('no script is an error the agent can read',IsError);
  Tool('euo_check','{"file":"'+StringToJSONString(Dir+PathDelim+'none.euo')+'"}');
  AssertTrue(IsError);
  AssertTrue(Text,Pos('file not found',Text)=1);
  Tool('euo_check','{"script":"halt","file":"x.euo"}');
  AssertTrue('both is one too many',IsError);
  Tool('euo_check','{"script":5}');
  AssertTrue('a wrong kind of value',IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestRunToItsEnd;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['set %a 2 + 3','log the sum is %a','display yesno go on?','log answered #DispRes',
    'finditem ABC G_2','halt'])+',"watch":["%a","#DispRes"]}');
  AssertFalse(Text,IsError);
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('halt',R.Get('reason',''));
  AssertEquals(6,R.Get('line',0));
  AssertEquals(1,R.Get('run',0));
  AssertEquals('no client',0,R.Get('client',-1));
  AssertEquals('the line that needs a client was skipped',1,R.Get('clientLinesSkipped',0));
  AssertEquals('log:the sum is 5|display:go on?|log:answered Yes|',Events(R));
  AssertEquals('5',R.Objects['vars'].Get('%a',''));
  AssertEquals('Yes',R.Objects['vars'].Get('#DispRes',''));
  AssertEquals('it says what is blocked',5,R.Arrays['blocked'].Count);

  R:=Tool('euo_run','{'+Scr(['display yesno go on?','log answered #DispRes','halt'])+',"answer":"no"}');
  AssertEquals('display:go on?|log:answered No|',Events(R));
  AssertEquals('a second run has its own number',2,R.Get('run',0));

  R:=Tool('euo_run','{'+Scr(['set %a 1','halt'])+',"trace":true}');
  AssertEquals('line:1|line:2|',Events(R));

  Tool('euo_run','{"script":"   "}');
  AssertTrue('an empty script',IsError);
  Tool('euo_run','{"script":"halt","answer":"maybe"}');
  AssertTrue(IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestBlockedCommandStopsTheRun;
const
  Cmds : array[0..4] of String = ('execute notepad.exe','shutdown','terminate uo','uoxl new','send httppost example.invalid /x y');
var
  R : TJSONObject;
  i : Integer;
begin
  for i:=Low(Cmds) to High(Cmds) do
  begin
    R:=Tool('euo_run','{'+Scr(['log before',Cmds[i],'log after','halt'])+'}');
    AssertEquals(Cmds[i],'blocked',R.Get('reason',''));
    AssertEquals(2,R.Get('line',0));
    AssertEquals('nothing after the blocked line ran','log:before|',Events(R));
    AssertTrue('it names the tool that could run it',Pos('euo_run_live',R.Get('detail',''))>0);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestRunLive;
var
  R : TJSONObject;
begin
  Tool('euo_run_live','{'+Scr(['halt'])+'}');
  AssertTrue('it is for a client or an allowed command: neither is an error',IsError);
  AssertTrue(Text,Pos('euo_run',Text)>0);

  // TERMINATE with a word it does not know does nothing: safe to let through.
  R:=Tool('euo_run_live','{'+Scr(['terminate nothing','log after','halt'])+',"allow":["terminate"]}');
  AssertFalse(Text,IsError);
  AssertEquals('halt',R.Get('reason',''));
  AssertEquals('log:after|',Events(R));
  AssertEquals('the others stay blocked',4,R.Arrays['blocked'].Count);
  AssertEquals('and still no client',0,R.Get('client',-1));

  Tool('euo_run_live','{'+Scr(['halt'])+',"allow":["finditem"]}');
  AssertTrue('only blocked commands can be allowed',IsError);

  // A client that is not there, whatever is running on this machine.
  Tool('euo_run_live','{'+Scr(['log ran','halt'])+',"client":987}');
  AssertTrue(IsError);
  AssertTrue(Text,(Pos('no UO client',Text)>0) or (Pos('no client number 987',Text)>0));
  AssertEquals('the run before it is still the last one',1,Tool('euo_status').Get('run',0));
  AssertEquals('and its variables can still be read','run',Tool('euo_vars','{"names":["#EUOVer"]}').Get('source',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestAScriptWithoutHaltIsStoppedAtItsRestart;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['log a','log b'])+'}');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('restart',R.Get('reason',''));
  AssertEquals('each line ran once','log:a|log:b|',Events(R));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestTimeout;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['log a','wait 30s','log never','halt'])+',"timeout":1,"wait":10}');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('timeout',R.Get('reason',''));
  AssertEquals('log:a|',Events(R));
  Tool('euo_run','{"script":"halt","timeout":-1}');
  AssertTrue(IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestFollowAndStop;
var
  R : TJSONObject;
begin
  R:=Tool('euo_status');
  AssertEquals('before any run','none',R.Get('state',''));

  R:=Tool('euo_run','{'+Scr(['log start','wait 30s','log never','halt'])+',"wait":0.5}');
  AssertEquals('it answers while the script is still going','running',R.Get('state',''));
  AssertEquals('log:start|',Events(R));
  R:=Tool('euo_status');
  AssertEquals('running',R.Get('state',''));
  AssertEquals('an event is reported once','',Events(R));

  Tool('euo_run','{'+Scr(['halt'])+'}');
  AssertTrue('one script at a time',IsError);
  AssertTrue(Text,Pos('euo_stop',Text)>0);
  Tool('euo_step');
  AssertTrue('a running script cannot be stepped',IsError);
  Tool('euo_continue');
  AssertTrue(IsError);

  R:=Tool('euo_stop');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('stopped',R.Get('reason',''));
  R:=Tool('euo_status','{"wait":0.3}');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('nothing ran after the stop','',Events(R));
  AssertEquals('stopping twice is no error','ended',Tool('euo_stop').Get('state',''));
  Tool('euo_pause');
  AssertTrue('an ended script cannot be paused',IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestBreakpointStepAndContinue;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['set %i 0','repeat','  set %i %i + 1','  log round %i','until %i >= 5','halt'])+
    ',"breakpoints":[{"line":4,"condition":"%i > 2"}],"watch":["%i"]}');
  AssertFalse(Text,IsError);
  AssertEquals('paused',R.Get('state',''));
  AssertEquals(4,R.Get('line',0));
  AssertEquals('log round %i',R.Get('text',''));
  AssertEquals('the condition held it back until then','log:round 1|log:round 2|',Events(R));
  AssertEquals('3',R.Objects['vars'].Get('%i',''));
  AssertEquals(1,R.Arrays['breakpoints'].Count);
  AssertEquals('%i > 2',R.Arrays['breakpoints'].Objects[0].Get('condition',''));

  R:=Tool('euo_step');
  AssertEquals('paused',R.Get('state',''));
  AssertEquals('one line on',5,R.Get('line',0));
  AssertEquals('log:round 3|',Events(R));

  R:=Tool('euo_continue');
  AssertEquals('the breakpoint again',4,R.Get('line',0));
  AssertEquals('4',R.Objects['vars'].Get('%i',''));

  R:=Tool('euo_breakpoint','{"line":4,"remove":true}');
  AssertEquals(0,R.Arrays['breakpoints'].Count);
  R:=Tool('euo_breakpoint','{"line":6}');
  AssertEquals(1,R.Arrays['breakpoints'].Count);
  AssertEquals(6,R.Arrays['breakpoints'].Objects[0].Get('line',0));
  R:=Tool('euo_continue');
  AssertEquals('paused',R.Get('state',''));
  AssertEquals('the new one',6,R.Get('line',0));
  AssertEquals('log:round 4|log:round 5|',Events(R));

  R:=Tool('euo_breakpoint','{"clear_all":true}');
  AssertEquals(0,R.Arrays['breakpoints'].Count);
  R:=Tool('euo_continue');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('halt',R.Get('reason',''));
  Tool('euo_breakpoint','{"line":2}');
  AssertTrue('a breakpoint needs a script that is alive',IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestStepIntoAndOut;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['gosub a','log back','halt','sub a','  log in','  log in2','return'])+',"step":true}');
  AssertEquals('paused',R.Get('state',''));
  AssertEquals('the first line ran: inside the sub',5,R.Get('line',0));
  AssertEquals(1,R.Get('depth',0));
  R:=Tool('euo_step','{"mode":"into"}');
  AssertEquals(6,R.Get('line',0));
  R:=Tool('euo_step','{"mode":"out"}');
  AssertEquals('back where the sub was called from',2,R.Get('line',0));
  AssertEquals(0,R.Get('depth',-1));
  AssertEquals('log:in2|',Events(R));
  R:=Tool('euo_continue','{"to_line":3}');
  AssertEquals('paused',R.Get('state',''));
  AssertEquals(3,R.Get('line',0));
  R:=Tool('euo_step');
  AssertEquals('ended',R.Get('state',''));
  Tool('euo_step','{"mode":"sideways"}');
  AssertTrue(IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestPauseAndContinue;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['set %i 0','repeat','  set %i %i + 1','until %i > 100000000','halt'])+',"wait":0.3}');
  AssertEquals('running',R.Get('state',''));
  R:=Tool('euo_pause');
  AssertEquals('paused',R.Get('state',''));
  AssertTrue('it had counted',StrToIntDef(Tool('euo_vars','{"names":["%i"]}').Objects['vars'].Get('%i',''),0)>0);
  AssertEquals('pausing twice is no error','paused',Tool('euo_pause').Get('state',''));
  R:=Tool('euo_continue','{"wait":0.2}');
  AssertEquals('running',R.Get('state',''));
  AssertEquals('ended',Tool('euo_stop').Get('state',''));
end;

////////////////////////////////////////////////////////////////////////////////
// The timeout is there for a script that never ends, not for an agent that thinks between
// two steps.
procedure TEuoCliMcpTests.TestPausedTimeDoesNotCount;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['log a','log b','halt'])+',"step":true,"timeout":1}');
  AssertEquals('paused',R.Get('state',''));
  PumpFor(1600);
  Server.Tick;
  R:=Tool('euo_status');
  AssertEquals('still paused after the timeout has passed','paused',R.Get('state',''));
  R:=Tool('euo_continue');
  AssertEquals('halt',R.Get('reason',''));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestVars;
var
  R : TJSONObject;
begin
  Tool('euo_vars','{"names":["%a"],"client":0}');
  AssertTrue('a script variable needs a run',IsError);
  Tool('euo_vars','{}');
  AssertTrue(IsError);
  R:=Tool('euo_vars','{"names":["EUOVer","#CharPosX"],"client":0}');
  AssertFalse(Text,IsError);
  AssertEquals('client',R.Get('source',''));
  AssertEquals('a bare name is a #variable','1_50_00',R.Objects['vars'].Get('#EUOVer',''));
  AssertEquals('N/A',R.Objects['vars'].Get('#CharPosX',''));

  Tool('euo_run','{'+Scr(['set %count 7','set !mine hello','str len abcde','halt'])+'}');
  R:=Tool('euo_vars','{"names":["%count","!mine","#StrRes"]}');
  AssertEquals('after a run, the run is read','run',R.Get('source',''));
  AssertEquals('7',R.Objects['vars'].Get('%count',''));
  AssertEquals('hello',R.Objects['vars'].Get('!mine',''));
  AssertEquals('what its commands put into #variables too','5',R.Objects['vars'].Get('#StrRes',''));
  R:=Tool('euo_vars','{"all":true}');
  AssertEquals('every variable the script made','7',R.Objects['vars'].Get('%COUNT',''));
  Tool('euo_vars','{"names":["%count"],"client":0}');
  AssertTrue('with a client named, it is not the run that is read',IsError);
end;

////////////////////////////////////////////////////////////////////////////////
// A pack of three pages, as tools\docs\gen-agent-pack.mjs lays one out.
procedure TEuoCliMcpTests.MakePack;
var
  P : String;
begin
  P:=Dir+PathDelim+'pack'+PathDelim;
  SaveText(P+'reference.json',
    '{"commands":[{"name":"finditem","title":"FindItem","description":"Finds objects by type or id.",'+
    '"needsClient":true,"origin":"original","aliases":["search item"],"file":"reference/commands/finditem.md"},'+
    '{"name":"event macro","title":"Event Macro","description":"Runs a client macro.","needsClient":true,'+
    '"origin":"original","aliases":[],"file":"reference/commands/event/macro.md"},'+
    '{"name":"log","title":"Log","description":"Writes a line to the Output panel.","needsClient":false,'+
    '"origin":"reforged","aliases":["print"],"file":"reference/commands/log.md"}],'+
    '"variables":[{"name":"#FindKind","title":"#FindKind","description":"Where the found object is.",'+
    '"needsClient":true,"origin":"original","aliases":[],"file":"reference/variables/findkind.md"}],'+
    '"pages":[{"title":"Common mistakes","description":"The rules scripts break.","file":"language.md"}]}');
  SaveText(P+'reference'+PathDelim+'commands'+PathDelim+'finditem.md','# FindItem'+LineEnding+LineEnding+'The page of finditem.');
  SaveText(P+'reference'+PathDelim+'commands'+PathDelim+'event'+PathDelim+'macro.md','# Event Macro');
  SaveText(P+'reference'+PathDelim+'commands'+PathDelim+'log.md','# Log');
  SaveText(P+'reference'+PathDelim+'variables'+PathDelim+'findkind.md','# #FindKind');
  SaveText(P+'language.md','# Common mistakes');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestDocs;
begin
  Tool('euo_docs','{"name":"finditem"}');
  AssertTrue('without a pack it says so',IsError);
  AssertTrue(Text,Pos('llms.txt',Text)>0);

  MakePack;
  Server.Free;
  Server:=TMcpServer.Create(Dir+PathDelim,Dir+PathDelim+'pack');
  Tool('euo_docs','{"name":"FindItem"}');
  AssertFalse(Text,IsError);
  AssertTrue('the page itself',Pos('The page of finditem.',Text)>0);
  Tool('euo_docs','{"name":"event  macro"}');
  AssertEquals('a sub-command, however it is spaced','# Event Macro',Trim(Text));
  Tool('euo_docs','{"name":"findkind"}');
  AssertEquals('a variable without its #','# #FindKind',Trim(Text));
  Tool('euo_docs','{"name":"print"}');
  AssertEquals('an alias','# Log',Trim(Text));
  Tool('euo_docs','{"name":"common mistakes"}');
  AssertEquals('a guide by its title','# Common mistakes',Trim(Text));

  Tool('euo_docs','{"search":"object"}');
  AssertFalse(IsError);
  AssertTrue(Text,Pos('finditem [client]: Finds objects by type or id.',Text)=1);
  AssertTrue('the variable too',Pos('#FindKind [client]',Text)>0);
  AssertTrue('not what does not match',Pos('event macro',Text)=0);
  Tool('euo_docs','{"search":"output line"}');
  AssertTrue('every word, in any order',Pos('log [new]',Text)=1);

  Tool('euo_docs','{"name":"finditm"}');
  AssertTrue('a name that is not there is an error',IsError);
  AssertTrue(Text,Pos('Nothing in the documentation matches',Text)=1);
  Tool('euo_docs','{"name":"item"}');
  AssertTrue('with what comes close',IsError and (Pos('finditem',Text)>0));
  Tool('euo_docs','{}');
  AssertTrue(IsError);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCliMcpTests.TestACancelledCallGetsNoAnswer;
var
  Start : QWord;
  Reply : String;
begin
  // The agent's program gave up on call 77 while the server was still waiting in it.
  Server.Push('{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":77,"reason":"enough"}}');
  Start:=GetTickCount64;
  Reply:=Server.Handle('{"jsonrpc":"2.0","id":77,"method":"tools/call","params":{"name":"euo_run","arguments":{'+
    Scr(['log start','wait 30s','halt'])+',"wait":20}}}');
  AssertEquals('no answer',Reply,'');
  AssertTrue('and no waiting',GetTickCount64-Start<5000);
  AssertFalse('the notice is used up',Server.HasPending);
  AssertEquals('the script itself goes on','running',Tool('euo_status').Get('state',''));
  AssertEquals('ended',Tool('euo_stop').Get('state',''));
end;

////////////////////////////////////////////////////////////////////////////////
// The program calls Shutdown when the agent's program closes the connection: a script
// never outlives the session that started it.
procedure TEuoCliMcpTests.TestShutdownStopsTheScript;
var
  R : TJSONObject;
begin
  R:=Tool('euo_run','{'+Scr(['log start','wait 30s','log never','halt'])+',"wait":0.3}');
  AssertEquals('running',R.Get('state',''));
  Server.Shutdown;
  R:=Tool('euo_status');
  AssertEquals('ended',R.Get('state',''));
  AssertEquals('stopped',R.Get('reason',''));
  AssertEquals('',Events(R));
end;

////////////////////////////////////////////////////////////////////////////////
// The protocol is one message per line: a text with line breaks must not break it.
procedure TEuoCliMcpTests.TestAnAnswerIsOneLine;
var
  Reply : String;
begin
  Reply:=Server.Handle('{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"euo_run","arguments":{'+
    Scr(['display ok one$two$','halt'])+'}}}');
  AssertTrue(Reply<>'');
  AssertEquals(0,Pos(#10,Reply));
  AssertEquals(0,Pos(#13,Reply));
  Reply:=Server.Handle('{"jsonrpc":"2.0","id":2,"method":"tools/list"}');
  AssertEquals(0,Pos(#10,Reply));
end;

initialization
  RegisterTest(TEuoCliMcpTests);

end.
