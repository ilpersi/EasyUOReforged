unit EuoComm;

{
  Ported from the original Delphi 7 parser\comm.pas -- the raw WinSock HTTP/1.0
  client backing the SEND command. Synchronous/blocking, hand-built request, no
  TLS, exactly as the original. Windows-only either way (this whole app drives a
  Windows game client via WinAPI throughout), so staying on the raw WinSock API
  (rather than moving to a higher-level library) has no portability downside and
  keeps this a faithful, minimal port. Ported byte-for-byte; nothing needed to
  change (a first draft speculatively renamed several identifiers, reverted
  before compiling -- none were actually necessary). Compiles with two benign
  warnings, investigated and left as-is: "comparison might be always false" on
  S1=INVALID_SOCKET (FPC's TSocket is a plain longint matching S1's own type
  exactly, and the compared constant is the platform unit's own -- this looks
  like an overly-cautious static check, not a real runtime issue); and
  GetTickCount deprecation (unrelated pre-existing 49.7-day-wraparound behavior,
  not a new porting risk -- not "fixed" to GetTickCount64 here since that would
  be an unrequested behavior change, not a faithful port).
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, WinSock;

type
  TStat         = (Done);
  TCommObj      = class(TObject)
  public
    Stat        : TStat;
    SendHeader  : String;
    SentHeader  : String;
    StrRes      : String;
    constructor Create;
    procedure   HTTPPost(Server,Path,Data : String; Port : Cardinal = 80);
    procedure   CropHeader;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TCommObj.Create;
begin
  inherited Create;
  Stat:=Done;
  SendHeader:='';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCommObj.HTTPPost(Server,Path,Data : String; Port : Cardinal = 80);
var
  Host : PHostEnt;
  Addr : PInAddr;
  Info : TSockAddrIn;
  S1   : Integer;
  s    : String;
  i    : Integer;
  m    : String;
  t    : Cardinal;
begin
  StrRes:='';

  s:=SendHeader;
  repeat
    i:=Pos('$',s);
    if i<1 then Break;
    Delete(s,i,1);
    Insert(#13#10,s,i);
  until False;
  s:=Trim(s);

  SentHeader:='POST '+Path+' HTTP/1.0'#13#10+
              'Host: '+Server+#13#10+
              'Content-Length: '+IntToStr(Length(Data))+#13#10+
              s+#13#10+
              #13#10+
              Data;

  ///////////////////////////

  Host:=gethostbyname(PChar(Server));
  if Host=nil then Exit;
  Addr:=PInAddr(Host.h_addr_list^);
  //ShowMessage(inet_ntoa(Addr^));

  ZeroMemory(@Info,SizeOf(Info));
  Info.sin_family:=AF_INET;
  Info.sin_port:=htons(Port);
  Info.sin_addr:=Addr^;

  S1:=socket(AF_INET,SOCK_STREAM,0);
  if S1=INVALID_SOCKET then Exit;
  try
    if connect(S1,Info,SizeOf(Info))<>0 then Exit;
    //ShowMessage('connected!');
    if send(S1,SentHeader[1],Length(SentHeader),0)=SOCKET_ERROR then Exit;

    m:='';
    t:=GetTickCount;
    repeat
      if GetTickCount-t>300000 then Exit;
      SetLength(s,4096);
      i:=recv(S1,s[1],4096,0);
      SetLength(s,i);
      m:=m+s;
    until i=0;

    StrRes:=m;
  finally
    closesocket(S1);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCommObj.CropHeader;
var
  Cnt : Integer;
begin
  Cnt:=Pos(#13#10#13#10,StrRes);
  Delete(StrRes,1,Cnt+3);
end;

////////////////////////////////////////////////////////////////////////////////
var WSData : WSAData;
initialization
  WSAStartup(2,WSData);
finalization
  WSACleanUp;
end.
