unit EuoHttp;

{
  Port addition (SEND GET, POST, PUT, DELETE, DOWNLOAD): the HTTP client behind the new forms of
  SEND. The original form, SEND HTTPPOST, keeps its own raw WinSock client (EuoComm.pas, unchanged)
  and its reply still runs as a script; nothing here is used by it.

  Built on WinHTTP, which every Windows has: https through Windows' own TLS (nothing to ship),
  redirects followed (never from https to http, WinHTTP's default rule), the proxy set for WinHTTP
  (netsh winhttp set proxy) and not the browser's: automatic proxy detection can add seconds to
  every request on a network without one. FPC 3.2.2's winhttp unit imports WinHttpSetTimeouts
  under a name winhttp.dll does not have (WinHttpSetTimes) and mangles some error constants, so the
  calls needed are declared here.

  - TEuoHttpRequest / TEuoHttpResult: what SEND passes in, and what it puts in #SendRes, #SendCode
    and #SendReply. Res is EUO_HTTP_OK when the server answered, whatever the status, otherwise the
    reason in words; Code is the HTTP status, 0 when no answer came.
  - SendHeaderLines: #SendHeader's lines, split at '$' as EuoComm does, each trimmed. A line without
    a ':' after its name is left out, so 'N/A', EasyUO's "nothing", sends nothing. A User-Agent line
    replaces EUO_HTTP_AGENT; without a Content-Type line a body goes out as EUO_HTTP_FORM_TYPE.
  - EuoHttpRun: one request, synchronously, in the calling thread (tests).
  - StartEuoHttp: the same on a thread of its own, as a reference-counted job. The interpreter waits
    for Done through Delay, so Stop and Pause work and the script lock is free meanwhile. Cancel
    (Stop) closes the request handle, which ends WinHTTP's blocking call, and the interpreter leaves
    without waiting: the thread finishes on its own, deletes a half-written download, and frees
    itself and the job.
  - A download (SaveTo set) writes the body to SaveTo + EUO_HTTP_PART, which replaces SaveTo only
    after a 2xx status and a complete read; otherwise SaveTo is left as it was, and Reply holds the
    start of what the server sent instead (its error page). A reply kept in Reply is capped at
    EUO_HTTP_MAX_REPLY bytes; a download is not.

  Bytes go out and come back as they are: the body is the script's text, the reply is kept byte
  for byte. The URL and the header lines are read as UTF-8, as the editor writes scripts.
  No LCL, no client, no interpreter.
}

{$mode delphi}{$H+}

interface

uses
  Windows, SysUtils, Classes, SyncObjs;

const
  EUO_HTTP_OK        = 'OK';
  EUO_HTTP_MAX_REPLY = 1024*1024;     // bytes a reply may have when it goes into #SendReply
  EUO_HTTP_TIMEOUT   = 30000;         // ms each step may take: resolve, connect, send, each read
  EUO_HTTP_AGENT     = 'EasyUO Reforged';
  EUO_HTTP_FORM_TYPE = 'application/x-www-form-urlencoded';
  EUO_HTTP_PART      = '.part';       // a download is written here first

type
  TEuoHttpRequest = record
    Method  : String;    // GET, POST, PUT or DELETE (a download is a GET with SaveTo set)
    Url     : String;    // http:// or https://
    Headers : String;    // #SendHeader as the script set it
    Body    : String;    // '' sends none
    SaveTo  : String;    // the full path a download writes; '' keeps the reply in Reply
    Timeout : Integer;   // ms per step; 0 = EUO_HTTP_TIMEOUT
  end;

  TEuoHttpResult = record
    Res   : String;      // EUO_HTTP_OK, or why not
    Code  : Integer;     // the HTTP status, 0 when no answer came
    Reply : String;      // the body, byte for byte ('' for a saved download)
  end;

  IEuoHttpJob = interface
    ['{6B1E2C4A-9F3D-4E7B-A2C5-1D8F0E3B7A64}']
    function  Done : Boolean;
    function  Outcome : TEuoHttpResult;   // meaningful once Done
    procedure Cancel;
  end;

procedure SendHeaderLines(const Raw : String; Lines : TStrings);
function  EuoHttpRun(const Req : TEuoHttpRequest) : TEuoHttpResult;
function  StartEuoHttp(const Req : TEuoHttpRequest) : IEuoHttpJob;

implementation

////////////////////////////////////////////////////////////////////////////////
// WinHTTP, as much of it as is used.
type
  HINTERNET = Pointer;

  TUrlComponents = record
    dwStructSize      : DWORD;
    lpszScheme        : PWideChar;
    dwSchemeLength    : DWORD;
    nScheme           : Integer;
    lpszHostName      : PWideChar;
    dwHostNameLength  : DWORD;
    nPort             : Word;
    lpszUserName      : PWideChar;
    dwUserNameLength  : DWORD;
    lpszPassword      : PWideChar;
    dwPasswordLength  : DWORD;
    lpszUrlPath       : PWideChar;
    dwUrlPathLength   : DWORD;
    lpszExtraInfo     : PWideChar;
    dwExtraInfoLength : DWORD;
  end;

const
  WINHTTP_DLL = 'winhttp.dll';

  WINHTTP_ACCESS_TYPE_DEFAULT_PROXY   = 0;
  WINHTTP_FLAG_SECURE                 = $00800000;
  INTERNET_SCHEME_HTTPS               = 2;
  WINHTTP_QUERY_STATUS_CODE           = 19;
  WINHTTP_QUERY_FLAG_NUMBER           = $20000000;
  WINHTTP_OPTION_SECURE_PROTOCOLS     = 84;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 = $00000800;
  WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3 = $00002000;

  ERROR_WINHTTP_TIMEOUT                 = 12002;
  ERROR_WINHTTP_INVALID_URL             = 12005;
  ERROR_WINHTTP_UNRECOGNIZED_SCHEME     = 12006;
  ERROR_WINHTTP_NAME_NOT_RESOLVED       = 12007;
  ERROR_WINHTTP_OPERATION_CANCELLED     = 12017;
  ERROR_WINHTTP_CANNOT_CONNECT          = 12029;
  ERROR_WINHTTP_CONNECTION_ERROR        = 12030;
  ERROR_WINHTTP_SECURE_CERT_DATE_INVALID= 12037;
  ERROR_WINHTTP_SECURE_CERT_CN_INVALID  = 12038;
  ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED = 12044;
  ERROR_WINHTTP_SECURE_INVALID_CA       = 12045;
  ERROR_WINHTTP_SECURE_CERT_REV_FAILED  = 12057;
  ERROR_WINHTTP_INVALID_SERVER_RESPONSE = 12152;
  ERROR_WINHTTP_INVALID_HEADER          = 12153;
  ERROR_WINHTTP_REDIRECT_FAILED         = 12156;
  ERROR_WINHTTP_SECURE_CHANNEL_ERROR    = 12157;
  ERROR_WINHTTP_SECURE_INVALID_CERT     = 12169;
  ERROR_WINHTTP_SECURE_CERT_REVOKED     = 12170;
  ERROR_WINHTTP_SECURE_FAILURE          = 12175;
  ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE = 12179;

function WinHttpOpen(pszAgent : PWideChar; dwAccessType : DWORD; pszProxy, pszProxyBypass : PWideChar;
  dwFlags : DWORD) : HINTERNET; stdcall; external WINHTTP_DLL name 'WinHttpOpen';
function WinHttpCloseHandle(h : HINTERNET) : BOOL; stdcall; external WINHTTP_DLL name 'WinHttpCloseHandle';
function WinHttpCrackUrl(pwszUrl : PWideChar; dwUrlLength, dwFlags : DWORD;
  var Components : TUrlComponents) : BOOL; stdcall; external WINHTTP_DLL name 'WinHttpCrackUrl';
function WinHttpConnect(hSession : HINTERNET; pswzServerName : PWideChar; nServerPort : Word;
  dwReserved : DWORD) : HINTERNET; stdcall; external WINHTTP_DLL name 'WinHttpConnect';
function WinHttpOpenRequest(hConnect : HINTERNET; pwszVerb, pwszObjectName, pwszVersion, pwszReferrer : PWideChar;
  ppwszAcceptTypes : Pointer; dwFlags : DWORD) : HINTERNET; stdcall; external WINHTTP_DLL name 'WinHttpOpenRequest';
function WinHttpSetTimeouts(h : HINTERNET; nResolve, nConnect, nSend, nReceive : Integer) : BOOL; stdcall;
  external WINHTTP_DLL name 'WinHttpSetTimeouts';
function WinHttpSetOption(h : HINTERNET; dwOption : DWORD; lpBuffer : Pointer; dwBufferLength : DWORD) : BOOL;
  stdcall; external WINHTTP_DLL name 'WinHttpSetOption';
function WinHttpSendRequest(hRequest : HINTERNET; lpszHeaders : PWideChar; dwHeadersLength : DWORD;
  lpOptional : Pointer; dwOptionalLength, dwTotalLength : DWORD; dwContext : PtrUInt) : BOOL; stdcall;
  external WINHTTP_DLL name 'WinHttpSendRequest';
function WinHttpReceiveResponse(hRequest : HINTERNET; lpReserved : Pointer) : BOOL; stdcall;
  external WINHTTP_DLL name 'WinHttpReceiveResponse';
function WinHttpQueryHeaders(hRequest : HINTERNET; dwInfoLevel : DWORD; pwszName : PWideChar; lpBuffer : Pointer;
  var dwBufferLength : DWORD; lpdwIndex : PDWORD) : BOOL; stdcall; external WINHTTP_DLL name 'WinHttpQueryHeaders';
function WinHttpReadData(hRequest : HINTERNET; lpBuffer : Pointer; dwNumberOfBytesToRead : DWORD;
  var dwNumberOfBytesRead : DWORD) : BOOL; stdcall; external WINHTTP_DLL name 'WinHttpReadData';

////////////////////////////////////////////////////////////////////////////////
type
  TEuoHttpJob = class(TInterfacedObject, IEuoHttpJob)
  private
    FReq       : TEuoHttpRequest;
    FOut       : TEuoHttpResult;
    FLock      : TCriticalSection;
    FDone      : Boolean;
    FCancelled : Boolean;
    FRequest   : HINTERNET;   // the open request handle, nil when none (under FLock)
    function  KeepRequest(H : HINTERNET) : Boolean;
    procedure DropRequest;
    function  Cancelled : Boolean;
    procedure DoRequest(var R : TEuoHttpResult);
  public
    constructor Create(const Req : TEuoHttpRequest);
    destructor  Destroy; override;
    procedure Run;
    function  Done : Boolean;
    function  Outcome : TEuoHttpResult;
    procedure Cancel;
  end;

  TEuoHttpThread = class(TThread)
  private
    FRef : IEuoHttpJob;    // keeps the job alive while the thread runs
    FJob : TEuoHttpJob;
  protected
    procedure Execute; override;
  public
    constructor Create(Job : TEuoHttpJob);
  end;

////////////////////////////////////////////////////////////////////////////////
procedure SendHeaderLines(const Raw : String; Lines : TStrings);
var
  s    : String;
  Line : String;
  i    : Integer;
begin
  Lines.Clear;
  s:=Raw+'$';
  repeat
    i:=Pos('$',s);
    if i<1 then Break;
    Line:=Trim(Copy(s,1,i-1));
    Delete(s,1,i);
    if Pos(':',Line)>1 then Lines.Add(Line);
  until False;
end;

////////////////////////////////////////////////////////////////////////////////
// Windows' own text for a WinHTTP error (its messages live in winhttp.dll), as UTF-8.
function WinHttpErrorText(Code : DWORD) : String;
var
  Buf : array[0..511] of WideChar;
  N   : DWORD;
  WS  : UnicodeString;
begin
  N:=FormatMessageW(FORMAT_MESSAGE_FROM_HMODULE or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    Pointer(GetModuleHandle(WINHTTP_DLL)),Code,0,@Buf[0],Length(Buf),nil);
  Result:='';
  if N>0 then
  begin
    SetString(WS,PWideChar(@Buf[0]),N);
    Result:=Trim(UTF8Encode(WS));
  end;
  if Result='' then Result:='no text for this error';
end;

////////////////////////////////////////////////////////////////////////////////
// What #SendRes says when a WinHTTP call failed with Code.
function FailText(Code : DWORD; const Host, Url : String) : String;
begin
  case Code of
    ERROR_WINHTTP_NAME_NOT_RESOLVED       : Result:='cannot resolve '+Host;
    ERROR_WINHTTP_CANNOT_CONNECT          : Result:='cannot connect to '+Host;
    ERROR_WINHTTP_TIMEOUT                 : Result:='timeout';
    ERROR_WINHTTP_CONNECTION_ERROR        : Result:='connection lost';
    ERROR_WINHTTP_INVALID_SERVER_RESPONSE : Result:='not an HTTP reply';
    ERROR_WINHTTP_REDIRECT_FAILED         : Result:='redirect refused';
    ERROR_WINHTTP_INVALID_HEADER          : Result:='bad line in #SendHeader';
    ERROR_WINHTTP_OPERATION_CANCELLED,
    ERROR_INVALID_HANDLE                  : Result:='stopped';
    ERROR_WINHTTP_INVALID_URL,
    ERROR_WINHTTP_UNRECOGNIZED_SCHEME     : Result:='bad url: '+Url;
    ERROR_WINHTTP_SECURE_CERT_DATE_INVALID,
    ERROR_WINHTTP_SECURE_CERT_CN_INVALID,
    ERROR_WINHTTP_CLIENT_AUTH_CERT_NEEDED,
    ERROR_WINHTTP_SECURE_INVALID_CA,
    ERROR_WINHTTP_SECURE_CERT_REV_FAILED,
    ERROR_WINHTTP_SECURE_CHANNEL_ERROR,
    ERROR_WINHTTP_SECURE_INVALID_CERT,
    ERROR_WINHTTP_SECURE_CERT_REVOKED,
    ERROR_WINHTTP_SECURE_FAILURE,
    ERROR_WINHTTP_SECURE_CERT_WRONG_USAGE : Result:='secure connection failed: '+WinHttpErrorText(Code);
  else
    Result:='error '+IntToStr(Code)+': '+WinHttpErrorText(Code);
  end;
end;

function LastErrorText : String;
begin
  Result:=Trim(SysErrorMessage(GetLastError));
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoHttpJob.Create(const Req : TEuoHttpRequest);
begin
  inherited Create;
  FReq:=Req;
  FLock:=TCriticalSection.Create;
  FOut.Res:='';
  FOut.Code:=0;
  FOut.Reply:='';
end;

destructor TEuoHttpJob.Destroy;
begin
  DropRequest;
  FLock.Free;
  inherited Destroy;
end;

function TEuoHttpJob.Done : Boolean;
begin
  FLock.Acquire;
  try
    Result:=FDone;
  finally
    FLock.Release;
  end;
end;

function TEuoHttpJob.Outcome : TEuoHttpResult;
begin
  FLock.Acquire;
  try
    Result:=FOut;
  finally
    FLock.Release;
  end;
end;

function TEuoHttpJob.Cancelled : Boolean;
begin
  FLock.Acquire;
  try
    Result:=FCancelled;
  finally
    FLock.Release;
  end;
end;

procedure TEuoHttpJob.Cancel;
begin
  FLock.Acquire;
  try
    FCancelled:=True;
    if FRequest<>nil then WinHttpCloseHandle(FRequest);   // ends the call blocked on it
    FRequest:=nil;
  finally
    FLock.Release;
  end;
end;

// False (and H closed) when the job was cancelled before the request existed.
function TEuoHttpJob.KeepRequest(H : HINTERNET) : Boolean;
begin
  FLock.Acquire;
  try
    Result:=not FCancelled;
    if Result then FRequest:=H
    else WinHttpCloseHandle(H);
  finally
    FLock.Release;
  end;
end;

procedure TEuoHttpJob.DropRequest;
begin
  FLock.Acquire;
  try
    if FRequest<>nil then WinHttpCloseHandle(FRequest);
    FRequest:=nil;
  finally
    FLock.Release;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHttpJob.Run;
var
  R : TEuoHttpResult;
begin
  R.Res:='';
  R.Code:=0;
  R.Reply:='';
  try
    DoRequest(R);
  except
    on E : Exception do
    begin
      R.Res:='error: '+E.Message;
      R.Reply:='';
    end;
  end;
  if R.Res='' then R.Res:=EUO_HTTP_OK;
  FLock.Acquire;
  try
    FOut:=R;
    FDone:=True;
  finally
    FLock.Release;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoHttpJob.DoRequest(var R : TEuoHttpResult);
var
  Url      : UnicodeString;
  HostW    : UnicodeString;
  PathW    : UnicodeString;
  ExtraW   : UnicodeString;
  HeadW    : UnicodeString;
  Host     : String;
  Parts    : TUrlComponents;
  Lines    : TStringList;
  Agent    : String;
  HeadText : String;
  Name     : String;
  HasType  : Boolean;
  Session  : HINTERNET;
  Connect  : HINTERNET;
  Request  : HINTERNET;
  Timeout  : Integer;
  Proto    : DWORD;
  Status   : DWORD;
  Len      : DWORD;
  Got      : DWORD;
  Total    : Int64;
  Buf      : array of Byte;
  Saving   : Boolean;
  PartFile : String;
  Dir      : String;
  Stream   : THandleStream;
  FileH    : THandle;
  Sent     : BOOL;
  Complete : Boolean;
  Lower    : String;
  i        : Integer;
  Flags    : DWORD;

  procedure Fail;
  begin
    R.Res:=FailText(GetLastError,Host,FReq.Url);
  end;

  procedure CloseStream;
  begin
    if Stream=nil then Exit;
    CloseHandle(Stream.Handle);
    FreeAndNil(Stream);
  end;

begin
  Lower:=LowerCase(FReq.Url);
  if (Copy(Lower,1,7)<>'http://') and (Copy(Lower,1,8)<>'https://') then
  begin
    R.Res:='bad url: '+FReq.Url;
    Exit;
  end;

  Url:=UTF8Decode(FReq.Url);
  FillChar(Parts,SizeOf(Parts),0);
  Parts.dwStructSize:=SizeOf(Parts);
  Parts.dwSchemeLength:=$FFFFFFFF;
  Parts.dwHostNameLength:=$FFFFFFFF;
  Parts.dwUrlPathLength:=$FFFFFFFF;
  Parts.dwExtraInfoLength:=$FFFFFFFF;
  if (not WinHttpCrackUrl(PWideChar(Url),Length(Url),0,Parts)) or (Parts.dwHostNameLength=0) then
  begin
    R.Res:='bad url: '+FReq.Url;
    Exit;
  end;
  SetString(HostW,Parts.lpszHostName,Parts.dwHostNameLength);
  SetString(PathW,Parts.lpszUrlPath,Parts.dwUrlPathLength);
  if Parts.dwExtraInfoLength>0 then
  begin
    SetString(ExtraW,Parts.lpszExtraInfo,Parts.dwExtraInfoLength);
    PathW:=PathW+ExtraW;
  end;
  if PathW='' then PathW:='/';
  Host:=UTF8Encode(HostW);

  Agent:=EUO_HTTP_AGENT;
  HeadText:='';
  HasType:=False;
  Lines:=TStringList.Create;
  try
    SendHeaderLines(FReq.Headers,Lines);
    for i:=0 to Lines.Count-1 do
    begin
      Name:=LowerCase(Trim(Copy(Lines[i],1,Pos(':',Lines[i])-1)));
      if Name='user-agent' then
      begin
        Agent:=Trim(Copy(Lines[i],Pos(':',Lines[i])+1,MaxInt));
        Continue;
      end;
      if Name='content-type' then HasType:=True;
      HeadText:=HeadText+Lines[i]+#13#10;
    end;
  finally
    Lines.Free;
  end;
  if (FReq.Body<>'') and not HasType then
    HeadText:=HeadText+'Content-Type: '+EUO_HTTP_FORM_TYPE+#13#10;
  HeadW:=UTF8Decode(HeadText);

  Timeout:=FReq.Timeout;
  if Timeout<=0 then Timeout:=EUO_HTTP_TIMEOUT;

  Session:=nil;
  Connect:=nil;
  Request:=nil;
  Stream:=nil;
  Saving:=False;
  Complete:=False;
  PartFile:='';
  try
    Session:=WinHttpOpen(PWideChar(UTF8Decode(Agent)),WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,nil,nil,0);
    if Session=nil then begin Fail; Exit; end;
    // TLS 1.2 and 1.3 where Windows has 1.3, 1.2 alone where it does not (older Windows had less).
    Proto:=WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2 or WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_3;
    if not WinHttpSetOption(Session,WINHTTP_OPTION_SECURE_PROTOCOLS,@Proto,SizeOf(Proto)) then
    begin
      Proto:=WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
      WinHttpSetOption(Session,WINHTTP_OPTION_SECURE_PROTOCOLS,@Proto,SizeOf(Proto));
    end;
    WinHttpSetTimeouts(Session,Timeout,Timeout,Timeout,Timeout);

    Connect:=WinHttpConnect(Session,PWideChar(HostW),Parts.nPort,0);
    if Connect=nil then begin Fail; Exit; end;

    Flags:=0;
    if Parts.nScheme=INTERNET_SCHEME_HTTPS then Flags:=WINHTTP_FLAG_SECURE;
    Request:=WinHttpOpenRequest(Connect,PWideChar(UTF8Decode(FReq.Method)),PWideChar(PathW),nil,nil,nil,Flags);
    if Request=nil then begin Fail; Exit; end;
    if not KeepRequest(Request) then
    begin
      Request:=nil;
      R.Res:='stopped';
      Exit;
    end;

    if HeadW<>'' then
      Sent:=WinHttpSendRequest(Request,PWideChar(HeadW),Length(HeadW),Pointer(FReq.Body),
        Length(FReq.Body),Length(FReq.Body),0)
    else
      Sent:=WinHttpSendRequest(Request,nil,0,Pointer(FReq.Body),Length(FReq.Body),Length(FReq.Body),0);
    if not Sent then begin Fail; Exit; end;
    if not WinHttpReceiveResponse(Request,nil) then begin Fail; Exit; end;

    Status:=0;
    Len:=SizeOf(Status);
    if not WinHttpQueryHeaders(Request,WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,nil,
      @Status,Len,nil) then begin Fail; Exit; end;
    R.Code:=Status;

    Saving:=(FReq.SaveTo<>'') and (Status>=200) and (Status<300);
    if Saving then
    begin
      Dir:=ExtractFileDir(FReq.SaveTo);
      if (Dir<>'') and not DirectoryExists(Dir) then
        if not ForceDirectories(Dir) then
        begin
          R.Res:='cannot create the folder '+Dir;
          Exit;
        end;
      FileH:=CreateFileW(PWideChar(UTF8Decode(FReq.SaveTo+EUO_HTTP_PART)),GENERIC_WRITE,FILE_SHARE_READ,nil,
        CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
      if FileH=INVALID_HANDLE_VALUE then
      begin
        R.Res:='cannot write '+FReq.SaveTo+': '+LastErrorText;
        Exit;
      end;
      PartFile:=FReq.SaveTo+EUO_HTTP_PART;
      Stream:=THandleStream.Create(FileH);
    end;

    SetLength(Buf,65536);
    Total:=0;
    repeat
      if Cancelled then
      begin
        R.Res:='stopped';
        Exit;
      end;
      Got:=0;
      if not WinHttpReadData(Request,@Buf[0],Length(Buf),Got) then begin Fail; Exit; end;
      if Got=0 then Break;
      if Saving then
        Stream.WriteBuffer(Buf[0],Got)
      else
      begin
        if Total+Got>EUO_HTTP_MAX_REPLY then
        begin
          if FReq.SaveTo='' then
          begin
            R.Reply:='';
            R.Res:='reply over 1 MB: use send download';
            Exit;
          end;
          // A refused download's error page: its first EUO_HTTP_MAX_REPLY bytes are enough.
          Got:=EUO_HTTP_MAX_REPLY-Total;
          SetLength(R.Reply,Total+Got);
          if Got>0 then Move(Buf[0],R.Reply[Total+1],Got);
          Break;
        end;
        SetLength(R.Reply,Total+Got);
        Move(Buf[0],R.Reply[Total+1],Got);
      end;
      Inc(Total,Got);
    until False;

    if FReq.SaveTo<>'' then
    begin
      if not Saving then
      begin
        R.Res:='not saved: the server answered '+IntToStr(Status);
        Exit;
      end;
      CloseStream;
      if Cancelled then
      begin
        R.Res:='stopped';
        Exit;
      end;
      if not MoveFileExW(PWideChar(UTF8Decode(PartFile)),PWideChar(UTF8Decode(FReq.SaveTo)),
        MOVEFILE_REPLACE_EXISTING or MOVEFILE_COPY_ALLOWED) then
      begin
        R.Res:='cannot write '+FReq.SaveTo+': '+LastErrorText;
        Exit;
      end;
      Complete:=True;
    end;
  finally
    CloseStream;
    if (PartFile<>'') and not Complete then DeleteFileW(PWideChar(UTF8Decode(PartFile)));
    if Request<>nil then DropRequest;
    if Connect<>nil then WinHttpCloseHandle(Connect);
    if Session<>nil then WinHttpCloseHandle(Session);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Created suspended: StartEuoHttp starts it and never touches it again, as it frees itself.
constructor TEuoHttpThread.Create(Job : TEuoHttpJob);
begin
  inherited Create(True);
  FJob:=Job;
  FRef:=Job;
  FreeOnTerminate:=True;
end;

procedure TEuoHttpThread.Execute;
begin
  try
    FJob.Run;
  finally
    FJob:=nil;
    FRef:=nil;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoHttpRun(const Req : TEuoHttpRequest) : TEuoHttpResult;
var
  Job : TEuoHttpJob;
  Ref : IEuoHttpJob;
begin
  Job:=TEuoHttpJob.Create(Req);
  Ref:=Job;      // owns the job: freed when Ref goes
  Job.Run;
  Result:=Ref.Outcome;
end;

function StartEuoHttp(const Req : TEuoHttpRequest) : IEuoHttpJob;
var
  Job : TEuoHttpJob;
begin
  Job:=TEuoHttpJob.Create(Req);
  Result:=Job;
  TEuoHttpThread.Create(Job).Start;
end;

end.
