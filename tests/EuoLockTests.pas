unit EuoLockTests;

{
  TEuoLock (common\EuoLock.pas) replaces FPC's TMultiReadExclusiveWriteSynchronizer on the
  interpreter's hot path. These pin the behaviours its callers rely on: recursion on one
  thread across any mix of Begin*/End*, mutual exclusion between threads, and the
  "End* without Begin*" diagnostic FPC's MREW raised.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoLock;

type
  TEuoLockTests = class(TTestCase)
  published
    procedure TestNestedWriteReadAcrossOneThread;
    procedure TestEndWithoutBeginRaises;
    procedure TestEndFromAnotherThreadRaises;
    procedure TestLockedAfterFullUnwindAcquirableByOtherThread;
    procedure TestMutualExclusionBetweenThreads;
  end;

implementation

type
  TProbe = class(TThread)
  public
    Lock    : TEuoLock;
    Got     : Boolean;
    Raised  : Boolean;
    Mode    : Integer;   // 0 = BeginWrite/EndWrite, 1 = bare EndWrite
    procedure Execute; override;
  end;

  TCounterThread = class(TThread)
  public
    Lock    : TEuoLock;
    Counter : PInteger;
    Rounds  : Integer;
    procedure Execute; override;
  end;

////////////////////////////////////////////////////////////////////////////////
procedure TProbe.Execute;
begin
  try
    if Mode = 0 then
    begin
      Lock.BeginWrite;
      Got := True;
      Lock.EndWrite;
    end
    else
      Lock.EndWrite;
  except
    on E: ELockError do Raised := True;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCounterThread.Execute;
var
  i, v : Integer;
begin
  for i := 1 to Rounds do
  begin
    Lock.BeginWrite;
    // Non-atomic read-modify-write with a yield in the middle: it only stays correct if
    // the lock really excludes the other thread.
    v := Counter^;
    if (i and 63) = 0 then Sleep(0);
    Counter^ := v + 1;
    Lock.EndWrite;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLockTests.TestNestedWriteReadAcrossOneThread;
var
  L : TEuoLock;
begin
  L := TEuoLock.Create;
  try
    L.BeginWrite;
    L.BeginRead;
    L.BeginWrite;
    L.EndWrite;
    L.EndRead;
    L.EndWrite;
    // Fully unwound: another full cycle must still work.
    L.BeginRead;
    L.EndRead;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLockTests.TestEndWithoutBeginRaises;
var
  L : TEuoLock;
  Raised : Boolean;
begin
  L := TEuoLock.Create;
  try
    Raised := False;
    try L.EndWrite; except on E: ELockError do Raised := True; end;
    AssertTrue('EndWrite with no Begin raises', Raised);

    Raised := False;
    try L.EndRead; except on E: ELockError do Raised := True; end;
    AssertTrue('EndRead with no Begin raises', Raised);

    // And the lock is still usable afterwards (the failed End must not unbalance it).
    L.BeginWrite;
    L.EndWrite;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLockTests.TestEndFromAnotherThreadRaises;
var
  L : TEuoLock;
  P : TProbe;
begin
  L := TEuoLock.Create;
  try
    L.BeginWrite;             // held by THIS thread
    P := TProbe.Create(True);
    try
      P.Lock := L;
      P.Mode := 1;            // the other thread tries to release it
      P.Start;
      P.WaitFor;
      AssertTrue('releasing a lock held by another thread raises', P.Raised);
    finally
      P.Free;
    end;
    L.EndWrite;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLockTests.TestLockedAfterFullUnwindAcquirableByOtherThread;
var
  L : TEuoLock;
  P : TProbe;
begin
  L := TEuoLock.Create;
  try
    L.BeginWrite;
    L.BeginRead;
    L.EndRead;
    L.EndWrite;
    P := TProbe.Create(True);
    try
      P.Lock := L;
      P.Mode := 0;
      P.Start;
      P.WaitFor;
      AssertTrue('other thread acquires after full unwind', P.Got);
    finally
      P.Free;
    end;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLockTests.TestMutualExclusionBetweenThreads;
const
  N = 20000;
var
  L : TEuoLock;
  A, B : TCounterThread;
  Counter : Integer;
begin
  L := TEuoLock.Create;
  Counter := 0;
  try
    A := TCounterThread.Create(True);
    B := TCounterThread.Create(True);
    try
      A.Lock := L; A.Counter := @Counter; A.Rounds := N;
      B.Lock := L; B.Counter := @Counter; B.Rounds := N;
      A.Start; B.Start;
      A.WaitFor; B.WaitFor;
    finally
      A.Free; B.Free;
    end;
    AssertEquals('no lost updates', 2 * N, Counter);
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoLockTests);

end.
