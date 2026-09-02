unit UoVariablesTests;

{
  Tests for uo\uovariables.pas's TUOVar against a real TUOSel with no client
  selected -- every RWV(Read/Write,...) call gates on UOSel.Nr>0 and safely
  zero-fills otherwise, so every accessor here is provably a safe no-op/default-
  value path with no live client. Not exhaustive over all ~50 accessors (that
  would just be re-proving the same RWV gate over and over); this is a
  representative sample across the different return-shape families (Integer,
  Cardinal, Boolean, String) plus IgnoreCont/GetContAddr, which have real local
  logic (ContList) worth exercising directly rather than only through RWV.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uoselector, uovariables;

type
  TUoVariablesTests = class(TTestCase)
  private
    Sel : TUOSel;
    V   : TUOVar;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCharPosXIsZeroWithNoClient;
    procedure TestCharGhostIsFalseWithNoClient;
    procedure TestCharNameIsEmptyAndVarResFalseWithNoClient;
    procedure TestCliLoggedIsFalseWithNoClient;
    procedure TestShardIsEmptyWithNoClient;
    procedure TestGetContAddrFailsWithNoClient;
    procedure TestIgnoreContResetRestoresDefaultList;
    procedure TestIgnoreContClearEmptiesList;
    procedure TestIgnoreContByNameThenByIDBothWork;
    procedure TestReadWritePropertiesRoundTripAsNoOpsWithNoClient;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.SetUp;
begin
  Sel := TUOSel.Create;
  V := TUOVar.Create(Sel);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TearDown;
begin
  V.Free;
  Sel.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestCharPosXIsZeroWithNoClient;
begin
  AssertEquals(0, V.CharPosX);
  AssertEquals(0, V.CharPosY);
  AssertEquals(0, V.CharPosZ);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestCharGhostIsFalseWithNoClient;
begin
  AssertFalse(V.CharGhost);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestCharNameIsEmptyAndVarResFalseWithNoClient;
begin
  // GetStat's Addr=0 short-circuit means CharName never even reaches RWV's own
  // gate -- exercises a different early-exit path than the plain RWV-gated ones.
  AssertEquals('', V.CharName);
  AssertFalse(V.VarRes);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestCliLoggedIsFalseWithNoClient;
begin
  AssertFalse(V.CliLogged);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestShardIsEmptyWithNoClient;
begin
  AssertEquals('', V.Shard);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestGetContAddrFailsWithNoClient;
var
  Addr : Cardinal;
begin
  AssertFalse(V.GetContAddr(Addr));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestIgnoreContResetRestoresDefaultList;
begin
  // Round-trips through the exact same public IgnoreCont(Cardinal) overload
  // the interpreter's Clear() calls -- must not raise, must not crash.
  V.IgnoreCont(0);        // clear
  V.IgnoreCont($FFFFFFFF); // reset to default gump list
  // No direct public getter for ContList's contents -- this test's contract is
  // simply that both calls complete without raising (FindSortedPos's binary
  // search assumptions hold against the real default list).
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestIgnoreContClearEmptiesList;
begin
  V.IgnoreCont(0);
  // Immediately re-adding after a clear must not crash FindSortedPos on an
  // empty list (L=0, H=-1 -- the boundary case for the binary search).
  V.IgnoreCont('SOME_GUMP');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestIgnoreContByNameThenByIDBothWork;
begin
  V.IgnoreCont('MY_TEST_GUMP');
  V.IgnoreCont('MY_TEST_GUMP'); // inserting the same name twice must not raise
  V.IgnoreCont(Cardinal(12345));
  V.IgnoreCont(Cardinal(12345)); // ditto for the numeric-ID overload
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUoVariablesTests.TestReadWritePropertiesRoundTripAsNoOpsWithNoClient;
begin
  // With no client, RWV's write side also silently no-ops (UOSel.Nr>0 gate);
  // confirms the read/write property pairs don't raise either direction.
  V.LShard := 5;
  AssertEquals(Cardinal(0), V.LShard);

  V.CliXRes := 800;
  AssertEquals(Cardinal(0), V.CliXRes);

  V.TargCurs := True; // exercises WriteTargCurs's code-cave path (VirtualProtectEx
                       // etc. all silently no-op via RWV/UOSel.Nr gate too)
  AssertFalse(V.TargCurs);
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TUoVariablesTests);
end.
