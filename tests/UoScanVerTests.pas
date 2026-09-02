unit UoScanVerTests;

{
  Tests for uo\uoscanver.pas. ScanVer itself needs a live "Ultima Online"-classed
  process to fingerprint and is not exercised here (see the migration plan's Tier
  3/4 strategy -- that needs either a real client or the not-yet-built synthetic
  fake-client-process harness, deliberately deferred out of this phase). What IS
  genuinely testable without any of that:
  - GetExePath against this test process's own handle (GetModuleFileNameEx works
    fine for the calling process, no live UO client involved).
  - EnumCliWnd's exact window-class matching, using two real (invisible) windows
    created with distinct classes -- one literally named "Ultima Online", one not
    -- so the callback's own logic is exercised end-to-end, not just assumed.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, uoscanver;

type
  TUoScanVerTests = class(TTestCase)
  published
    procedure TestGetExePathAgainstOwnProcess;
    procedure TestGetExePathWithNullHandleReturnsEmpty;
    procedure TestEnumCliWndMatchesOnlyExactClassName;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TUoScanVerTests.TestGetExePathAgainstOwnProcess;
var
  Path : String;
  Hnd  : THandle;
begin
  // Deliberately NOT GetCurrentProcess() -- that returns a sentinel pseudo-handle
  // (all 64 bits set), which the original PSAPI-loaded GetModuleFileNameEx (a
  // Cardinal-typed function pointer, unchanged from the original since real
  // OpenProcess handles to the always-32-bit remote client safely fit in 32 bits)
  // would receive truncated to the wrong value -- production code never calls
  // GetExePath with that pseudo-handle, only with a real OpenProcess handle, so
  // a real handle is what this test needs too.
  Hnd := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False,
    GetCurrentProcessId);
  AssertTrue('failed to open a handle to this test process', Hnd <> 0);
  try
    Path := GetExePath(Cardinal(Hnd));
    AssertTrue('expected a real exe path, got: ' + Path, FileExists(Path));
    AssertTrue('expected the path to point at this test binary',
      Pos('RUNTESTS', UpperCase(Path)) > 0);
  finally
    CloseHandle(Hnd);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoScanVerTests.TestGetExePathWithNullHandleReturnsEmpty;
begin
  AssertEquals('', GetExePath(0));
end;

////////////////////////////////////////////////////////////////////////////////
function MakeInvisibleWindow(const ClassName, WindowTitle : String) : HWND;
var
  WC : TWndClass;
begin
  ZeroMemory(@WC, SizeOf(WC));
  WC.lpfnWndProc := @DefWindowProc;
  WC.hInstance := HInstance;
  WC.lpszClassName := PChar(ClassName);
  Windows.RegisterClass(WC);
  Result := CreateWindowEx(0, PChar(ClassName), PChar(WindowTitle), 0,
    0, 0, 0, 0, 0, 0, HInstance, nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoScanVerTests.TestEnumCliWndMatchesOnlyExactClassName;
var
  UOWnd, OtherWnd : HWND;
  List : TStringList;
begin
  UOWnd := MakeInvisibleWindow('Ultima Online', 'fake client for testing');
  OtherWnd := MakeInvisibleWindow('Not Ultima Online', 'unrelated window');
  AssertTrue('failed to create test windows', (UOWnd <> 0) and (OtherWnd <> 0));

  List := TStringList.Create;
  try
    EnumWindows(@EnumCliWnd, Cardinal(List));
    AssertTrue('the "Ultima Online"-classed window must be picked up',
      List.IndexOf(IntToStr(UOWnd)) >= 0);
    AssertTrue('a differently-classed window must NOT be picked up',
      List.IndexOf(IntToStr(OtherWnd)) < 0);
  finally
    List.Free;
    DestroyWindow(UOWnd);
    DestroyWindow(OtherWnd);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TUoScanVerTests);
end.
