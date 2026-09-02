unit uoscanver;

{
  Ported from the original Delphi 7 uo\uoscanver.pas (read in full, 162 lines) --
  fingerprints an attached UO client build by scanning its process memory for one
  of two known byte signatures (ScanStr1 for the old 1.26.x-2.0.x clients,
  ScanStr2 for 3.0.x-5.0.6e), falling back to the exe's embedded file version.

  One genuine 64-bit host bug found and fixed while porting, independent of every
  other bitness concern in this codebase: PSAPIHnd held the result of
  LoadLibrary('psapi.dll') as a Cardinal. Every OTHER handle in this unit/uo\
  (CliHWnd, PHnd/PHandle from OpenProcess) refers to an object owned by the
  REMOTE 32-bit client -- Windows/WOW64 officially guarantees those fit in 32
  bits, which is exactly why driving a 32-bit client from a 64-bit host works at
  all. PSAPIHnd is different: it's an HMODULE for a DLL loaded into THIS (64-bit)
  host process's own address space, and system DLLs commonly load above 4GB on
  Win64 (typically near 0x7FF0`00000000) -- truncating that to Cardinal would
  silently corrupt the handle, making every later GetProcAddress/FreeLibrary call
  operate on garbage. Fixed by widening PSAPIHnd to THandle. GetModuleFileNameEx's
  hProc/hMod parameters stay Cardinal, unchanged -- hProc there is always a
  REMOTE client process handle (safe per the above), and hMod is always passed
  literal 0.

  Retained as module-level state exactly as the original: LastScan/LastAddr cache
  the previously-successful scan method/address so a second call (from the same
  process, e.g. a periodic re-check) can skip straight to VerifyBase instead of
  re-scanning from scratch. This is unit-global (not per-window) in the original
  and is kept that way here -- the migration plan's stated modernization target
  for statefulness is uoselector.pas's own polling loop, not this fingerprinting
  helper.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Classes, access;

  function GetExePath(PHnd : Cardinal) : String;
  function ScanVer(Wnd : Cardinal) : String;
  function EnumCliWnd(Wnd, Obj : Cardinal) : Boolean; stdcall;

implementation

const
  ScanStr2 = #104#2#2#2#2#232#2#2#2#2#131#196#24#198#5#2#2#2#2#1#184; // Clients 3.0.x - 5.0.6e
  ScanStr1 = #199#134#152#0#0#0#255#255#255#255#161#1#1#1#1#80#141#76#36#36#104; // Clients 1.26.x - 2.0.x
var
  LastScan   : Cardinal = 0;
  LastAddr   : Cardinal = 0;
  PSAPIHnd   : THandle;                          // fixed: see unit header comment
  GetModuleFileNameEx : function(hProc, hMod : Cardinal; fn : PChar; size : Cardinal) : Cardinal; stdcall;

////////////////////////////////////////////////////////////////////////////////
function ReadScan2(PHnd, Base : Cardinal) : String;
var
  sBuf : String;
begin
  sBuf:=#0#0#0#0#0#0#0#0#0#0#0;
  ReadMem(PHnd, Base-15, @sBuf[1], 10);
  Result:=IntToStr(Byte(sBuf[10]))+'.'+
          IntToStr(Byte(sBuf[8]))+'.'+
          IntToStr(Byte(sBuf[6]));
  ReadMem(PHnd, Cardinal(Pointer(@sBuf[1])^), @sBuf[1], 10);
  Result:=Result+PChar(@sBuf[1]);
end;

////////////////////////////////////////////////////////////////////////////////
function ReadScan1(PHnd, Base : Cardinal) : String;
begin
  ReadMem(PHnd, Base+11, @Base, 4);
  Result:=#0#0#0#0#0#0#0#0#0#0#0;
  ReadMem(PHnd, Base+4, @Result[1], 10);
  Result:=PChar(@Result[1]);
end;

////////////////////////////////////////////////////////////////////////////////
function GetExePath(PHnd : Cardinal) : String;
var
  s    : String;
begin
  Result:='';
  if not Assigned(GetModuleFileNameEx)or(PHnd=0) then Exit;
  SetLength(s,4096);
  GetModuleFileNameEx(PHnd,0,@s[1],Length(s));
  Result:=PChar(s);
end;

////////////////////////////////////////////////////////////////////////////////
function GetFileVer(PHnd : Cardinal) : String;
var
  i     : Integer;
  fn    : String;
  str   : String;
  info  : PVSFixedFileInfo;
begin
  Result:='';
  fn:=GetExePath(PHnd);
  if fn='' then Exit;
  i:=GetFileVersionInfoSize(@fn[1],Cardinal(i));
  if i<1 then Exit;
  SetLength(str,i);
  GetFileVersionInfo(@fn[1],0,i,@str[1]);
  VerQueryValue(@str[1],'\',Pointer(info),Cardinal(i));
  if i<SizeOf(info) then Exit;
  Result:=IntToStr(HiWord(info^.dwFileVersionMS))+'.'+
    IntToStr(LoWord(info^.dwFileVersionMS))+'.'+
    IntToStr(HiWord(info^.dwFileVersionLS))+'.'+
    IntToStr(LoWord(info^.dwFileVersionLS));
end;

////////////////////////////////////////////////////////////////////////////////
function VerifyBase(PHnd, Base : Cardinal; ScanStr : String; Joker : Char) : Boolean;
var
  sBuf : String;
  Cnt  : Integer;
begin
  Result:=False;
  SetLength(sBuf,Length(ScanStr));
  ReadMem(PHnd, Base, @sBuf[1], Length(sBuf));
  for Cnt:=1 to Length(sBuf) do
    if ScanStr[Cnt]<>Joker then
      if ScanStr[Cnt]<>sBuf[Cnt] then Exit;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function ScanVer(Wnd : Cardinal) : String;
var
  PHnd  : Cardinal;
begin
  Result:='';

  GetWindowThreadProcessID(Wnd,PHnd);
  PHnd:=OpenProcess(PROCESS_ALL_ACCESS,False,PHnd);
  if PHnd=0 then Exit;

  case LastScan of
    2 : if VerifyBase(PHnd,LastAddr,ScanStr2,#2) then Result:=ReadScan2(PHnd,LastAddr);
    1 : if VerifyBase(PHnd,LastAddr,ScanStr1,#1) then Result:=ReadScan1(PHnd,LastAddr);
  end;
  if Result<>'' then
  begin
    CloseHandle(PHnd);
    Exit;
  end;
  LastScan:=0;

  LastAddr:=SearchMem(PHnd,ScanStr2,#2);
  if LastAddr>0 then
  begin
    Result:=ReadScan2(PHnd,LastAddr);
    LastScan:=2;
    CloseHandle(PHnd);
    Exit;
  end;

  Result:=GetFileVer(PHnd);
  if Result<>'' then
  begin
    CloseHandle(PHnd);
    Exit;
  end;

  LastAddr:=SearchMem(PHnd,ScanStr1,#1);
  if LastAddr>0 then
  begin
    Result:=ReadScan1(PHnd,LastAddr);
    LastScan:=1;
    CloseHandle(PHnd);
    Exit;
  end;

  CloseHandle(PHnd);
end;

////////////////////////////////////////////////////////////////////////////////
function EnumCliWnd(Wnd, Obj : Cardinal) : Boolean; stdcall;
var
  Buf  : array[1..14] of Char;
begin
  GetClassName(Wnd,@Buf,14);
  if PChar(@Buf)='Ultima Online' then
    TStringList(Obj).AddObject(IntToStr(Wnd),Pointer(Wnd));
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  PSAPIHnd:=LoadLibrary('psapi.dll');
  if PSAPIHnd=0 then GetModuleFileNameEx:=nil
  else GetModuleFileNameEx:=GetProcAddress(PSAPIHnd,'GetModuleFileNameExA');
finalization
  FreeLibrary(PSAPIHnd);
end.
