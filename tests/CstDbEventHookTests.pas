unit CstDbEventHookTests;

{ Regression tests for TCstDB.Update's live scan when an earlier Reforged session has
  already installed its event hook (uoevents.pas InitEvents) in the client.

  The bug: E_OLDDIR is scanned as the target of the client's `call` at E_REDIR. After a
  first session ran an event command, that call points at the code cave instead, so a
  second session resolved E_OLDDIR to the cave itself. The cave ends with
  `push E_OLDDIR; ret`, which then jumped to its own start -- an endless loop that froze
  the client's main thread (only Task Manager could end it).

  The fake "client" is a suspended, never-resumed child process (cmd.exe) with a block of
  memory committed in it at the fixed address $400000 -- the base SearchMem always scans
  from -- holding just the signature the E_REDIR/E_OLDDIR scan entries look for, so no
  real UO client is needed. It has to be a child: the test executable itself is linked
  at $400000, so that range can't be mapped in-process. If the child can't be set up the
  tests report as ignored. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, uoclidata, access;

type
  TCstDbEventHookTests = class(TTestCase)
  private
    Proc   : TProcessInformation;
    PHnd   : Cardinal;
    Ready  : Boolean;
    Why    : String;
    Cst    : TCstDB;
    procedure PutBytes(Addr : Cardinal; const Bytes : array of Byte);
    procedure PutDWord(Addr, Value : Cardinal);
    procedure InstallClientCall(Target : Cardinal);
    procedure InstallCave(PushedValue : Cardinal);
    procedure Rescan;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestUnpatchedClientResolvesOriginalTarget;
    procedure TestRescanAfterHookInstalledKeepsOriginalTarget;
    procedure TestRescanIsStableAcrossRepeatedSessions;
    procedure TestPatchedCallWithBlankCaveDisablesHook;
    procedure TestPatchedCallWithSelfLoopingCaveDisablesHook;
  end;

implementation

const
  ImageBase   = $400000;
  ImageSize   = $660000;           // SearchMem reads $4000-byte blocks up to $650000
  CallAddr    = $5AFC6D;           // address of the `call` opcode the E_REDIR scan resolves
  OrigTarget  = $0063BB40;         // the client function that call originally targets

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.PutBytes(Addr : Cardinal; const Bytes : array of Byte);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@Bytes[0]), Length(Bytes)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.PutDWord(Addr, Value : Cardinal);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@Value), 4));
end;

////////////////////////////////////////////////////////////////////////////////
// `33 DB 53 53 50 E8 <rel32>` -- the signature both the E_REDIR and E_OLDDIR scan
// entries use; the client's `call` is the E8.
procedure TCstDbEventHookTests.InstallClientCall(Target : Cardinal);
begin
  PutBytes(CallAddr - 5, [$33, $DB, $53, $53, $50, $E8]);
  PutDWord(CallAddr + 1, Target - (CallAddr + 5));
end;

////////////////////////////////////////////////////////////////////////////////
// The first instruction of uoevents.pas's cave: `push imm32`. What it pushes is the
// value E_OLDDIR had when the hook was installed.
procedure TCstDbEventHookTests.InstallCave(PushedValue : Cardinal);
begin
  PutBytes(EVENT_CAVE_BASE, [$68]);
  PutDWord(EVENT_CAVE_BASE + 1, PushedValue);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.Rescan;
begin
  Cst.Update('7.0.108.0', PHnd);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.SetUp;
var
  SI   : TStartupInfo;
  Path : String;
begin
  Cst := TCstDB.Create;
  Ready := False;
  PHnd := 0;
  ZeroMemory(@Proc, SizeOf(Proc));
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);

  Path := SysUtils.GetEnvironmentVariable('SystemRoot') + '\System32\cmd.exe';
  if not CreateProcess(PChar(Path), nil, nil, nil, False, CREATE_SUSPENDED, nil, nil, SI, Proc) then
  begin
    Why := 'Cannot start helper process (Win32 error ' + IntToStr(GetLastError) + ').';
    Exit;
  end;
  PHnd := Proc.hProcess;

  if VirtualAllocEx(PHnd, Pointer(ImageBase), ImageSize, MEM_RESERVE or MEM_COMMIT,
                    PAGE_READWRITE) = nil then
  begin
    Why := 'Cannot map the fake client image at $400000 (Win32 error ' +
           IntToStr(GetLastError) + ').';
    Exit;
  end;
  Ready := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.TearDown;
begin
  if Proc.hProcess <> 0 then
  begin
    TerminateProcess(Proc.hProcess, 0);
    CloseHandle(Proc.hThread);
    CloseHandle(Proc.hProcess);
  end;
  Cst.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.TestUnpatchedClientResolvesOriginalTarget;
begin
  if not Ready then Ignore(Why);
  InstallClientCall(OrigTarget);

  Rescan;

  AssertEquals('E_REDIR', CallAddr, Cst.EREDIR);
  AssertEquals('E_OLDDIR', OrigTarget, Cst.EOLDDIR);
end;

////////////////////////////////////////////////////////////////////////////////
// The reported scenario: session 1 patched the client, session 2 rescans it.
procedure TCstDbEventHookTests.TestRescanAfterHookInstalledKeepsOriginalTarget;
begin
  if not Ready then Ignore(Why);
  InstallClientCall(OrigTarget);
  Rescan;                                       // session 1: reads the pristine client

  InstallCave(Cst.EOLDDIR);                     // ...and InitEvents installs its hook
  InstallClientCall(EVENT_CAVE_BASE);

  Rescan;                                       // session 2

  AssertEquals('E_REDIR', CallAddr, Cst.EREDIR);
  AssertEquals('E_OLDDIR must still be the client''s own function, not the cave',
               OrigTarget, Cst.EOLDDIR);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.TestRescanIsStableAcrossRepeatedSessions;
var
  i : Integer;
begin
  if not Ready then Ignore(Why);
  InstallClientCall(OrigTarget);
  Rescan;
  InstallCave(Cst.EOLDDIR);
  InstallClientCall(EVENT_CAVE_BASE);

  for i := 1 to 3 do
  begin
    Rescan;
    InstallCave(Cst.EOLDDIR);                   // each session's InitEvents rewrites the cave
    AssertEquals('E_OLDDIR after session ' + IntToStr(i), OrigTarget, Cst.EOLDDIR);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Patched call but nothing readable in the cave (e.g. something else patched it): the
// original target is unrecoverable, so the hook must be switched off rather than built
// on a guess.
procedure TCstDbEventHookTests.TestPatchedCallWithBlankCaveDisablesHook;
begin
  if not Ready then Ignore(Why);
  InstallClientCall(EVENT_CAVE_BASE);

  Rescan;

  AssertEquals('E_REDIR', Cardinal(0), Cst.EREDIR);
  AssertEquals('E_OLDDIR', Cardinal(0), Cst.EOLDDIR);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbEventHookTests.TestPatchedCallWithSelfLoopingCaveDisablesHook;
begin
  if not Ready then Ignore(Why);
  InstallClientCall(EVENT_CAVE_BASE);
  InstallCave(EVENT_CAVE_BASE);                 // a cave already poisoned by the old bug

  Rescan;

  AssertEquals('E_REDIR', Cardinal(0), Cst.EREDIR);
  AssertEquals('E_OLDDIR', Cardinal(0), Cst.EOLDDIR);
end;

initialization
  RegisterTest(TCstDbEventHookTests);
end.
