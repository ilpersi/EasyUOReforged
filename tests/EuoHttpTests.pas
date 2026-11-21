unit EuoHttpTests;

{
  Tests for SEND's new forms (parser\EuoHttp.pas, TEuoInterpreter.SendHttpProc), the frozen original
  form SEND HTTPPOST (EuoComm.pas), and STR URLENCODE / JSONESCAPE (EuoStrOps.pas), with no client
  and no network: every request goes to a small HTTP server on 127.0.0.1 that this unit runs on a
  thread of its own. It records the bytes of each request and answers what the test set for its path;
  a path without an answer never answers (for the timeout, Cancel and Stop tests).

  https can't be served here without a certificate: it is hand-checked (tests\euo\send-hand-test.euo).
  The one name lookup (an .invalid host, which never resolves) needs no network either.

  FPC 3.2.2's WinSock unit imports getsockname as getpeername, so the server declares its own.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, SyncObjs, WinSock, fpcunit, testregistry,
  EuoHttp, EuoStrOps, EuoInterpreter, EuoExecutor;

type
  TCond = function : Boolean of object;

  TTestHttpServer = class(TThread)
  private
    FListen    : TSocket;
    FLock      : TCriticalSection;
    FPaths     : TStringList;    // the paths that answer
    FReplies   : TStringList;    // their raw answers, same index
    FRequests  : TStringList;    // the raw bytes of each request, in order
    FHangEnded : Boolean;        // a request that got no answer was closed by the client
    function  Answer(const Raw : String) : String;
    procedure Serve(C : TSocket);
  protected
    procedure Execute; override;
  public
    Port : Word;
    constructor Create;
    destructor  Destroy; override;
    procedure Route(const Path, Reply : String);
    function  RequestCount : Integer;
    function  Request(i : Integer) : String;
    function  HangEnded : Boolean;
  end;

  TEuoHttpTests = class(TTestCase)
  private
    Srv    : TTestHttpServer;
    Interp : TEuoInterpreter;
    Dir    : String;     // the test's own folder, with a trailing '\'
    function  Url(const Path : String) : String;
    function  Req(const Method, Path : String; const Body : String = ''; const Headers : String = '') : TEuoHttpRequest;
    procedure Play(const Script : array of String; MaxSteps : Integer = 2000);
    function  WaitUntil(Cond : TCond; Ms : Integer) : Boolean;
    function  ReadFile(const FN : String) : String;
    procedure WriteFile(const FN, Data : String);
    function  GotRequest : Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestUrlEncode;
    procedure TestJsonEscape;
    procedure TestSendHeaderLines;
    procedure TestGetSendsTheRequestAndKeepsTheReply;
    procedure TestPostBodyAndDefaultContentType;
    procedure TestSendHeaderOverridesTypeAndAgent;
    procedure TestPutAndDelete;
    procedure TestAnErrorStatusIsStillAnAnswer;
    procedure TestRedirectIsFollowed;
    procedure TestRefusedPort;
    procedure TestUnresolvableHost;
    procedure TestBadUrls;
    procedure TestReplyOverOneMegabyte;
    procedure TestDownloadWritesTheFile;
    procedure TestRefusedDownloadKeepsTheOldFile;
    procedure TestTimeout;
    procedure TestCancelEndsTheRequest;
    procedure TestScriptGetSetsTheVariables;
    procedure TestScriptPostTakesTheRestOfTheLine;
    procedure TestScriptWordErrors;
    procedure TestScriptVariablesAreNAUntilASendAndAfterClear;
    procedure TestScriptDownload;
    procedure TestScriptDownloadIsConfined;
    procedure TestScriptStrUrlEncodeAndJsonEscape;
    procedure TestStopDuringASendLeavesTheVariables;
    procedure TestOriginalFormIsByteForByte;
    procedure TestOriginalFormWithSendHeader;
  end;

implementation

const
  CRLF = #13#10;

function ws_getsockname(s : TSocket; var name : TSockAddrIn; var namelen : Integer) : Integer; stdcall;
  external 'wsock32.dll' name 'getsockname';

////////////////////////////////////////////////////////////////////////////////
function HttpReply(Code : Integer; const Body : String; const Extra : String = '') : String;
begin
  Result:='HTTP/1.1 '+IntToStr(Code)+' X'+CRLF+'Content-Length: '+IntToStr(Length(Body))+CRLF+
    'Connection: close'+CRLF+Extra+CRLF+Body;
end;

function Readable(S : TSocket; Ms : Integer) : Boolean;
var
  FD : TFDSet;
  TV : TTimeVal;
begin
  FD.fd_count:=1;
  FD.fd_array[0]:=S;
  TV.tv_sec:=Ms div 1000;
  TV.tv_usec:=(Ms mod 1000)*1000;
  Result:=select(0,@FD,nil,nil,@TV)>0;
end;

// The header part of a request, the first line included; '' while it is not complete.
function HeadOf(const Raw : String) : String;
var
  i : Integer;
begin
  i:=Pos(CRLF+CRLF,Raw);
  if i<1 then Result:='' else Result:=Copy(Raw,1,i+1);
end;

function HeaderValue(const Raw, Name : String) : String;
var
  Lines : TStringList;
  i     : Integer;
begin
  Result:='';
  Lines:=TStringList.Create;
  try
    Lines.Text:=HeadOf(Raw);
    for i:=1 to Lines.Count-1 do
      if LowerCase(Trim(Copy(Lines[i],1,Pos(':',Lines[i])-1)))=LowerCase(Name) then
        Exit(Trim(Copy(Lines[i],Pos(':',Lines[i])+1,MaxInt)));
  finally
    Lines.Free;
  end;
end;

function HasHeader(const Raw, Name : String) : Boolean;
begin
  Result:=Pos(CRLF+LowerCase(Name)+':',LowerCase(HeadOf(Raw)))>0;
end;

function FirstLine(const Raw : String) : String;
begin
  Result:=Copy(Raw,1,Pos(CRLF,Raw)-1);
end;

function BodyOf(const Raw : String) : String;
begin
  Result:=Copy(Raw,Pos(CRLF+CRLF,Raw)+4,MaxInt);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TTestHttpServer.Create;
var
  A : TSockAddrIn;
  L : Integer;
begin
  inherited Create(True);
  FLock:=TCriticalSection.Create;
  FPaths:=TStringList.Create;
  FReplies:=TStringList.Create;
  FRequests:=TStringList.Create;
  FListen:=socket(AF_INET,SOCK_STREAM,0);
  FillChar(A,SizeOf(A),0);
  A.sin_family:=AF_INET;
  A.sin_port:=0;
  A.sin_addr.s_addr:=inet_addr('127.0.0.1');
  bind(FListen,PSockAddr(@A),SizeOf(A));
  listen(FListen,8);
  L:=SizeOf(A);
  ws_getsockname(FListen,A,L);
  Port:=ntohs(A.sin_port);
  Start;
end;

destructor TTestHttpServer.Destroy;
begin
  Terminate;
  WaitFor;
  closesocket(FListen);
  FRequests.Free;
  FReplies.Free;
  FPaths.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TTestHttpServer.Route(const Path, Reply : String);
begin
  FLock.Acquire;
  try
    FPaths.Add(Path);
    FReplies.Add(Reply);
  finally
    FLock.Release;
  end;
end;

function TTestHttpServer.RequestCount : Integer;
begin
  FLock.Acquire;
  try
    Result:=FRequests.Count;
  finally
    FLock.Release;
  end;
end;

function TTestHttpServer.Request(i : Integer) : String;
begin
  FLock.Acquire;
  try
    Result:=FRequests[i];
  finally
    FLock.Release;
  end;
end;

function TTestHttpServer.HangEnded : Boolean;
begin
  FLock.Acquire;
  try
    Result:=FHangEnded;
  finally
    FLock.Release;
  end;
end;

// The answer for the path of the request line; a path not routed gets a 404, a path routed to ''
// gets nothing.
function TTestHttpServer.Answer(const Raw : String) : String;
var
  Line : String;
  Path : String;
  i    : Integer;
begin
  Line:=FirstLine(Raw);
  Path:=Copy(Line,Pos(' ',Line)+1,MaxInt);
  Path:=Copy(Path,1,Pos(' ',Path)-1);
  FLock.Acquire;
  try
    i:=FPaths.IndexOf(Path);
    if i<0 then Result:=HttpReply(404,'no route '+Path)
    else Result:=FReplies[i];
  finally
    FLock.Release;
  end;
end;

procedure TTestHttpServer.Serve(C : TSocket);
var
  Buf   : array[0..65535] of Char;
  Chunk : String;
  Raw   : String;
  Reply : String;
  N     : Integer;
  Sent  : Integer;
  Head  : String;
  Need  : Integer;
  T     : QWord;
begin
  Raw:='';
  repeat
    if not Readable(C,5000) then Break;
    N:=recv(C,@Buf[0],SizeOf(Buf),0);
    if N<=0 then Break;
    SetString(Chunk,PChar(@Buf[0]),N);
    Raw:=Raw+Chunk;
    Head:=HeadOf(Raw);
    if Head<>'' then
    begin
      Need:=Length(Head)+2+StrToIntDef(HeaderValue(Raw,'Content-Length'),0);
      if Length(Raw)>=Need then Break;
    end;
  until Terminated;
  // What else arrives at once: the original form sends more than its Content-Length counts.
  while Readable(C,100) do
  begin
    N:=recv(C,@Buf[0],SizeOf(Buf),0);
    if N<=0 then Break;
    SetString(Chunk,PChar(@Buf[0]),N);
    Raw:=Raw+Chunk;
  end;
  FLock.Acquire;
  try
    FRequests.Add(Raw);
  finally
    FLock.Release;
  end;

  Reply:=Answer(Raw);
  if Reply='' then
  begin
    // No answer: wait until the client gives up.
    while not Terminated do
      if Readable(C,20) then
      begin
        N:=recv(C,@Buf[0],SizeOf(Buf),0);
        if N<=0 then
        begin
          FLock.Acquire;
          FHangEnded:=True;
          FLock.Release;
          Break;
        end;
      end;
  end
  else
  begin
    Sent:=0;
    while Sent<Length(Reply) do
    begin
      N:=send(C,PChar(@Reply[Sent+1]),Length(Reply)-Sent,0);
      if N<=0 then Break;
      Inc(Sent,N);
    end;
    shutdown(C,1);   // SD_SEND, which FPC's WinSock unit hides on Windows
    T:=GetTickCount64;
    while (GetTickCount64-T<3000) and not Terminated do
      if Readable(C,20) then
      begin
        N:=recv(C,@Buf[0],SizeOf(Buf),0);
        if N<=0 then Break;
      end;
  end;
  closesocket(C);
end;

procedure TTestHttpServer.Execute;
var
  C : TSocket;
begin
  while not Terminated do
  begin
    if not Readable(FListen,50) then Continue;
    C:=accept(FListen,nil,nil);
    if C=INVALID_SOCKET then Continue;
    Serve(C);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHttpTests.SetUp;
begin
  Srv:=TTestHttpServer.Create;
  Dir:=IncludeTrailingPathDelimiter(GetTempDir(False))+'euohttp-'+IntToStr(GetTickCount64)+'-'+
    IntToStr(Random(100000))+'\';
  ForceDirectories(Dir);
  Interp:=TEuoInterpreter.Create(0);
  Interp.Clear;
end;

procedure TEuoHttpTests.TearDown;
var
  SR : TSearchRec;
begin
  Interp.Free;
  Srv.Free;
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

function TEuoHttpTests.Url(const Path : String) : String;
begin
  Result:='http://127.0.0.1:'+IntToStr(Srv.Port)+Path;
end;

function TEuoHttpTests.Req(const Method, Path : String; const Body : String; const Headers : String) : TEuoHttpRequest;
begin
  Result.Method:=Method;
  Result.Url:=Url(Path);
  Result.Headers:=Headers;
  Result.Body:=Body;
  Result.SaveTo:='';
  Result.Timeout:=5000;
end;

procedure TEuoHttpTests.Play(const Script : array of String; MaxSteps : Integer);
var
  Cnt : Integer;
  S   : String;
begin
  S:='';
  for Cnt:=Low(Script) to High(Script) do S:=S+Script[Cnt]+CRLF;
  Interp.ScrList.Scr.Text:=S;
  Interp.NextLine:=0;
  Interp.ResInt:=RES_OK;
  Cnt:=0;
  while (Interp.ResInt<>RES_STOP) and (Interp.ResInt<>RES_CLOSE) and (Cnt<MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

function TEuoHttpTests.WaitUntil(Cond : TCond; Ms : Integer) : Boolean;
var
  T : QWord;
begin
  T:=GetTickCount64;
  repeat
    if Cond() then Exit(True);
    Sleep(10);
  until GetTickCount64-T>QWord(Ms);
  Result:=Cond();
end;

function TEuoHttpTests.GotRequest : Boolean;
begin
  Result:=Srv.RequestCount>0;
end;

function TEuoHttpTests.ReadFile(const FN : String) : String;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;
end;

procedure TEuoHttpTests.WriteFile(const FN, Data : String);
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmCreate);
  try
    if Data<>'' then FS.WriteBuffer(Data[1],Length(Data));
  finally
    FS.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHttpTests.TestUrlEncode;
begin
  AssertEquals('AZaz09-_.~',StrUrlEncode('AZaz09-_.~'));
  AssertEquals('a%20b%26c%3Dd%2Be',StrUrlEncode('a b&c=d+e'));
  AssertEquals('%25%3F%2F%23%22%27%2C',StrUrlEncode('%?/#"'','));
  AssertEquals('bytes, so UTF-8 stays UTF-8','caf%C3%A8',StrUrlEncode('caf'#$C3#$A8));
  AssertEquals('%0D%0A%00',StrUrlEncode(#13#10#0));
  AssertEquals('',StrUrlEncode(''));
end;

procedure TEuoHttpTests.TestJsonEscape;
begin
  AssertEquals('plain text',StrJsonEscape('plain text'));
  AssertEquals('say \"hi\" \\ bye',StrJsonEscape('say "hi" \ bye'));
  AssertEquals('a\nb\r\tc\b\f',StrJsonEscape('a'#10'b'#13#9'c'#8#12));
  AssertEquals('\u0000\u001f\u000b',StrJsonEscape(#0#31#11));
  AssertEquals('bytes over 127 stay','caf'#$C3#$A8' / {x}',StrJsonEscape('caf'#$C3#$A8' / {x}'));
end;

procedure TEuoHttpTests.TestSendHeaderLines;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    SendHeaderLines('A: 1$B: 2$',L);
    AssertEquals('A: 1|B: 2|',StringReplace(L.Text,CRLF,'|',[rfReplaceAll]));
    SendHeaderLines('N/A',L);
    AssertEquals('N/A sends nothing',0,L.Count);
    SendHeaderLines('',L);
    AssertEquals(0,L.Count);
    SendHeaderLines('  X-A : v $ $junk$:novalue$C:d',L);
    AssertEquals('X-A : v|C:d|',StringReplace(L.Text,CRLF,'|',[rfReplaceAll]));
  finally
    L.Free;
  end;
end;

procedure TEuoHttpTests.TestGetSendsTheRequestAndKeepsTheReply;
var
  R   : TEuoHttpResult;
  Raw : String;
begin
  Srv.Route('/a?x=1&y=two',HttpReply(200,'hello'#13#10'world'));
  R:=EuoHttpRun(Req('GET','/a?x=1&y=two'));
  AssertEquals('OK',R.Res);
  AssertEquals(200,R.Code);
  AssertEquals('hello'#13#10'world',R.Reply);
  Raw:=Srv.Request(0);
  AssertEquals('GET /a?x=1&y=two HTTP/1.1',FirstLine(Raw));
  AssertEquals('127.0.0.1:'+IntToStr(Srv.Port),HeaderValue(Raw,'Host'));
  AssertEquals(EUO_HTTP_AGENT,HeaderValue(Raw,'User-Agent'));
  AssertFalse('no body, no type',HasHeader(Raw,'Content-Type'));
end;

procedure TEuoHttpTests.TestPostBodyAndDefaultContentType;
var
  R   : TEuoHttpResult;
  Raw : String;
begin
  Srv.Route('/form',HttpReply(200,'ok'));
  R:=EuoHttpRun(Req('POST','/form','name=Bob&text=hi%20there'));
  AssertEquals('OK',R.Res);
  AssertEquals('ok',R.Reply);
  Raw:=Srv.Request(0);
  AssertEquals('POST /form HTTP/1.1',FirstLine(Raw));
  AssertEquals('name=Bob&text=hi%20there',BodyOf(Raw));
  AssertEquals('24',HeaderValue(Raw,'Content-Length'));
  AssertEquals(EUO_HTTP_FORM_TYPE,HeaderValue(Raw,'Content-Type'));
end;

procedure TEuoHttpTests.TestSendHeaderOverridesTypeAndAgent;
var
  Raw : String;
begin
  Srv.Route('/hook',HttpReply(204,''));
  AssertEquals(204,EuoHttpRun(Req('POST','/hook','{"content":"hi"}',
    'Content-Type: application/json$User-Agent: Bot/1$X-Key: k1$N/A')).Code);
  Raw:=Srv.Request(0);
  AssertEquals('application/json',HeaderValue(Raw,'Content-Type'));
  AssertEquals('Bot/1',HeaderValue(Raw,'User-Agent'));
  AssertEquals('k1',HeaderValue(Raw,'X-Key'));
  AssertEquals('{"content":"hi"}',BodyOf(Raw));
  AssertFalse('a line without a colon is left out',Pos('N/A',HeadOf(Raw))>0);
end;

procedure TEuoHttpTests.TestPutAndDelete;
begin
  Srv.Route('/item/5',HttpReply(200,'done'));
  AssertEquals('done',EuoHttpRun(Req('PUT','/item/5','qty=3')).Reply);
  AssertEquals('PUT /item/5 HTTP/1.1',FirstLine(Srv.Request(0)));
  AssertEquals('qty=3',BodyOf(Srv.Request(0)));
  AssertEquals('done',EuoHttpRun(Req('DELETE','/item/5')).Reply);
  AssertEquals('DELETE /item/5 HTTP/1.1',FirstLine(Srv.Request(1)));
  AssertFalse(HasHeader(Srv.Request(1),'Content-Type'));
end;

procedure TEuoHttpTests.TestAnErrorStatusIsStillAnAnswer;
var
  R : TEuoHttpResult;
begin
  R:=EuoHttpRun(Req('GET','/missing'));
  AssertEquals('the server answered','OK',R.Res);
  AssertEquals(404,R.Code);
  AssertEquals('no route /missing',R.Reply);
  Srv.Route('/boom',HttpReply(500,'oops'));
  R:=EuoHttpRun(Req('GET','/boom'));
  AssertEquals('OK',R.Res);
  AssertEquals(500,R.Code);
end;

procedure TEuoHttpTests.TestRedirectIsFollowed;
var
  R : TEuoHttpResult;
begin
  Srv.Route('/old',HttpReply(302,'','Location: /new'+CRLF));
  Srv.Route('/new',HttpReply(200,'moved here'));
  R:=EuoHttpRun(Req('GET','/old'));
  AssertEquals('OK',R.Res);
  AssertEquals(200,R.Code);
  AssertEquals('moved here',R.Reply);
  AssertEquals(2,Srv.RequestCount);
end;

procedure TEuoHttpTests.TestRefusedPort;
var
  S : TSocket;
  A : TSockAddrIn;
  L : Integer;
  P : Word;
  Q : TEuoHttpRequest;
  R : TEuoHttpResult;
begin
  // A port nobody listens on: bound, read, closed.
  S:=socket(AF_INET,SOCK_STREAM,0);
  FillChar(A,SizeOf(A),0);
  A.sin_family:=AF_INET;
  A.sin_addr.s_addr:=inet_addr('127.0.0.1');
  bind(S,PSockAddr(@A),SizeOf(A));
  L:=SizeOf(A);
  ws_getsockname(S,A,L);
  P:=ntohs(A.sin_port);
  closesocket(S);
  Q:=Req('GET','/');
  Q.Url:='http://127.0.0.1:'+IntToStr(P)+'/';
  R:=EuoHttpRun(Q);
  AssertEquals('cannot connect to 127.0.0.1',R.Res);
  AssertEquals(0,R.Code);
  AssertEquals('',R.Reply);
end;

procedure TEuoHttpTests.TestUnresolvableHost;
var
  Q : TEuoHttpRequest;
  R : TEuoHttpResult;
begin
  Q:=Req('GET','/');
  Q.Url:='http://euo-selftest.invalid/x';
  R:=EuoHttpRun(Q);
  AssertEquals('cannot resolve euo-selftest.invalid',R.Res);
  AssertEquals(0,R.Code);
end;

procedure TEuoHttpTests.TestBadUrls;
const
  Bad : array[0..4] of String = ('ftp://example.com/x','example.com/x','http://','https:/x','');
var
  Q : TEuoHttpRequest;
  i : Integer;
begin
  for i:=Low(Bad) to High(Bad) do
  begin
    Q:=Req('GET','/');
    Q.Url:=Bad[i];
    AssertEquals(Bad[i],'bad url: '+Bad[i],EuoHttpRun(Q).Res);
  end;
  AssertEquals('nothing was sent',0,Srv.RequestCount);
end;

procedure TEuoHttpTests.TestReplyOverOneMegabyte;
var
  R : TEuoHttpResult;
begin
  Srv.Route('/max',HttpReply(200,StringOfChar('x',EUO_HTTP_MAX_REPLY)));
  Srv.Route('/big',HttpReply(200,StringOfChar('x',EUO_HTTP_MAX_REPLY+1)));
  R:=EuoHttpRun(Req('GET','/max'));
  AssertEquals('OK',R.Res);
  AssertEquals(EUO_HTTP_MAX_REPLY,Length(R.Reply));
  R:=EuoHttpRun(Req('GET','/big'));
  AssertEquals('reply over 1 MB: use send download',R.Res);
  AssertEquals(200,R.Code);
  AssertEquals('',R.Reply);
end;

procedure TEuoHttpTests.TestDownloadWritesTheFile;
var
  Q    : TEuoHttpRequest;
  R    : TEuoHttpResult;
  Data : String;
begin
  Data:='bytes'#0#1#255#13#10+StringOfChar('z',EUO_HTTP_MAX_REPLY+10);
  Srv.Route('/f.bin',HttpReply(200,Data));
  WriteFile(Dir+'f.bin','old');
  Q:=Req('GET','/f.bin');
  Q.SaveTo:=Dir+'f.bin';
  R:=EuoHttpRun(Q);
  AssertEquals('OK',R.Res);
  AssertEquals(200,R.Code);
  AssertEquals('a download keeps nothing in the reply','',R.Reply);
  AssertTrue('the file is the body, byte for byte',ReadFile(Dir+'f.bin')=Data);
  AssertFalse('no .part left',FileExists(Dir+'f.bin'+EUO_HTTP_PART));
  Q.SaveTo:=Dir+'sub\deeper\g.bin';
  AssertEquals('folders are made','OK',EuoHttpRun(Q).Res);
  AssertTrue(ReadFile(Dir+'sub\deeper\g.bin')=Data);
  DeleteFile(Dir+'sub\deeper\g.bin');
  RemoveDir(Dir+'sub\deeper');
  RemoveDir(Dir+'sub');
end;

procedure TEuoHttpTests.TestRefusedDownloadKeepsTheOldFile;
var
  Q : TEuoHttpRequest;
  R : TEuoHttpResult;
begin
  WriteFile(Dir+'keep.euo','set %v 1');
  Q:=Req('GET','/gone.euo');
  Q.SaveTo:=Dir+'keep.euo';
  R:=EuoHttpRun(Q);
  AssertEquals('not saved: the server answered 404',R.Res);
  AssertEquals(404,R.Code);
  AssertEquals('the error page','no route /gone.euo',R.Reply);
  AssertEquals('set %v 1',ReadFile(Dir+'keep.euo'));
  AssertFalse(FileExists(Dir+'keep.euo'+EUO_HTTP_PART));
end;

procedure TEuoHttpTests.TestTimeout;
var
  Q : TEuoHttpRequest;
  R : TEuoHttpResult;
  T : QWord;
begin
  Srv.Route('/slow','');
  Q:=Req('GET','/slow');
  Q.Timeout:=500;
  T:=GetTickCount64;
  R:=EuoHttpRun(Q);
  AssertEquals('timeout',R.Res);
  AssertEquals(0,R.Code);
  AssertTrue('gave up in time',GetTickCount64-T<4000);
end;

procedure TEuoHttpTests.TestCancelEndsTheRequest;
var
  Job : IEuoHttpJob;
  T   : QWord;
begin
  Srv.Route('/slow','');
  Job:=StartEuoHttp(Req('GET','/slow'));
  AssertTrue('the request arrived',WaitUntil(GotRequest,3000));
  AssertFalse(Job.Done);
  T:=GetTickCount64;
  Job.Cancel;
  while (not Job.Done) and (GetTickCount64-T<2000) do Sleep(5);
  AssertTrue('Cancel ended the blocked call',Job.Done);
  AssertEquals('stopped',Job.Outcome.Res);
  AssertTrue('and closed the connection',WaitUntil(Srv.HangEnded,2000));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHttpTests.TestScriptGetSetsTheVariables;
begin
  Srv.Route('/v',HttpReply(200,'1.2.3'));
  Play(['send get '+Url('/v'),'halt']);
  AssertEquals('OK',Interp.GetVar('#SendRes'));
  AssertEquals('200',Interp.GetVar('#SendCode'));
  AssertEquals('1.2.3',Interp.GetVar('#SendReply'));
  Play(['send GET '+Url('/nope'),'halt']);
  AssertEquals('OK',Interp.GetVar('#SendRes'));
  AssertEquals('404',Interp.GetVar('#SendCode'));
  AssertEquals('no route /nope',Interp.GetVar('#SendReply'));
end;

procedure TEuoHttpTests.TestScriptPostTakesTheRestOfTheLine;
begin
  Srv.Route('/p',HttpReply(201,'made'));
  Play(['set %n Bob','send post '+Url('/p')+' name= , %n , &x=1   two  words','halt']);
  AssertEquals('201',Interp.GetVar('#SendCode'));
  AssertEquals('name=Bob&x=1 two words',BodyOf(Srv.Request(0)));
  Play(['send put '+Url('/p')+' {"a":1}','halt']);
  AssertEquals('PUT /p HTTP/1.1',FirstLine(Srv.Request(1)));
  AssertEquals('{"a":1}',BodyOf(Srv.Request(1)));
  Play(['send delete '+Url('/p'),'halt']);
  AssertEquals('DELETE /p HTTP/1.1',FirstLine(Srv.Request(2)));
  AssertEquals('',BodyOf(Srv.Request(2)));
  Play(['send post '+Url('/p'),'halt']);
  AssertEquals('a post with no data','POST /p HTTP/1.1',FirstLine(Srv.Request(3)));
end;

procedure TEuoHttpTests.TestScriptWordErrors;

  procedure Check(const Line, Res : String);
  begin
    Play([Line,'halt']);
    AssertEquals(Line,Res,Interp.GetVar('#SendRes'));
    AssertEquals(Line,'0',Interp.GetVar('#SendCode'));
    AssertEquals(Line,'',Interp.GetVar('#SendReply'));
  end;

begin
  Check('send get','no url given: send get {url}');
  Check('send download','no url given: send download {url}');
  Check('send get '+Url('/v')+' a=1','get takes only a url: put the data in its query (?name=value)');
  Check('send download '+Url('/v'),'no file given: send download {url} {file}');
  Check('send download '+Url('/v')+' my file.txt','download takes one file name: glue a name that has spaces with ,');
  Check('send get nohost/x','bad url: nohost/x');
  AssertEquals('none of them reached the server',0,Srv.RequestCount);
  Interp.Clear;
  Play(['send gett '+Url('/v'),'send','send nonsense a b c d','halt']);
  AssertEquals('another word does nothing','N/A',Interp.GetVar('#SendRes'));
  AssertEquals(0,Srv.RequestCount);
end;

procedure TEuoHttpTests.TestScriptVariablesAreNAUntilASendAndAfterClear;
begin
  AssertEquals('N/A',Interp.GetVar('#SendRes'));
  AssertEquals('N/A',Interp.GetVar('#SendCode'));
  AssertEquals('N/A',Interp.GetVar('#SendReply'));
  Srv.Route('/v',HttpReply(200,'x'));
  Play(['send get '+Url('/v'),'halt']);
  AssertEquals('OK',Interp.GetVar('#SendRes'));
  Interp.Clear;
  AssertEquals('N/A',Interp.GetVar('#SendRes'));
  AssertEquals('N/A',Interp.GetVar('#SendCode'));
  AssertEquals('N/A',Interp.GetVar('#SendReply'));
end;

procedure TEuoHttpTests.TestScriptDownload;
begin
  Srv.Route('/s.euo',HttpReply(200,'set %got 7'+CRLF));
  Play(['send download '+Url('/s.euo')+' '+Dir+'s.euo','call '+Dir+'s.euo','halt']);
  AssertEquals('OK',Interp.GetVar('#SendRes'));
  AssertEquals('200',Interp.GetVar('#SendCode'));
  AssertEquals('',Interp.GetVar('#SendReply'));
  AssertEquals('the downloaded script ran with call','7',Interp.GetVar('%got'));
end;

procedure TEuoHttpTests.TestScriptDownloadIsConfined;
begin
  Srv.Route('/s.euo',HttpReply(200,'x'));
  Interp.ConfineFiles:=True;
  Play(['send download '+Url('/s.euo')+' ..\up.euo','halt']);
  AssertEquals('outside the program folder: ..\up.euo',Interp.GetVar('#SendRes'));
  Play(['send download '+Url('/s.euo')+' '+Dir+'abs.euo','halt']);
  AssertEquals('outside the program folder: '+Dir+'abs.euo',Interp.GetVar('#SendRes'));
  AssertEquals('0',Interp.GetVar('#SendCode'));
  AssertEquals(0,Srv.RequestCount);
  AssertFalse(FileExists(Dir+'abs.euo'));
end;

procedure TEuoHttpTests.TestScriptStrUrlEncodeAndJsonEscape;
begin
  Play(['set %t a , #spc , b&c','str urlencode %t','set %u #strres','halt']);
  AssertEquals('a%20b%26c',Interp.GetVar('%u'));
  Play(['set %t say , #spc , "hi"','str jsonescape %t','set %j #strres','halt']);
  AssertEquals('say \"hi\"',Interp.GetVar('%j'));
end;

procedure TEuoHttpTests.TestStopDuringASendLeavesTheVariables;
var
  Ex : TExecutor;
  T  : QWord;
begin
  Srv.Route('/slow','');
  Ex:=TExecutor.Create(0);
  try
    T:=GetTickCount64;
    while (not Ex.Paused) and (GetTickCount64-T<3000) do Sleep(5);
    Ex.LoadScript('send get '+Url('/slow')+CRLF+'set %after 1'+CRLF+'halt'+CRLF);
    Ex.State:=EuoExecutor.PLAY;
    AssertTrue('the request arrived',WaitUntil(GotRequest,3000));
    Sleep(100);
    AssertEquals('the GUI can read variables meanwhile','N/A',Ex.GetVar('#SendRes'));
    T:=GetTickCount64;
    Ex.State:=EuoExecutor.STOP;
    while (not Ex.Paused) and (GetTickCount64-T<5000) do Sleep(5);
    AssertTrue('the script left the send',Ex.Paused);
    AssertTrue('at once',GetTickCount64-T<1500);
    AssertEquals('N/A',Ex.GetVar('%after'));
    AssertEquals('a stopped send reports nothing','N/A',Ex.GetVar('#SendRes'));
    AssertTrue('the request was cancelled',WaitUntil(Srv.HangEnded,3000));
  finally
    Ex.Free;
  end;
end;

// The original form is frozen: these are its exact bytes, the blank line it puts before the data
// when #SendHeader is empty included. Its reply runs as a script, and it sets none of the new
// variables.
procedure TEuoHttpTests.TestOriginalFormIsByteForByte;
begin
  Srv.Route('/p','HTTP/1.0 200 OK'+CRLF+CRLF+'set %r 5');
  Play(['send httppost'+IntToStr(Srv.Port)+' 127.0.0.1 /p a=1','set %after 1','halt']);
  AssertEquals(1,Srv.RequestCount);
  AssertEquals('POST /p HTTP/1.0'+CRLF+'Host: 127.0.0.1'+CRLF+'Content-Length: 3'+CRLF+CRLF+CRLF+'a=1',
    Srv.Request(0));
  AssertEquals('the reply ran','5',Interp.GetVar('%r'));
  AssertEquals('and the script went on after it','1',Interp.GetVar('%after'));
  AssertEquals('N/A',Interp.GetVar('#SendRes'));
  AssertEquals('N/A',Interp.GetVar('#SendCode'));
  AssertEquals('N/A',Interp.GetVar('#SendReply'));
end;

procedure TEuoHttpTests.TestOriginalFormWithSendHeader;
begin
  Srv.Route('/p','HTTP/1.0 200 OK'+CRLF+CRLF+'set %r 6');
  Play(['set #SendHeader X-A: , #spc , 1$','send httppost'+IntToStr(Srv.Port)+' 127.0.0.1 /p a=1 b','halt']);
  AssertEquals('POST /p HTTP/1.0'+CRLF+'Host: 127.0.0.1'+CRLF+'Content-Length: 5'+CRLF+'X-A: 1'+CRLF+CRLF+'a=1 b',
    Srv.Request(0));
  AssertEquals('6',Interp.GetVar('%r'));
  AssertEquals('N/A',Interp.GetVar('#SendRes'));
end;

var
  WSData : TWSAData;

initialization
  WSAStartup($0202,WSData);
  RegisterTest(TEuoHttpTests);
finalization
  WSACleanup;
end.
