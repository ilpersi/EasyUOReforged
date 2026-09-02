unit UOSelector;

{
  Ported from the original Delphi 7 tools\EUOUpdater\uoselector.pas. This is
  EUOUpdater's OWN simple, unthreaded, synchronously-polled client selector --
  deliberately kept separate from uo\uoselector.pas's TUOSel (which depends on
  TCstDB/uoclidata.pas and runs a background poller thread), per the migration
  plan and CLAUDE.md: EUOUpdater's tool doesn't need any of that, it just needs
  "is there an Ultima Online window right now" on its own SysTimer tick.

  One change, per the plan's explicit Phase 6 instruction ("port EUOUpdtr.exe
  onto uocommon"): the original forked its own rwaccess.pas (a near-duplicate
  of common\access.pas, including the same LoadLibrary+GetProcAddress-into-
  mistyped-function-pointers bug already fixed there in Phase 1, and the same
  Intel-syntax FindPos asm block already fixed there for 64-bit registers).
  Retired here; this unit now uses common\access.pas directly instead --
  RWVar(PHnd,Read,Pos,Buf,Len) becomes ReadMem(PHnd,Pos,Buf,Len) (access.pas
  has separate ReadMem/WriteMem functions rather than one RW-mode-selecting
  function; only Read is ever used here since GetVer never writes).

  Everything else -- the two client-version byte-signature scans (CliVer1 for
  1.26.x-2.0.x, CliVer2 for 3.0.x+), GetCurVer's cache-by-HWnd, GetNr's
  self-clearing "client went away" behavior -- is unchanged.
}

{$mode delphi}{$H+}

interface
uses Classes, Windows, SysUtils, access;

type
  TUOSel        = class(TObject)
  private
    UOHWnd      : Cardinal;
    PHandle     : Cardinal;
    WndList     : TStringList;
    VerStr      : String;
    VerHWnd     : Cardinal;
    function    GetCnt : Cardinal;
    function    GetNr : Cardinal;
    function    GetCurVer : String;
  public
    constructor Create;
    procedure   Free;
    procedure   Update;
    function    GetTitle(Nr : Cardinal) : String;
    function    GetPID(Nr : Cardinal) : Cardinal;
    function    GetVer(Nr : Cardinal) : String;
    function    SelectClient(Nr : Cardinal) : Boolean;
    property    Cnt : Cardinal read GetCnt;
    property    Nr : Cardinal read GetNr;
    property    Ver : String read GetCurVer;
    property    HWnd : Cardinal read UOHWnd;
    property    HProc : Cardinal read PHandle;
  end;

implementation
{******************************************************************************}

type
  TScanStr = record
    Str      : String;
    Offs     : Integer;
    Joker    : Char;
  end;

const
  CliVer1    : TScanStr =
    (Str: #199#134#152#0#0#0#255#255#255#255#161#1#1#1#1#80#141#76#36#36#104; Offs: 11; Joker: #1);
    // Clients 1.26.x - 2.0.x

  CliVer2    : TScanStr =
    (Str: #104#2#2#2#2#232#2#2#2#2#131#196#24#198#5#2#2#2#2#1#184; Offs: 1; Joker: #2);
    // Clients 3.0.x - ???

{******************************************************************************}
constructor TUOSel.Create;
begin
  inherited Create;
  WndList:=TStringList.Create;
  WndList.Sorted:=True;
  UOHWnd:=0;
  PHandle:=0;
  VerHWnd:=0;
end;

{******************************************************************************}
procedure TUOSel.Free;
begin
  WndList.Free;
end;

{******************************************************************************}
function EnumWnd(Wnd : HWnd; Obj : Cardinal) : Boolean; stdcall;
var
  Buf  : Array[1..14] of Char;
begin
  GetClassName(Wnd,@Buf,14);
  if StrPas(@Buf)='Ultima Online' then
  begin
    TStringList(Obj).Add(IntToStr(Wnd));
  end;
  Result:=True;
end;

{******************************************************************************}
procedure TUOSel.Update;
begin
  WndList.Clear;
  EnumWindows(@EnumWnd,Cardinal(WndList));
  GetNr;
end;

{******************************************************************************}
function TUOSel.GetTitle(Nr : Cardinal) : String;
var
  Buf : Array[0..255] of Char;
begin
  Result:='';
  if (WndList.Count<Nr)or(Nr=0) then Exit;
  GetWindowText(StrToInt(WndList[Nr-1]),@Buf,255);
  Result:=StrPas(@Buf);
end;

{******************************************************************************}
function TUOSel.GetPID(Nr : Cardinal) : Cardinal;
var
  PID  : Cardinal;
begin
  Result:=0;
  if (WndList.Count<Nr)or(Nr=0) then Exit;
  GetWindowThreadProcessID(StrToInt(WndList[Nr-1]),@PID);
  Result:=PID;
end;

{******************************************************************************}
function TUOSel.GetVer(Nr : Cardinal) : String;
var
  PHnd : Cardinal;
  cBuf : Cardinal;
  sBuf : String;
begin
  Result:='';
  if (Nr>WndList.Count)or(Nr=0) then Exit;

  GetWindowThreadProcessID(StrToInt(WndList[Nr-1]),PHnd);
  PHnd:=OpenProcess(PROCESS_ALL_ACCESS,False,PHnd);
  if PHnd=0 then Exit;

  sBuf:=#0#0#0#0#0#0#0#0#0#0;

  cBuf:=SearchMem(PHnd,CliVer1.Str,CliVer1.Joker)+CliVer1.Offs;
  if cBuf>$FF then
  begin
    ReadMem(PHnd, cBuf, @cBuf, 4);
    ReadMem(PHnd, cBuf+4, @sBuf[1], 10);
  end;

  cBuf:=SearchMem(PHnd,CliVer2.Str,CliVer2.Joker)+CliVer2.Offs;
  if cBuf>$FF then
  begin
    ReadMem(PHnd, cBuf, @cBuf, 4);
    ReadMem(PHnd, cBuf, @sBuf[1], 10);
  end;

  Result:=StrPas(@sBuf[1]);
end;

{******************************************************************************}
function TUOSel.SelectClient(Nr : Cardinal) : Boolean;
begin
  repeat
    if (Nr>WndList.Count)or(Nr=0) then Break;
    UOHWnd:=StrToInt(WndList[Nr-1]);
    GetWindowThreadProcessID(UOHWnd,PHandle);
    PHandle:=OpenProcess(PROCESS_ALL_ACCESS,False,PHandle);
    if PHandle=0 then Break;
    Result:=True;
    Exit;
  until True;
  UOHWnd:=0;
  PHandle:=0;
  Result:=False;
end;

{******************************************************************************}
function TUOSel.GetCnt : Cardinal;
begin
  Result:=WndList.Count;
end;

{******************************************************************************}
function TUOSel.GetNr : Cardinal;
begin
  Result:=WndList.IndexOf(IntToStr(UOHWnd))+1;
  if Result>0 then Exit;
  UOHWnd:=0;
  PHandle:=0;
end;

{******************************************************************************}
function TUOSel.GetCurVer : String;
begin
  Result:='';
  if UOHWnd=0 then Exit;
  if VerHWnd<>UOHWnd then VerStr:=GetVer(GetNr);
  if VerStr='' then Exit;
  VerHWnd:=UOHWnd;
  Result:=VerStr;
end;

{******************************************************************************}
end.
