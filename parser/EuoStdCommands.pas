unit EuoStdCommands;

{
  Ported from the original Delphi 7 parser\stdcommands.pas -- client-independent OS
  utility commands (no uo\ engine dependency at all). Two changes from the
  original, both deliberate: TDelayFunc unified to the one shared declaration in
  common\uotypes.pas (originally duplicated separately in stdcommands.pas/
  uocommands.pas/uoevents.pas); and Display/SetCliTitle's "@Str[1]" raw first-
  character-address idiom replaced with PChar(Str), per the migration plan (a raw
  @Str[1] on a possibly-empty string doesn't reliably give a valid empty-C-string
  pointer the way an explicit PChar cast does in both compilers). Everything else
  was first ported byte-for-byte identical to the original, then adjusted only
  where the real compiler proved a change was needed (a first draft "corrected"
  several identifiers speculatively without checking -- that was reverted before
  compiling for real). Three genuine FPC-vs-Delphi differences, confirmed against
  FPC's actual RTL/package source, not guessed:
  - ShellExecuteEx(@Info) is ambiguous between FPC's A/W overloads for this
    pointer type; called as the explicit ShellExecuteExA entry point instead
    (ShellExecuteExW since 2026-11-27, see Execute).
  - hTokenHandle must be THandle (8 bytes on Win64), not Cardinal (4 bytes) --
    OpenProcessToken's var out-parameter is handle-width. Same bug class as
    Phase 1's access.pas RPM/WPM finding.
  - FPC's Windows unit has no ID_OK/ID_YES/ID_NO aliases Delphi provides; only
    the standard IDOK/IDYES/IDNO spellings exist.
  Later, at the user's request: the DISPLAY box's caption is 'Reforged Message'
  (was 'EUO Message'), held in DISPLAY_CAPTION, which EuoExecutor's
  KillDisplayBox matches on to close a stopped script's box.
  Port addition (EUOCli run, docs\agent-support.md phase 3): OnDisplay. A host with nobody
  to click a message box sets it, and Display then asks the handler for the answer instead
  of opening the box. It is nil unless a host sets it, so the editor and uo.dll show the
  box exactly as before.
}

{$mode delphi}{$H+}

interface
uses SysUtils, Windows, Messages, ShellApi, MMSystem, Registry, Classes, uotypes;

const
  DISPLAY_CAPTION = 'Reforged Message';

type
  // Port addition: answers a DISPLAY in place of the message box. Text is the message with
  // its '$' already turned into line breaks, Buttons is OK, OKCANCEL, YESNO or YESNOCANCEL.
  // The result becomes #DispRes: Ok, Yes, No or Cancel. Called on the script's thread.
  TDisplayHandler = function(const Text, Buttons : String) : String of object;

  TStdCmd       = class(TObject)
  private
    Delay       : TDelayFunc;
    function    GetVK(KeyStr : String) : Cardinal;
  public
    DispRes     : String;
    OnDisplay   : TDisplayHandler;   // port addition; nil = show the message box

    constructor Create(DFunc : TDelayFunc);
    procedure   Wait(Duration, RandHi : Cardinal);
    function    OnHotkey(KeyStr : String; Ctrl,Alt,Shift : Boolean) : Boolean;
    procedure   Shutdown(Force : Boolean = False);
    function    Execute(App,Par : String; Show : Boolean; TimeOut : Cardinal = 0) : Boolean;
    procedure   SoundProc(SndFile : String = '');

    function    GetPix(Wnd : Cardinal; X,Y : Cardinal) : Cardinal;
    function    Display(Wnd : Cardinal; Str : String; MsgType : String; Dollar : Boolean = True) : String;
    function    GetCliTitle(Wnd : Cardinal) : String;
    procedure   SetCliTitle(Wnd : Cardinal; Title : String);
    procedure   TypeText(Wnd : Cardinal; const Text : String);   // port addition (MSG)
  end;

implementation
uses EuoConversion;

////////////////////////////////////////////////////////////////////////////////
constructor TStdCmd.Create(DFunc : TDelayFunc);
begin
  Delay:=DFunc;
  DispRes:='';
  OnDisplay:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStdCmd.Wait(Duration, RandHi : Cardinal);
begin
  Delay(Duration+Random(RandHi));
end;

////////////////////////////////////////////////////////////////////////////////
function TStdCmd.GetVK(KeyStr : String) : Cardinal;
const
  HKStr : Array[0..22] of String = (
    'F10','F11','F12','ESC','BACK','TAB','ENTER','PAUSE','CAPSLOCK','SPACE',
    'PGUP','PGDN','END','HOME','LEFT','RIGHT','UP','DOWN','PRNSCR','INSERT',
    'DELETE','NUMLOCK','SCROLLLOCK');
  HKVK : Array[0..22] of Cardinal = (
    VK_F10,VK_F11,VK_F12,VK_ESCAPE,VK_BACK,VK_TAB,VK_RETURN,VK_PAUSE,
    VK_CAPITAL,VK_SPACE,VK_PRIOR,VK_NEXT,VK_END,VK_HOME,VK_LEFT,VK_RIGHT,
    VK_UP,VK_DOWN,VK_SNAPSHOT,VK_INSERT,VK_DELETE,VK_NUMLOCK,VK_SCROLL);
var
  Cnt : Integer;
begin
  Result:=0;
  KeyStr:=UpperCase(KeyStr);
  if Length(KeyStr)=1 then
    if KeyStr[1] in ['A'..'Z','0'..'9'] then
      Result:=Byte(KeyStr[1]);
  if Length(KeyStr)=2 then
    if (KeyStr[1]='F')and(KeyStr[2] in ['1'..'9']) then
      Result:=Byte(VK_F1+Byte(KeyStr[2])-49);
  if Result=0 then
    for Cnt:=0 to High(HKStr) do
      if KeyStr=HKStr[Cnt] then
        Result:=HKVK[Cnt];
end;

////////////////////////////////////////////////////////////////////////////////
function TStdCmd.OnHotkey(KeyStr : String; Ctrl,Alt,Shift : Boolean) : Boolean;
var
  VK       : Cardinal;
begin
  Result:=False;
  VK:=GetVK(KeyStr);
  if VK=0 then Exit;

  if (Hi(GetAsyncKeyState(VK))<128) then Exit;
  if Ctrl xor (Hi(GetAsyncKeyState(VK_CONTROL))>127) then Exit;
  if Alt xor (Hi(GetAsyncKeyState(VK_MENU))>127) then Exit;
  if Shift xor (Hi(GetAsyncKeyState(VK_SHIFT))>127) then Exit;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// Port change (EuoTextEncoding, 2026-11-27): the script's text is UTF-8, so the Unicode entry
// point, with the file and parameters decoded from UTF-8 (was ShellExecuteExA with the bytes as
// they were, which Windows read as its ANSI code page).
function TStdCmd.Execute(App,Par : String; Show : Boolean; TimeOut : Cardinal = 0) : Boolean;
var
  Info   : ShellExecuteInfoW;
  WApp   : UnicodeString;
  WPar   : UnicodeString;
begin
  WApp:=UTF8Decode(App);
  WPar:=UTF8Decode(Par);
  FillChar(Info,SizeOf(Info),0);
  Info.cbSize:=SizeOf(ShellExecuteInfoW);
  Info.fMask:=SEE_MASK_DOENVSUBST or SEE_MASK_NOCLOSEPROCESS;
  Info.Wnd:=0;
  Info.lpVerb:='open';
  Info.lpFile:=PWideChar(WApp);
  Info.lpParameters:=PWideChar(WPar);
  Info.lpDirectory:=nil;
  Info.nShow:=SW_SHOW*Byte(Show)+SW_HIDE*Byte(not Show);
  ShellExecuteExW(@Info);   // explicit -W entry point: plain ShellExecuteEx is
                            // ambiguous between the A/W overloads under FPC

  Result:=Info.hInstApp>32;
  if not Result then Exit;

  if TimeOut>0 then
    Result:=WaitForSingleObject(Info.hProcess,TimeOut)<>WAIT_FAILED;
  CloseHandle(Info.hProcess);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStdCmd.Shutdown(Force : Boolean = False);
var
  hTokenHandle : THandle;   // must be handle-width (8 bytes on Win64), not
                            // Cardinal -- OpenProcessToken's var out-param
  PrivLUID     : Int64;
  TokenPriv    : TOKEN_PRIVILEGES;
  tkpDummy     : TOKEN_PRIVILEGES;
  lDummy       : Cardinal;
begin
  OpenProcessToken(GetCurrentProcess,
    TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hTokenHandle);
  LookupPrivilegeValue('', 'SeShutdownPrivilege', PrivLUID);
  TokenPriv.PrivilegeCount:=1;
  TokenPriv.Privileges[0].Luid:=PrivLUID;
  TokenPriv.Privileges[0].Attributes:=SE_PRIVILEGE_ENABLED;
  AdjustTokenPrivileges(hTokenHandle, False, TokenPriv,
    SizeOf(tkpDummy), tkpDummy, lDummy);
  CloseHandle(hTokenHandle);
  ExitWindowsEx(EWX_FORCE*Byte(Force)+EWX_POWEROFF+EWX_SHUTDOWN, 0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStdCmd.SoundProc(SndFile : String = '');
begin
  if SndFile='' then
  begin
    MessageBeep($FFFFFFFF);
    MessageBeep(MB_OK);
  end
  else SndPlaySound(PChar(SndFile), SND_ASYNC or SND_NOSTOP or SND_NODEFAULT);
end;

////////////////////////////////////////////////////////////////////////////////
function TStdCmd.GetPix(Wnd : Cardinal; X,Y : Cardinal) : Cardinal;
var
  DC : HDC;
begin
  DC:=GetDC(Wnd);
  Result:=GetPixel(DC,X,Y);
  ReleaseDC(Wnd,DC);
end;

////////////////////////////////////////////////////////////////////////////////
function TStdCmd.Display(Wnd : Cardinal; Str : String; MsgType : String; Dollar : Boolean = True) : String;
var
  MBType : Cardinal;
  WStr   : UnicodeString;
  WCap   : UnicodeString;
begin
  MsgType:=UpperCase(MsgType);
  MBType:=MB_OK;
  if MsgType='OKCANCEL'    then MBType:=MB_OKCANCEL;
  if MsgType='YESNO'       then MBType:=MB_YESNO;
  if MsgType='YESNOCANCEL' then MBType:=MB_YESNOCANCEL;

  if Dollar then Str:=ReplaceStr(Str,'$',#13#10);

  // Port addition: a host that answers DISPLAY itself (see OnDisplay). No box is opened.
  if Assigned(OnDisplay) then
  begin
    if MBType=MB_OK then MsgType:='OK';
    Result:=OnDisplay(Str,MsgType);
    DispRes:=Result;
    Exit;
  end;

  // Port change (EuoTextEncoding): the Unicode box, the text decoded from UTF-8 (MessageBox was
  // MessageBoxA, which showed a UTF-8 "è" as "Ã¨").
  WStr:=UTF8Decode(Str);
  WCap:=DISPLAY_CAPTION;
  MBType:=MessageBoxW(Wnd,PWideChar(WStr),PWideChar(WCap),MB_SETFOREGROUND+{MB_TOPMOST+}MBType);
  //MB_TOPMOST will only work if executed in the EUO window thread!
  //But because of the sync all other threads who use display get blocked
  //until the very last display message disappears!!!!!!!!!!

  Result:='Cancel';
  case MBType of
    IDOK  : Result:='Ok';   // confirmed via compile: FPC has no ID_OK/ID_YES/
    IDYES : Result:='Yes';  // ID_NO underscore-alias forms Delphi provides,
    IDNO  : Result:='No';   // only the standard IDOK/IDYES/IDNO spellings
  end;
  DispRes:=Result;
end;

////////////////////////////////////////////////////////////////////////////////
// Port change (EuoTextEncoding, 2026-11-27): the title through the Unicode calls, as UTF-8 like
// the script's text (were GetWindowTextA/SetWindowTextA, the bytes read as the ANSI code page).
// GETUOTITLE, SETUOTITLE and #CliTitle all come here; uo.dll keeps its own (TUOVar.CliTitle).
function TStdCmd.GetCliTitle(Wnd : Cardinal) : String;
var
  W : UnicodeString;
  N : Integer;
begin
  Result:='';
  N:=GetWindowTextLengthW(Wnd);
  if N<=0 then Exit;
  SetLength(W,N+1);
  N:=GetWindowTextW(Wnd,PWideChar(W),N+1);
  SetLength(W,N);
  Result:=UTF8Encode(W);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStdCmd.SetCliTitle(Wnd : Cardinal; Title : String);
var
  W : UnicodeString;
begin
  W:=UTF8Decode(Title);
  SetWindowTextW(Wnd,PWideChar(W));
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (EuoTextEncoding): MSG's typing, as the original TUOCmd.Msg did it (one WM_CHAR
// per character, posted), but from UTF-8 and through PostMessageW, so every letter arrives as
// itself (TUOCmd.Msg posted each byte with PostMessageA; uo.dll still uses it).
procedure TStdCmd.TypeText(Wnd : Cardinal; const Text : String);
var
  W : UnicodeString;
  i : Integer;
begin
  W:=UTF8Decode(Text);
  for i:=1 to Length(W) do
    PostMessageW(Wnd,WM_CHAR,WPARAM(Ord(W[i])),0);
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  Randomize;
end.
