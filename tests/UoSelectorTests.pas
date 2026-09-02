unit UoSelectorTests;

{
  Tests for uo\uoselector.pas's TUOSel, exercised against this test machine's
  real background poller with (assumed) zero actual "Ultima Online"-classed
  windows running -- i.e. the same "no client selected" state the interpreter-core
  phase's stubs modeled, now proven against the real engine rather than a stub.
  Live-client selection itself (Tier 4 of the migration plan) needs a real game
  client and is out of scope here.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uoselector;

type
  TUoSelectorTests = class(TTestCase)
  published
    procedure TestNrIsZeroWithNoClientSelected;
    procedure TestGetTitleOutOfRangeReturnsEmpty;
    procedure TestGetPIDOutOfRangeReturnsZero;
    procedure TestGetVerOutOfRangeReturnsEmpty;
    procedure TestSelectClientOutOfRangeFailsCleanly;
    procedure TestVerOnUnselectedInstanceIsEmpty;
    procedure TestMultipleInstancesDontInterfere;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestNrIsZeroWithNoClientSelected;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertEquals(Cardinal(0), Sel.Nr);
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestGetTitleOutOfRangeReturnsEmpty;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertEquals('', Sel.GetTitle(0));
    AssertEquals('', Sel.GetTitle(999));
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestGetPIDOutOfRangeReturnsZero;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertEquals(Cardinal(0), Sel.GetPID(0));
    AssertEquals(Cardinal(0), Sel.GetPID(999));
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestGetVerOutOfRangeReturnsEmpty;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertEquals('', Sel.GetVer(0));
    AssertEquals('', Sel.GetVer(999));
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestSelectClientOutOfRangeFailsCleanly;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertFalse(Sel.SelectClient(0));
    AssertFalse(Sel.SelectClient(999));
    AssertEquals(Cardinal(0), Sel.HWnd);
    AssertEquals(Cardinal(0), Sel.HProc);
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestVerOnUnselectedInstanceIsEmpty;
var
  Sel : TUOSel;
begin
  Sel := TUOSel.Create;
  try
    AssertEquals('', Sel.Ver);
    AssertEquals('', Sel.ExePath);
  finally
    Sel.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoSelectorTests.TestMultipleInstancesDontInterfere;
var
  Sel1, Sel2 : TUOSel;
begin
  // TUOSel.Create/Free register/unregister with the shared process-wide Insts
  // list (refreshed by the background poller) -- confirms that's safe to do
  // repeatedly and concurrently-constructed instances don't crash each other.
  Sel1 := TUOSel.Create;
  try
    Sel2 := TUOSel.Create;
    try
      AssertEquals(Sel1.Cnt, Sel2.Cnt);
    finally
      Sel2.Free;
    end;
  finally
    Sel1.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TUoSelectorTests);
end.
