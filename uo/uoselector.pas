unit uoselector;

{
  Ported from the original Delphi 7 uo\uoselector.pas (read in full, 244 lines).
  TUOSel enumerates candidate "Ultima Online"-classed windows on a background
  100ms timer and lets callers pick/switch which running client instance to
  drive; multiple TUOSel instances (one per open script tab) share one process-
  wide window/version list, kept in sync by a single background poller and
  protected by one TMultiReadExclusiveWriteSynchronizer (RCS) -- concurrent
  reads from many TUOSel.Nr/Cnt/GetTitle/etc. calls, exclusive writes only while
  the poller refreshes the list. This genuinely needs multi-reader/single-writer
  semantics (not just inertia from the original), so RCS is kept as-is rather
  than simplified to a plain TCriticalSection.

  Modernization applied per the migration plan: the original's raw BeginThread +
  TerminateThread singleton poller is replaced with a proper TThread descendant
  (TUOSelPoller). TimerProc's own scan-and-diff logic is unchanged.

  finalization deliberately does NOT wait for the thread to exit, even though
  this unit is also linked into EasyUOReforged.exe (a normal process, where waiting
  would be safe) -- because it is ALSO linked into uo.dll (Phase 6), and this
  unit's initialization/finalization run inside DllMain for a DLL. An earlier
  version of this fix used Poller.Terminate + Poller.WaitFor (safe for a plain
  EXE), and it deadlocked uo.dll's FreeLibrary every time: the main thread,
  inside DllMain(DLL_PROCESS_DETACH), holds the OS loader lock while waiting
  for the poller thread to exit; the poller thread's own exit needs that same
  loader lock (Windows notifies every loaded DLL of DLL_THREAD_DETACH when any
  thread exits) -- a real, unbreakable circular wait, confirmed by isolating
  it with a standalone LoadLibrary/FreeLibrary smoke test (Close() returned
  fine; FreeLibrary() hung indefinitely). No bounded timeout fixes this either
  -- the wait can never succeed while the lock is held, so it would just make
  every FreeLibrary call slow instead of hanging outright. Matching the
  original's own forceful TerminateThread (no wait at all) turns out to be the
  genuinely correct choice here, not just the simpler one -- it's safe in both
  the EXE and the DLL context, so there's no need for context-specific
  behavior. The original author's choice of the "simple" primitive over a
  "proper" cooperative one was, in this specific case, already right.

  Preserved exactly (pre-existing in the original, not something this port
  should "fix"): GetTitle/GetPID use StrToInt on a stringified HWND while
  SelectClient uses StrToInt64 for the same kind of value -- an inconsistency
  already present in the Delphi 7 source, harmless in practice since real HWND
  values are handle-table indices, not large memory addresses, and not a
  bitness/porting concern this migration was asked to address.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Classes, uoclidata, uoscanver;

type
  TUOSel        = class(TObject)
  private
    CliHWnd     : Cardinal;
    PHandle     : Cardinal;
  public
    CstDB       : TCstDB;
    constructor Create;
    procedure   Free;
    function    GetTitle(Nr : Cardinal) : String;
    function    GetPID(Nr : Cardinal) : Cardinal;
    function    GetVer(Nr : Cardinal) : String;
    function    SelectClient(Nr : Cardinal; Version : String = '') : Boolean;
    function    Cnt : Cardinal;
    function    Nr : Cardinal;
    function    Ver : String;
    function    ExePath : String;
    property    HWnd : Cardinal read CliHWnd;
    property    HProc : Cardinal read PHandle;
  end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
implementation

type
  TUOSelPoller = class(TThread)
  protected
    procedure   Execute; override;
  end;

var
  WndList     : TStringList;
  VerList     : TStringList;
  RCS         : TMultiReadExclusiveWriteSynchronizer;
  Insts       : TList;
  Poller      : TUOSelPoller;

////////////////////////////////////////////////////////////////////////////////
procedure TimerProc;
var
  Cnt    : Integer;
  Cnt2   : Integer;
  Wnd    : Cardinal;
  Found  : Boolean;
  wList  : TStringList;
  vList  : TStringList;
begin
  wList:=TStringList.Create;
  wList.Sorted:=True;
  EnumWindows(@EnumCliWnd,Cardinal(wList));

  vList:=TStringList.Create;
  RCS.BeginWrite;
  vList.Assign(VerList);       // CS in case of UOSelUpdate reentrance!
  RCS.EndWrite;

  // Add new entries to version list. Found is tracked explicitly rather than testing
  // Cnt2>=vList.Count after the inner loop -- a real, pre-existing bug (inherited from
  // the original Delphi 7 source, not introduced by this migration) relied on that
  // post-loop counter value, but Object Pascal's `for` loop leaves its control variable
  // at its LAST ITERATED value on normal completion (not one past it, unlike a C-style
  // loop) -- so whenever vList.Count was exactly 1 at the moment a genuinely-new window
  // was checked (e.g. the second of two clients discovered in the same poll tick), the
  // inner loop's single iteration (Cnt2:=0, no match, no Break) left Cnt2=0, and
  // `0 >= vList.Count(=1)` is False -- silently treated as "already known" and never
  // scanned, leaving that window's version permanently empty (and therefore permanently
  // filtered out as unsupported) even though a fresh scan would have succeeded. Verified
  // directly: reproduced against two real, simultaneously-running clients, and confirmed
  // fixed the same way afterward.
  for Cnt:=0 to wList.Count-1 do
  begin
    Wnd:=Cardinal(wList.Objects[Cnt]);
    Found:=False;
    for Cnt2:=0 to vList.Count-1 do
      if Cardinal(vList.Objects[Cnt2])=Wnd then
      begin
        Found:=True;
        Break;
      end;
    if not Found then
      vList.AddObject(ScanVer(Wnd),Pointer(Wnd));
  end;

  // Delete unused entries in version list
  for Cnt:=vList.Count-1 downto 0 do
  begin
    Wnd:=Cardinal(vList.Objects[Cnt]);
    if wList.IndexOf(IntToStr(Wnd))<0 then
      vList.Delete(Cnt);
  end;

  // Local window and version lists are synced now!

  // Delete unsupported clients in window list. Switched (per an explicit decision
  // confirmed with the user during the milestone/delta uoclidata.pas redesign) from an
  // exact-string match against the old flat SupportedCli list to uoclidata's floor-based
  // CliVerSupported -- a client build newer than the newest known milestone, or falling
  // in a not-yet-explicitly-known gap, is now automatically selectable instead of being
  // silently filtered out until someone adds an exact ClientList/VersionIndex row for it.
  for Cnt:=0 to vList.Count-1 do
  begin
    if CliVerSupported(vList[Cnt]) then Continue;
    Wnd:=Cardinal(vList.Objects[Cnt]);
    if wList.Find(IntToStr(Wnd),Cnt2) then // Always successful
      wList.Delete(Cnt2);
  end;

  RCS.BeginWrite;
  VerList.Free;
  WndList.Free;
  VerList:=vList;
  WndList:=wList;
  for Cnt:=0 to Insts.Count-1 do // Refresh all UOSel objects!
    TUOSel(Insts[Cnt]).Nr; // CS recursion!
  RCS.EndWrite;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TUOSel.Create;
begin
  inherited Create;
  CstDB:=TCstDB.Create;
  CliHWnd:=0;
  PHandle:=0;
  RCS.BeginWrite;
  Insts.Add(self);
  RCS.EndWrite;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOSel.Free;
begin
  RCS.BeginWrite;
  Insts.Delete(Insts.IndexOf(self));
  RCS.EndWrite;
  CstDB.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.GetTitle(Nr : Cardinal) : String;
var
  Buf : array[0..255] of Char;
begin
  RCS.BeginRead;
  Result:='';
  if (Nr<=WndList.Count)and(Nr>0) then
  begin
    GetWindowText(StrToInt(WndList[Nr-1]),@Buf,255);
    Result:=PChar(@Buf);
  end;
  RCS.EndRead;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.GetPID(Nr : Cardinal) : Cardinal;
begin
  RCS.BeginRead;
  Result:=0;
  if (Nr<=WndList.Count)and(Nr>0) then
    GetWindowThreadProcessID(StrToInt(WndList[Nr-1]),@Result);
  RCS.EndRead;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.GetVer(Nr : Cardinal) : String;
var
  Cnt : Integer;
begin
  RCS.BeginRead;
  Result:='';
  if (Nr<=WndList.Count)and(Nr>0) then
  begin
    for Cnt:=0 to VerList.Count-1 do
      if VerList.Objects[Cnt]=WndList.Objects[Nr-1] then
    begin
      Result:=VerList[Cnt];
      Break;
    end;
  end;
  RCS.EndRead;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.SelectClient(Nr : Cardinal; Version : String = '') : Boolean;
begin
  RCS.BeginRead;
  repeat
    if (Nr>WndList.Count)or(Nr=0) then Break;
    CliHWnd:=StrToInt64(WndList[Nr-1]);
    GetWindowThreadProcessID(CliHWnd,PHandle);
    PHandle:=OpenProcess(PROCESS_ALL_ACCESS,False,PHandle);
    if PHandle=0 then Break;
    if Version='' then CstDB.Update(Ver,PHandle)
    else CstDB.Update(Version,PHandle);
    Result:=True;
    RCS.EndRead;
    Exit;
  until True;
  RCS.EndRead;
  CliHWnd:=0;
  PHandle:=0;
  CstDB.Update('');
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.Cnt : Cardinal;
begin
  RCS.BeginRead;
  Result:=WndList.Count; //WndList might get freed and reassigned meanwhile!
  RCS.EndRead;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.Nr : Cardinal;
begin
  RCS.BeginRead;
  Result:=WndList.IndexOf(IntToStr(CliHWnd))+1;
  RCS.EndRead;
  if Result>0 then Exit;
  if PHandle>0 then
    CloseHandle(PHandle);
  CliHWnd:=0;
  PHandle:=0;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.Ver : String;
begin
  Result:=GetVer(Nr);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOSel.ExePath : String;
begin
  Result:=GetExePath(PHandle);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOSelPoller.Execute;
begin
  while not Terminated do
  begin
    Sleep(100);
    if not Terminated then TimerProc;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  WndList:=TStringList.Create;
  VerList:=TStringList.Create;
  Insts:=TList.Create;
  RCS:=TMultiReadExclusiveWriteSynchronizer.Create;
  TimerProc;
  Poller:=TUOSelPoller.Create(False);
finalization
  // No Terminate+WaitFor here -- see the unit header comment on the DLL
  // loader-lock deadlock this caused. TerminateThread matches the original's
  // own shutdown exactly and is safe in both the EXE and the DLL context.
  TerminateThread(Poller.Handle,0);
  CloseHandle(Poller.Handle);
  RCS.Free;
  Insts.Free;
  VerList.Free;
  WndList.Free;
end.
