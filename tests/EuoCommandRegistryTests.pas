unit EuoCommandRegistryTests;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoCommandRegistry;

type
  TEuoCommandRegistryTests = class(TTestCase)
  private
    Hits : Integer;
    procedure IncHits;
    procedure NoOpProc;
  published
    procedure TestExactMatchDispatchesAndReturnsTrue;
    procedure TestNameLookupIsCaseInsensitive;
    procedure TestUnknownNameIsSilentNoOpReturningFalse;
    procedure TestClientGatedCommandNoOpsWithNoClient;
    procedure TestClientGatedCommandDispatchesWithClient;
    procedure TestNonGatedCommandDispatchesRegardlessOfClientFlag;
    procedure TestExplicitNoOpRegistrationStillReportsHandled;
  end;

implementation

procedure TEuoCommandRegistryTests.IncHits;
begin
  Inc(Hits);
end;

procedure TEuoCommandRegistryTests.NoOpProc;
begin
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestExactMatchDispatchesAndReturnsTrue;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('Pause', IncHits);
    AssertTrue(R.Dispatch('PAUSE', False));
    AssertEquals(1, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestNameLookupIsCaseInsensitive;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('Pause', IncHits);
    AssertTrue(R.Dispatch('pAuSe', False));
    AssertEquals(1, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestUnknownNameIsSilentNoOpReturningFalse;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('Pause', IncHits);
    AssertFalse(R.Dispatch('NoSuchCommand', True));
    AssertEquals(0, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestClientGatedCommandNoOpsWithNoClient;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('FindItem', IncHits, True);
    AssertFalse('client-gated command with no client selected must silently ' +
      'no-op, exactly like an unrecognized word -- callers must not need to ' +
      'distinguish the two', R.Dispatch('FindItem', False));
    AssertEquals(0, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestClientGatedCommandDispatchesWithClient;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('FindItem', IncHits, True);
    AssertTrue(R.Dispatch('FindItem', True));
    AssertEquals(1, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistryTests.TestNonGatedCommandDispatchesRegardlessOfClientFlag;
var R : TEuoCommandRegistry;
begin
  Hits := 0;
  R := TEuoCommandRegistry.Create;
  try
    R.Register('Set', IncHits, False);
    AssertTrue(R.Dispatch('Set', False));
    AssertTrue(R.Dispatch('Set', True));
    AssertEquals(2, Hits);
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
// StopCD/PlayCD are registered with an explicit no-op handler in EuoInterpreter's
// RegisterCommands -- Dispatch must still report True (recognized & handled),
// distinguishing "recognized but does nothing" from "not found", even though the
// handler itself has no observable effect.
procedure TEuoCommandRegistryTests.TestExplicitNoOpRegistrationStillReportsHandled;
var R : TEuoCommandRegistry;
begin
  R := TEuoCommandRegistry.Create;
  try
    R.Register('StopCD', NoOpProc);
    AssertTrue(R.Dispatch('StopCD', False));
  finally R.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoCommandRegistryTests);
end.
